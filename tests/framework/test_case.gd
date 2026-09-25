class_name TestCase
extends RefCounted
## Classe de base de tous les tests.
##
## Un fichier de test (tests/unit/test_xxx.gd) hérite de TestCase ; chacune de
## ses fonctions dont le nom commence par « test_ » est un test. Exemple :
##
##     extends TestCase
##
##     func test_addition() -> void:
##         assert_eq(1 + 1, 2, "l'addition doit marcher")
##
## Fonctions optionnelles appelées autour de CHAQUE test : before_each() et
## after_each() (préparer / ranger). Un test peut utiliser « await » pour
## attendre des images (wait_frames) ou du temps (wait_seconds).

## Arbre de scènes du lanceur (pour ajouter des nœuds, attendre des images…).
var tree: SceneTree
## Intercepteur d'erreurs du moteur (fourni par le lanceur).
var catcher: ErrorCatcher

var _failures: PackedStringArray = []
var _assertion_count: int = 0
var _nodes_to_free: Array[Node] = []
var _expected_warnings: PackedStringArray = []


# --- À redéfinir si besoin ----------------------------------------------------

func before_each() -> void:
	pass


func after_each() -> void:
	pass


# --- Vérifications ------------------------------------------------------------

func assert_true(condition: bool, message: String = "") -> void:
	_assertion_count += 1
	if not condition:
		_fail("attendu vrai", message)


func assert_false(condition: bool, message: String = "") -> void:
	_assertion_count += 1
	if condition:
		_fail("attendu faux", message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	_assertion_count += 1
	if not _same(actual, expected):
		_fail("obtenu %s, attendu %s" % [var_to_str(actual), var_to_str(expected)], message)


func assert_ne(actual: Variant, unexpected: Variant, message: String = "") -> void:
	_assertion_count += 1
	if _same(actual, unexpected):
		_fail("valeur %s non souhaitée" % var_to_str(actual), message)


func assert_almost_eq(actual: float, expected: float, tolerance: float = 0.001, message: String = "") -> void:
	_assertion_count += 1
	if absf(actual - expected) > tolerance:
		_fail("obtenu %f, attendu %f (± %f)" % [actual, expected, tolerance], message)


func assert_not_null(value: Variant, message: String = "") -> void:
	_assertion_count += 1
	if value == null:
		_fail("valeur nulle", message)


func assert_null(value: Variant, message: String = "") -> void:
	_assertion_count += 1
	if value != null:
		_fail("attendu null, obtenu %s" % var_to_str(value), message)


func fail(message: String) -> void:
	_assertion_count += 1
	_fail("échec", message)


# --- Outils -------------------------------------------------------------------

## Ajoute un nœud à l'arbre ; il sera libéré automatiquement après le test.
func add_node(node: Node) -> Node:
	tree.root.add_child(node)
	_nodes_to_free.append(node)
	return node


## Attend « count » images (le moteur fait tourner _process / _physics_process).
func wait_frames(count: int = 1) -> void:
	for i in count:
		await tree.process_frame


## Attend « count » pas de physique (60 par seconde dans ce projet).
func wait_physics(count: int = 1) -> void:
	for i in count:
		await tree.physics_frame


## Attend « seconds » secondes de physique (convertit en nombre de pas).
func wait_physics_seconds(seconds: float) -> void:
	await wait_physics(roundi(seconds * Engine.physics_ticks_per_second))


## Annonce qu'un avertissement du moteur contenant « fragment » est ATTENDU
## pendant ce test (sinon, tout avertissement fait échouer le test).
func expect_warning(fragment: String) -> void:
	_expected_warnings.append(fragment)


## Attend « seconds » secondes de temps de jeu.
func wait_seconds(seconds: float) -> void:
	await tree.create_timer(seconds).timeout


## Erreurs du moteur survenues depuis le début du test (ou le dernier appel à clear_engine_errors).
func engine_errors() -> PackedStringArray:
	return catcher.errors() if catcher else PackedStringArray()


func clear_engine_errors() -> void:
	if catcher:
		catcher.clear()


# --- Utilisé par le lanceur ---------------------------------------------------

func _reset_results() -> void:
	_failures.clear()
	_assertion_count = 0
	_expected_warnings.clear()


func _is_expected_warning(warning: String) -> bool:
	for fragment in _expected_warnings:
		if warning.contains(fragment):
			return true
	return false


func _free_nodes() -> void:
	for node in _nodes_to_free:
		if is_instance_valid(node):
			node.queue_free()
	_nodes_to_free.clear()


func _fail(reason: String, message: String) -> void:
	var line: String = reason if message.is_empty() else "%s : %s" % [message, reason]
	_failures.append(line)


## Compare deux valeurs ; tolère int/float égaux (1 == 1.0) et StringName/String.
func _same(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float):
		return is_equal_approx(float(a), float(b))
	if (a is String or a is StringName) and (b is String or b is StringName):
		return String(a) == String(b)
	return typeof(a) == typeof(b) and a == b
