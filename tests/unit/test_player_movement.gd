extends TestCase
## Tests du déplacement d'Élias : on construit un petit décor, on pilote Élias
## par ses intentions (comme le ferait un joueur) et on vérifie ses états et
## ses positions. La simulation avance image par image (--fixed-fps 60).

const ELIAS: PackedScene = preload("res://scenes/player/elias.tscn")
const B: float = 48.0  # un bloc
const FLOOR_Y: float = 480.0  # dessus du sol de l'arène

var arena: Node2D
var player: Player
var cfg: PlayerMovementConfig


func before_each() -> void:
	Settings.classic_mode = false
	arena = add_node(Node2D.new())
	block(-20, 10, 60, 4)  # grand sol : dessus à y = 480


func after_each() -> void:
	Settings.classic_mode = false


# --- Outils ------------------------------------------------------------------

## Ajoute un bloc solide (coordonnées et tailles en blocs).
func block(x: float, y: float, w: float, h: float) -> void:
	var solid := SolidBlock.new()
	solid.position = Vector2(x, y) * B
	solid.size_blocks = Vector2(w, h)
	arena.add_child(solid)


## Place Élias (pieds en « feet », en pixels) et le pilote par le test.
func spawn(feet: Vector2, facing: int = 1) -> void:
	player = ELIAS.instantiate()
	player.position = feet
	player.start_facing = facing
	arena.add_child(player)
	player.input.from_devices = false
	cfg = player.config
	await wait_physics(3)


## Avance jusqu'à ce que Élias soit dans l'état voulu (ou abandonne après max_frames).
func run_until_state(state: StringName, max_frames: int = 180) -> bool:
	for i in max_frames:
		if player.machine.current_name == state:
			return true
		await wait_physics(1)
	return player.machine.current_name == state


func state() -> StringName:
	return player.machine.current_name


# --- Réglages calculés -------------------------------------------------------

func test_jump_formulas_match_block_settings() -> void:
	var config: PlayerMovementConfig = load("res://resources/player/player_movement.tres")
	var v: Vector2 = config.running_jump_velocity()
	var height: float = v.y * v.y / (2.0 * config.gravity)
	var airtime: float = 2.0 * -v.y / config.gravity
	assert_almost_eq(height, config.blocks(config.running_jump_height_blocks), 0.5, "hauteur du saut avec élan")
	assert_almost_eq(v.x * airtime, config.blocks(config.running_jump_distance_blocks), 0.5, "longueur du saut avec élan")


# --- Au sol ------------------------------------------------------------------

func test_idle_walk_run() -> void:
	await spawn(Vector2(0, FLOOR_Y))
	assert_eq(state(), &"Idle")
	player.input.move = 1
	await wait_physics(10)
	assert_eq(state(), &"Walk", "une direction : marche")
	player.input.run = true
	await wait_physics(30)
	assert_eq(state(), &"Run", "direction + course")
	assert_true(player.velocity.x > cfg.walk_speed, "plus rapide qu'en marchant")
	player.input.move = 0
	await wait_physics(2)
	assert_eq(state(), &"Skid", "relâcher en pleine course : dérapage")
	assert_true(await run_until_state(&"Idle", 60), "arrêt après le dérapage")


func test_turn_before_walking_back() -> void:
	await spawn(Vector2(0, FLOOR_Y), 1)
	player.input.move = -1
	await wait_physics(2)
	assert_eq(state(), &"Turn", "demi-tour animé d'abord")
	assert_true(await run_until_state(&"Walk", 30), "puis marche")
	assert_eq(player.facing, -1)


