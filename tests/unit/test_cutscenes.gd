extends TestCase
## Tests du lecteur de cinématiques (J7) : bandes noires, joueur bloqué,
## passage en maintenant « Passer », état final garanti, enchaînement.

const ELIAS: PackedScene = preload("res://scenes/player/elias.tscn")


## Une petite cinématique de test : 3 s d'attente, puis un état final.
class ProbeCutscene extends Cutscene:
	var steps: Array[String] = []

	func run(ctx: CutscenePlayer) -> void:
		steps.append("début")
		await ctx.wait(3.0)
		steps.append("fin du déroulé")

	func finish(_ctx: CutscenePlayer) -> void:
		steps.append("état final")


var arena: Node2D
var player: Player
var cutscenes: CutscenePlayer


func before_each() -> void:
	arena = add_node(Node2D.new())
	player = ELIAS.instantiate()
	player.get_node("Foley").free()
	arena.add_child(player)
	cutscenes = CutscenePlayer.new()
	cutscenes.input_from_devices = false
	arena.add_child(cutscenes)
	await wait_physics(2)


func probe() -> ProbeCutscene:
	var scene := ProbeCutscene.new()
	arena.add_child(scene)
	return scene


func test_plays_with_letterbox_and_locks_the_player() -> void:
	var scene: ProbeCutscene = probe()
	cutscenes.play(scene)
	await wait_physics_seconds(0.6)
	assert_true(cutscenes.playing)
	assert_false(player.input.from_devices, "le joueur ne pilote plus Élias")
	assert_almost_eq(cutscenes._top.size.y, CutscenePlayer.BAR_HEIGHT, 0.5, "bande du haut")
	assert_almost_eq(cutscenes._bottom.size.y, CutscenePlayer.BAR_HEIGHT, 0.5, "bande du bas")
	assert_true(cutscenes._top.size.x > 100.0, "sur toute la largeur")
	await wait_physics_seconds(3.0)
	assert_false(cutscenes.playing, "terminée")
	assert_eq(scene.steps, ["début", "fin du déroulé", "état final"] as Array[String])
	await wait_physics_seconds(CutscenePlayer.BAR_TIME + 0.1)
	assert_almost_eq(cutscenes._top.size.y, 0.0, 0.5, "bandes rentrées")


func test_holding_skip_for_one_second_jumps_to_the_end() -> void:
	var scene: ProbeCutscene = probe()
	cutscenes.play(scene)
	await wait_physics_seconds(0.2)
	cutscenes.skip_held = true
	await wait_physics_seconds(0.5)
	assert_true(cutscenes.playing, "un appui court ne suffit pas")
	await wait_physics_seconds(0.7)
	assert_false(cutscenes.playing, "passée après une seconde d'appui")
	assert_true(scene.steps.has("état final"), "l'état final est appliqué")
	cutscenes.skip_held = false


func test_releasing_skip_resets_the_gauge() -> void:
	var scene: ProbeCutscene = probe()
	cutscenes.play(scene)
	cutscenes.skip_held = true
	await wait_physics_seconds(0.6)
	cutscenes.skip_held = false
	await wait_physics(2)
	cutscenes.skip_held = true
	await wait_physics_seconds(0.6)
	cutscenes.skip_held = false
	assert_true(cutscenes.playing, "deux appuis courts ne s'additionnent pas")
	await wait_physics_seconds(3.0)


func test_play_once_and_chaining() -> void:
	var first: ProbeCutscene = probe()
	var second: ProbeCutscene = probe()
	first.next = first.get_path_to(second)
	cutscenes.play(first)
	await wait_physics_seconds(6.5)
	assert_eq(second.steps.size(), 3, "la suivante s'enchaîne")
	assert_false(cutscenes.playing)
	cutscenes.play(first)
	await wait_physics(2)
	assert_false(cutscenes.playing, "une cinématique « une fois » ne se rejoue pas")
