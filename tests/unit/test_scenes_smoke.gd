extends TestCase
## Tests « de fumée » : on allume tout et on regarde si ça fume.
##
## Chaque scène du dossier /scenes est instanciée et tourne pendant quelques
## images ; chaque script du projet est chargé. Le moindre message d'erreur du
## moteur (script invalide, nœud introuvable, ressource manquante…) fait échouer
## le test, avec le nom de la scène ou du script fautif.

const FRAMES_PER_SCENE: int = 60
const SCRIPT_DIRS: Array[String] = ["res://scripts", "res://tests", "res://tools/godot"]


func test_every_scene_runs_without_errors() -> void:
	var scenes: PackedStringArray = _find_files("res://scenes", ".tscn")
	assert_true(scenes.size() > 0, "au moins une scène")
	for path in scenes:
		clear_engine_errors()
		var packed: PackedScene = load(path) as PackedScene
		if packed == null:
			fail("%s : ne se charge pas" % path)
			continue
		var instance: Node = packed.instantiate()
		tree.root.add_child(instance)
		await wait_frames(FRAMES_PER_SCENE)
		instance.queue_free()
		await wait_frames(2)
		for error in engine_errors():
			fail("%s : %s" % [path, error])
		assert_true(true)  # une vérification par scène, pour le décompte
	clear_engine_errors()


func test_every_script_compiles() -> void:
	for dir_path in SCRIPT_DIRS:
		for path in _find_files(dir_path, ".gd"):
			clear_engine_errors()
			var script: Script = load(path) as Script
			assert_not_null(script, "%s : ne se charge pas" % path)
			for error in engine_errors():
				fail("%s : %s" % [path, error])
	clear_engine_errors()


## Liste récursive des fichiers d'une extension donnée.
func _find_files(dir_path: String, extension: String) -> PackedStringArray:
	var found: PackedStringArray = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return found
	for sub in dir.get_directories():
		found.append_array(_find_files(dir_path.path_join(sub), extension))
	for file in dir.get_files():
		if file.ends_with(extension):
			found.append(dir_path.path_join(file))
	found.sort()
	return found