func test_crouch_cannot_stand_under_low_ceiling() -> void:
	block(4, 7.5, 6, 1)  # plafond à 72 px du sol (bas du bloc à y = 408)
	await spawn(Vector2(2 * B, FLOOR_Y))
	player.input.down = true
	await wait_physics(4)
	assert_eq(state(), &"Crouch")
	player.input.move = 1
	await wait_physics(150)  # avance accroupi (60 px/s) jusque sous le plafond
	player.input.move = 0
	player.input.down = false
	await wait_physics(10)
	assert_true(player.global_position.x > 4 * B + 12, "sous le plafond")
	assert_eq(state(), &"Crouch", "impossible de se relever sous un plafond bas")


func test_edge_guard_stops_before_deadly_drop() -> void:
	block(-20, 0, 26, 3)  # plate-forme haute (dessus à y = 0), vide de 10 blocs à droite
	await spawn(Vector2(4 * B, 0))
	player.input.move = 1
	await wait_physics(120)
	assert_true(player.is_on_floor(), "reste sur la plate-forme")
	assert_true(player.global_position.x < 6 * B, "s'arrête au bord")


# --- Sauts -------------------------------------------------------------------

func _measure_jump(running: bool) -> float:
	await spawn(Vector2(-10 * B, FLOOR_Y))
	player.input.move = 1
	player.input.run = running
	await wait_physics(60)
	player.input.press(&"jump")
	var start_x: float = player.global_position.x
	await run_until_state(&"Jump", 10)
	for i in 120:
		await wait_physics(1)
		if player.is_on_floor() and player.velocity.y >= 0.0 and state() != &"Jump":
			break
	return (player.global_position.x - start_x) / B


func test_standing_jump_covers_about_two_blocks() -> void:
	var distance: float = await _measure_jump(false)
	assert_true(distance > 1.7 and distance < 2.9, "saut sans élan : %.2f blocs" % distance)


func test_running_jump_covers_about_four_blocks() -> void:
	var distance: float = await _measure_jump(true)
	assert_true(distance > 3.7 and distance < 5.0, "saut avec élan : %.2f blocs" % distance)


func test_jump_is_committed_in_the_air() -> void:
	await spawn(Vector2(0, FLOOR_Y))
	player.input.move = 1
	player.input.run = true
	await wait_physics(40)
	player.input.press(&"jump")
	await wait_physics(5)
	assert_eq(state(), &"Jump")
	player.input.move = -1
	await wait_physics(10)
	assert_true(player.velocity.x > 0.0, "la trajectoire ne change pas en l'air")


# --- Chutes ------------------------------------------------------------------

func _drop_from(height_blocks: float) -> void:
	await spawn(Vector2(0, FLOOR_Y - height_blocks * B))
	player.air_top_y = player.global_position.y
	player.machine.transition_to(&"Fall")


func test_small_fall_is_a_light_landing() -> void:
	await _drop_from(1.5)
	assert_true(await run_until_state(&"Land", 60))
	assert_false(player.is_dead)


func test_medium_fall_forces_a_roll() -> void:
	await _drop_from(4.0)
	assert_true(await run_until_state(&"Roll", 90), "roulade de réception")
	assert_false(player.is_dead)


func test_high_fall_is_deadly() -> void:
	var causes: Array[StringName] = []
	await _drop_from(6.5)
	player.died.connect(func(cause: StringName) -> void: causes.append(cause))
	assert_true(await run_until_state(&"Dead", 90))
	assert_eq(causes, [&"fall"] as Array[StringName])


func test_falling_out_of_the_level_kills() -> void:
	await spawn(Vector2(0, FLOOR_Y))
	player.kill_y = FLOOR_Y - 10.0
	await wait_physics(2)
	assert_true(player.is_dead)


# --- Rebords -----------------------------------------------------------------

func test_jump_up_grabs_ledge_then_climbs() -> void:
	block(2, 7, 4, 3)  # mur de 3 blocs : dessus à y = 336
	await spawn(Vector2(2 * B - 13, FLOOR_Y), 1)
	player.input.press(&"move_up")
	assert_true(await run_until_state(&"LedgeHang", 90), "s'accroche en sautant")
	player.input.press(&"move_up")
	assert_true(await run_until_state(&"LedgeClimb", 20), "se hisse")
	assert_true(await run_until_state(&"Idle", 90))
	assert_almost_eq(player.global_position.y, 7 * B, 2.0, "debout sur le mur")


