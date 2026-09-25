extends SceneTree
## Lanceur de tests maison (sans dépendance externe).
##
## Lancement (depuis la racine du dépôt) :
##     godot --headless --path . --fixed-fps 60 -s res://tests/run_tests.gd
##     godot --headless --path . --fixed-fps 60 -s res://tests/run_tests.gd -- audio settings   # filtre
## ou plus simplement : ./tools/run_tests.sh
## (--fixed-fps 60 : la simulation avance d'exactement 1/60 s par image, aussi vite
## que possible ; sans cette option, les tests passent mais en temps réel.)
##
## Fonctionnement :
##   1. cherche tous les fichiers tests/unit/**/test_*.gd ;
##   2. pour chacun, exécute toutes les fonctions « test_* » (voir TestCase) ;
##   3. un test échoue si une vérification échoue, si le moteur signale une
##      erreur ou un avertissement non annoncé (voir TestCase.expect_warning),
##      s'il ne fait aucune vérification, ou s'il dépasse le délai maximum ;
##   4. quitte avec le code 0 si tout passe, 1 sinon (la CI s'en sert).
##
## « extends SceneTree » : ce script remplace la boucle principale du jeu.
## Les autoloads (AudioManager, Settings…) sont quand même chargés.

const TEST_DIR: String = "res://tests/unit"
## Délai maximum d'un test, en images (2 minutes de temps simulé à 60 images/s).
## Au-delà, le test est déclaré en échec et la suite continue.
const MAX_TEST_FRAMES: int = 60 * 120
## Images laissées au moteur après chaque test pour libérer les nœuds et
## remonter les erreurs tardives, avant de passer au test suivant.
const SETTLE_FRAMES: int = 3

var _catcher: ErrorCatcher


func _initialize() -> void:
	_catcher = ErrorCatcher.new()
	OS.add_logger(_catcher)
	# On attend que l'arbre soit prêt (autoloads initialisés) avant de lancer.
	_run.call_deferred()


func _run() -> void:
	var filters: PackedStringArray = OS.get_cmdline_user_args()
	var files: PackedStringArray = _find_test_files(TEST_DIR)
	var passed: int = 0
	var failed: int = 0
	var assertions: int = 0
	var failed_names: PackedStringArray = []
	var start_ms: int = Time.get_ticks_msec()

	print("\n=== PARADOXE — tests automatisés (Godot %s) ===" % Engine.get_version_info().string)

	for path in files:
		if not filters.is_empty() and not _matches(path, filters):
			continue
		_catcher.clear()
		var script: GDScript = load(path) as GDScript
		if script == null or not script.can_instantiate():
			failed += 1
			failed_names.append(path.get_file())
			print("\n✘ %s : le script ne se charge pas" % path)
			for error in _catcher.errors():
				print("      - %s" % error)
			continue
		var suite: TestCase = script.new() as TestCase
		if suite == null:
			failed += 1
			failed_names.append(path.get_file())
			print("\n✘ %s : le script doit hériter de TestCase" % path)
			continue
		suite.tree = self
		suite.catcher = _catcher
		print("\n%s" % path.get_file())

		for method in _test_methods(script):
			_catcher.clear()
			suite._reset_results()
			var finished: bool = await _call_with_timeout(suite, &"before_each")
			finished = finished and await _call_with_timeout(suite, method)
			finished = await _call_with_timeout(suite, &"after_each") and finished
			suite._free_nodes()
			for i in SETTLE_FRAMES:
				await process_frame  # libère les nœuds, laisse remonter les erreurs tardives
			if not finished:
				suite._failures.append("délai dépassé (%d images) : un « await » ne s'est jamais terminé" % MAX_TEST_FRAMES)
			for error in _catcher.errors():
				suite._failures.append("erreur moteur : %s" % error)
			for warning in _catcher.warnings():
				if not suite._is_expected_warning(warning):
					suite._failures.append("avertissement moteur imprévu : %s" % warning)
			if suite._assertion_count == 0 and finished:
				suite._failures.append("aucune vérification : ce test ne vérifie rien")
			assertions += suite._assertion_count
			if suite._failures.is_empty():
				passed += 1
				print("  ✔ %s" % method)
			else:
				failed += 1
				failed_names.append("%s › %s" % [path.get_file(), method])
				print("  ✘ %s" % method)
				for failure in suite._failures:
					print("      - %s" % failure)

	var elapsed: float = (Time.get_ticks_msec() - start_ms) / 1000.0
	print("\n=== %d réussi(s), %d échoué(s), %d vérifications, %.1f s ===" % [passed, failed, assertions, elapsed])
	if failed > 0:
		print("Échecs :")
		for name in failed_names:
			print("  - %s" % name)
	if passed + failed == 0:
		print("Aucun test trouvé (filtre : %s)" % " ".join(filters))
		failed = 1
	OS.remove_logger(_catcher)
	await _silence_audio()
	quit(1 if failed > 0 else 0)


## Arrête tous les sons avant de quitter. Le moteur mixe le son dans un fil
## d'exécution à part, en temps RÉEL : un son arrêté n'est libéré qu'au passage
## suivant de ce fil. Sans cette pause, les sons encore en cours au moment de
## quitter apparaissent comme des « fuites mémoire » dans la console.
func _silence_audio() -> void:
	for node in root.find_children("*", "AudioStreamPlayer", true, false):
		(node as AudioStreamPlayer).stop()
	for node in root.find_children("*", "AudioStreamPlayer2D", true, false):
		(node as AudioStreamPlayer2D).stop()
	OS.delay_msec(250)
	await process_frame
	await process_frame


## Appelle target.method() (éventuellement une coroutine) et attend sa fin, au
## plus MAX_TEST_FRAMES images. Renvoie faux si le délai est dépassé.
func _call_with_timeout(target: Object, method: StringName) -> bool:
	var state: Dictionary = {"done": false}
	var runner := func() -> void:
		await target.call(method)
		state["done"] = true
	runner.call()
	var frames: int = 0
	while not state["done"] and frames < MAX_TEST_FRAMES:
		await process_frame
		frames += 1
	return state["done"]


## Liste récursive des fichiers test_*.gd, triée par nom.
func _find_test_files(dir_path: String) -> PackedStringArray:
	var found: PackedStringArray = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return found
	for sub in dir.get_directories():
		found.append_array(_find_test_files(dir_path.path_join(sub)))
	for file in dir.get_files():
		if file.begins_with("test_") and file.ends_with(".gd"):
			found.append(dir_path.path_join(file))
	found.sort()
	return found


## Noms des fonctions « test_* » du script, dans l'ordre où elles sont écrites.
func _test_methods(script: GDScript) -> PackedStringArray:
	var names: PackedStringArray = []
	for method: Dictionary in script.get_script_method_list():
		var name: String = method["name"]
		if name.begins_with("test_") and not names.has(name):
			names.append(name)
	return names


func _matches(path: String, filters: PackedStringArray) -> bool:
	for f in filters:
		if path.get_file().contains(f):
			return true
	return false