func test_low_step_is_climbed_directly() -> void:
	block(2, 9, 4, 1)  # marche d'un bloc
	await spawn(Vector2(2 * B - 13, FLOOR_Y), 1)
	player.input.press(&"move_up")
	await wait_physics(2)
	assert_eq(state(), &"LedgeClimb", "pas besoin de sauter")
	assert_true(await run_until_state(&"Idle", 60))
	assert_almost_eq(player.global_position.y, 9 * B, 2.0)


func test_classic_mode_needs_up_held_to_grab() -> void:
	Settings.classic_mode = true
	block(2, 7, 4, 3)
	await spawn(Vector2(2 * B - 13, FLOOR_Y), 1)
	player.input.press(&"jump")
	await wait_physics(80)
	assert_ne(state(), &"LedgeHang", "pas de rattrapage automatique")
	player.input.up = true
	player.input.press(&"move_up")
	assert_true(await run_until_state(&"LedgeHang", 90), "avec Haut maintenu, il s'accroche")


func test_descend_from_edge_to_hang() -> void:
	block(-20, 7, 24, 3)  # plate-forme : dessus à y = 336, bord droit à x = 192
	await spawn(Vector2(4 * B - 14, 7 * B), 1)
	player.input.down = true
	assert_true(await run_until_state(&"LedgeDescend", 10))
	player.input.down = false
	assert_true(await run_until_state(&"LedgeHang", 60), "suspendu sous le bord")
	assert_eq(player.facing, -1, "face au mur")
	player.input.down = true
	assert_true(await run_until_state(&"Fall", 10), "lâche prise")


# --- Parkour moderne ---------------------------------------------------------

func test_slide_passes_under_low_obstacle() -> void:
	block(5, 7.5, 2, 1)  # obstacle bas : 72 px de passage dessous
	await spawn(Vector2(0, FLOOR_Y))
	player.input.move = 1
	player.input.run = true
	await wait_physics(25)
	player.input.down = true
	assert_true(await run_until_state(&"Slide", 5))
	await wait_physics(40)  # on maintient Bas pendant la glissade
	player.input.down = false
	await wait_physics(120)
	assert_true(player.global_position.x > 7 * B, "a franchi l'obstacle (x = %.0f)" % player.global_position.x)


func test_slide_disabled_in_classic_mode() -> void:
	Settings.classic_mode = true
	await spawn(Vector2(0, FLOOR_Y))
	player.input.move = 1
	player.input.run = true
	await wait_physics(30)
	player.input.down = true
	await wait_physics(5)
	assert_ne(state(), &"Slide")


func test_dodge_roll_is_briefly_invulnerable() -> void:
	await spawn(Vector2(0, FLOOR_Y))
	player.input.press(&"roll")
	await wait_physics(10)
	assert_eq(state(), &"Roll")
	assert_true(player.is_invulnerable, "invulnérable pendant l'esquive")
	await run_until_state(&"Idle", 60)
	assert_false(player.is_invulnerable)


func test_input_buffer_chains_jump_after_landing() -> void:
	await _drop_from(1.5)
	await run_until_state(&"Land", 60)
	player.input.press(&"jump")  # appuyé PENDANT la réception
	assert_true(await run_until_state(&"Jump", 20), "le saut part dès la fin de la réception")


func test_respawn_resets_player() -> void:
	await _drop_from(7.0)
	await run_until_state(&"Dead", 90)
	player.respawn(Vector2(0, FLOOR_Y), -1)
	await wait_physics(2)
	assert_false(player.is_dead)
	assert_eq(state(), &"Idle")
	assert_eq(player.facing, -1)
