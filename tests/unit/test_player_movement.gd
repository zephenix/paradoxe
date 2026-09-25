extends TestCase
## Tests du déplacement d'Élias : on construit un petit décor, on pilote Élias
## par ses intentions (comme le ferait un joueur) et on vérifie ses états et
## ses positions. La simulation avance image par image (--fixed-fps 60).
##
## Repères : 1 bloc = 48 px (B) ; y vers le BAS ; les pieds d'Élias sont à son
## origine. Le sol de l'arène a son dessus à y = 480 (10 blocs).

const ELIAS: PackedScene = preload("res://scenes/player/elias.tscn")
const B: float = 48.0  # un bloc
const FLOOR_Y: float = 480.0  # dessus du sol de l'arène

var arena: Node2D
var player: Player
var cfg: PlayerMovementConfig
## Suite des états traversés depuis spawn() (pour vérifier des enchaînements).
var states_seen: Array[StringName] = []


func before_each() -> void:
	Settings.classic_mode = false
	states_seen.clear()
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
## Ses bruitages sont retirés : ces tests vérifient le mouvement, pas le son.
func spawn(feet: Vector2, facing: int = 1) -> void:
	player = ELIAS.instantiate()
	player.position = feet
	player.start_facing = facing
	player.get_node("Foley").free()
	arena.add_child(player)
	player.input.from_devices = false
	player.machine.state_changed.connect(func(_from: StringName, to: StringName) -> void: states_seen.append(to))
	cfg = player.config
	await wait_physics(3)


## Avance jusqu'à ce que Élias soit dans l'état voulu (ou abandonne après max_frames).
func run_until_state(state: StringName, max_frames: int = 180) -> bool:
	for i in max_frames:
		if player.machine.current_name == state:
			return true
		await wait_physics(1)
	return player.machine.current_name == state


## Avance jusqu'à ce qu'Élias touche le sol (après avoir sauté ou être tombé).
func run_until_grounded(max_frames: int = 240) -> bool:
	for i in max_frames:
		await wait_physics(1)
		if player.is_on_floor() and state() not in [&"Jump", &"Fall"]:
			return true
	return false


func state() -> StringName:
	return player.machine.current_name


# --- Réglages calculés -------------------------------------------------------

func test_jump_formulas_match_block_settings() -> void:
	var config: PlayerMovementConfig = load("res://resources/player/player_movement.tres")
	var jumps: Dictionary = {
		"avec élan": [config.running_jump_velocity(), config.running_jump_height_blocks, config.running_jump_distance_blocks],
		"sans élan": [config.standing_jump_velocity(), config.standing_jump_height_blocks, config.standing_jump_distance_blocks],
	}
	for jump_name: String in jumps:
		var v: Vector2 = jumps[jump_name][0]
		var height: float = v.y * v.y / (2.0 * config.gravity)
		var airtime: float = 2.0 * -v.y / config.gravity
		assert_almost_eq(height, config.blocks(jumps[jump_name][1]), 0.5, "hauteur du saut %s" % jump_name)
		assert_almost_eq(v.x * airtime, config.blocks(jumps[jump_name][2]), 0.5, "longueur du saut %s" % jump_name)
	var up: Vector2 = config.vertical_jump_velocity()
	assert_almost_eq(up.y * up.y / (2.0 * config.gravity), config.blocks(config.vertical_jump_height_blocks), 0.5, "saut sur place")
	assert_almost_eq(up.x, 0.0, 0.001, "le saut sur place est vertical")


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


func test_walk_moves_at_walk_speed() -> void:
	await spawn(Vector2(0, FLOOR_Y))
	player.input.move = 1
	await wait_physics(60)
	var distance: float = player.global_position.x
	# 1 s de marche à 125 px/s, moins le court temps d'accélération.
	assert_true(distance > cfg.walk_speed * 0.85 and distance < cfg.walk_speed * 1.02, "marche : %.0f px en 1 s" % distance)


func test_turn_before_walking_back() -> void:
	await spawn(Vector2(0, FLOOR_Y), 1)
	player.input.move = -1
	await wait_physics(2)
	assert_eq(state(), &"Turn", "demi-tour animé d'abord")
	assert_true(await run_until_state(&"Walk", 30), "puis marche")
	assert_eq(player.facing, -1)


func test_skid_turn_reverses_and_keeps_running() -> void:
	await spawn(Vector2(0, FLOOR_Y), 1)
	player.input.move = 1
	player.input.run = true
	await wait_physics(40)
	player.input.move = -1
	await wait_physics(2)
	assert_eq(state(), &"Skid", "demi-tour en pleine course : dérapage")
	assert_true(await run_until_state(&"Run", 40), "puis repart en courant")
	assert_eq(player.facing, -1, "dans l'autre sens")
	var after_skid: int = states_seen.find(&"Skid") + 1
	assert_eq(states_seen[after_skid], &"Run", "directement, sans demi-tour supplémentaire (%s)" % [states_seen])


func test_crouch_then_stand_up() -> void:
	await spawn(Vector2(0, FLOOR_Y))
	player.input.down = true
	await wait_physics(5)
	assert_eq(state(), &"Crouch")
	assert_true(player.is_crouched, "boîte de collision basse")
	player.input.down = false
	assert_true(await run_until_state(&"Idle", 10), "se relève dès qu'on relâche Bas")
	assert_false(player.is_crouched)


func test_crouch_walk_is_slow() -> void:
	await spawn(Vector2(0, FLOOR_Y))
	player.input.down = true
	await wait_physics(5)
	player.input.move = 1
	await wait_physics(60)
	var distance: float = player.global_position.x
	assert_eq(state(), &"CrouchWalk")
	assert_true(distance > cfg.crouch_walk_speed * 0.8 and distance < cfg.crouch_walk_speed * 1.05, "accroupi : %.0f px en 1 s" % distance)


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
	block(-20, 0, 26, 3)  # plate-forme haute (dessus à y = 0, bord à x = 288), vide de 10 blocs
	await spawn(Vector2(4 * B, 0))
	player.input.move = 1
	await wait_physics(120)
	assert_true(player.is_on_floor(), "reste sur la plate-forme")
	assert_eq(state(), &"Idle", "arrêté")
	assert_true(player.global_position.x > 5 * B and player.global_position.x < 6 * B, "s'est avancé jusqu'au bord (x = %.0f)" % player.global_position.x)


func test_edge_guard_disabled_in_classic_mode() -> void:
	Settings.classic_mode = true
	block(-20, 0, 26, 3)
	await spawn(Vector2(4 * B, 0))
	player.input.move = 1
	await wait_physics(120)
	assert_true(player.global_position.y > 3 * B, "en classique, Élias tombe")


func test_crouching_at_edge_does_not_flicker() -> void:
	block(-20, 0, 26, 3)
	await spawn(Vector2(5.5 * B, 0))
	player.input.down = true
	player.input.move = 1
	await wait_physics(60)
	var changes: int = states_seen.size()
	assert_true(changes <= 4, "états stables au bord (%d changements : %s)" % [changes, states_seen])
	assert_true(player.is_on_floor(), "reste sur la plate-forme")


# --- Sauts -------------------------------------------------------------------

func _measure_jump(running: bool) -> float:
	await spawn(Vector2(-10 * B, FLOOR_Y))
	player.input.move = 1
	player.input.run = running
	await wait_physics(60)
	player.input.press(&"jump")
	var start_x: float = player.global_position.x
	assert_true(await run_until_state(&"Jump", 10), "le saut démarre")
	assert_true(await run_until_grounded(), "le saut retombe")
	return (player.global_position.x - start_x) / B


func test_standing_jump_covers_about_two_blocks() -> void:
	var distance: float = await _measure_jump(false)
	var expected: float = cfg.standing_jump_distance_blocks
	# + ~0,1 bloc : Élias avance encore un peu pendant l'impulsion et la réception.
	assert_true(absf(distance - expected) < 0.25, "saut sans élan : %.2f blocs (réglage : %.1f)" % [distance, expected])


func test_running_jump_covers_about_four_blocks() -> void:
	var distance: float = await _measure_jump(true)
	var expected: float = cfg.running_jump_distance_blocks
	assert_true(absf(distance - expected) < 0.25, "saut avec élan : %.2f blocs (réglage : %.1f)" % [distance, expected])


func test_running_jump_needs_momentum() -> void:
	await spawn(Vector2(0, FLOOR_Y))
	player.input.move = 1
	player.input.run = true
	await wait_physics(2)  # la course vient à peine de commencer
	player.input.press(&"jump")
	assert_true(await run_until_state(&"Jump", 5))
	await wait_physics(12)  # impulsion puis décollage
	assert_true(player.velocity.x < cfg.running_jump_velocity().x * 0.8, "sans élan : saut sans élan (vx = %.0f)" % player.velocity.x)


func test_jump_is_committed_in_the_air() -> void:
	await spawn(Vector2(0, FLOOR_Y))
	assert_false(player.machine.is_committed(), "à l'arrêt : non engagé")
	player.input.move = 1
	player.input.run = true
	await wait_physics(40)
	player.input.press(&"jump")
	await wait_physics(5)
	assert_eq(state(), &"Jump")
	assert_true(player.machine.is_committed(), "un saut est engagé")
	player.input.move = -1
	await wait_physics(10)
	assert_true(player.velocity.x > 0.0, "la trajectoire ne change pas en l'air")


func test_running_jump_landing_does_not_slide_far() -> void:
	await spawn(Vector2(-10 * B, FLOOR_Y))
	player.input.move = 1
	player.input.run = true
	await wait_physics(60)
	player.input.press(&"jump")
	assert_true(await run_until_state(&"Jump", 10), "le saut démarre")
	player.input.move = 0
	player.input.run = false
	assert_true(await run_until_state(&"Land", 120), "réception")
	var landed_x: float = player.global_position.x
	await wait_physics(20)
	assert_true(player.global_position.x - landed_x < 30.0, "glisse de %.0f px à la réception" % (player.global_position.x - landed_x))


# --- Chutes ------------------------------------------------------------------

func _drop_from(height_blocks: float) -> void:
	await spawn(Vector2(0, FLOOR_Y - height_blocks * B))
	player.air_top_y = player.global_position.y
	player.machine.transition_to(&"Fall")


func test_small_fall_is_a_light_landing() -> void:
	await _drop_from(1.5)
	assert_true(await run_until_state(&"Land", 60))
	assert_eq(player.visual.current, &"land", "réception légère")
	assert_false(player.is_dead)


func test_fall_between_two_and_three_blocks_is_heavy() -> void:
	await _drop_from(2.5)
	assert_true(await run_until_state(&"Land", 60))
	assert_eq(player.visual.current, &"land_heavy", "réception lourde")
	var frames: int = 0
	while state() == &"Land" and frames < 120:
		await wait_physics(1)
		frames += 1
	assert_almost_eq(frames / 60.0, cfg.heavy_land_recovery, 0.05, "durée de récupération")


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


func test_fall_height_is_measured_from_last_floor() -> void:
	await spawn(Vector2(0, FLOOR_Y))
	player.air_top_y = FLOOR_Y - 300.0  # valeur périmée (ancien étage)
	await wait_physics(2)
	assert_almost_eq(player.air_top_y, player.global_position.y, 0.5, "au sol, le point de référence suit les pieds")


# --- Temps du coyote -----------------------------------------------------------

## Court vers le bord d'une plate-forme, attend « frames_after » images après
## avoir quitté le sol, puis appuie sur Saut. Renvoie l'état 2 images plus tard.
func _jump_after_leaving_edge(frames_after: int) -> StringName:
	block(-20, 0, 26, 3)  # bord à x = 288, vide dessous
	await spawn(Vector2(0, 0))
	player.input.move = 1
	player.input.run = true
	for i in 120:
		await wait_physics(1)
		if not player.is_on_floor():
			break
	await wait_physics(frames_after)
	player.input.press(&"jump")
	await wait_physics(2)
	return state()


func test_coyote_jump_just_after_leaving_edge() -> void:
	var result: StringName = await _jump_after_leaving_edge(3)
	assert_eq(result, &"Jump", "saut accepté juste après le bord")
	assert_true(player.velocity.y < 0.0, "décolle aussitôt, sans impulsion au sol")


func test_coyote_jump_while_walking_takes_off_at_once() -> void:
	block(-20, 8.5, 26, 3)  # petite marche de 1,5 bloc (le garde-bord laisse passer), bord à x = 288
	await spawn(Vector2(4 * B, 8.5 * B))
	player.input.move = 1
	for i in 120:
		await wait_physics(1)
		if not player.is_on_floor():
			break
	await wait_physics(3)
	player.input.press(&"jump")
	await wait_physics(2)
	assert_eq(state(), &"Jump", "saut sans élan accepté juste après le bord")
	assert_true(player.velocity.y < 0.0, "décolle aussitôt : pas d'impulsion des genoux en l'air")


func test_no_coyote_jump_in_classic_mode() -> void:
	Settings.classic_mode = true
	var result: StringName = await _jump_after_leaving_edge(3)
	assert_ne(result, &"Jump", "pas de temps du coyote en classique")
	assert_eq(result, &"Fall")


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


func test_step_climb_limit_is_the_setting() -> void:
	block(2, 7, 4, 3)  # mur de 3 blocs : au-dessus de step_climb_max_blocks (2,6)
	await spawn(Vector2(2 * B - 13, FLOOR_Y), 1)
	player.input.press(&"move_up")
	await wait_physics(2)
	assert_eq(state(), &"Jump", "trop haut pour se hisser directement : saut")


func test_overhang_prevents_direct_climb() -> void:
	block(2, 9, 4, 1)      # marche d'un bloc
	block(-2, 7.4, 3.8, 0.5)  # surplomb au-dessus d'Élias (bas à 101 px des pieds)
	await spawn(Vector2(2 * B - 13, FLOOR_Y), 1)
	player.input.press(&"move_up")
	await wait_physics(2)
	assert_ne(state(), &"LedgeClimb", "le trajet du hissage traverserait le surplomb")


func test_climb_refused_when_no_room_on_top() -> void:
	block(2, 7, 4, 3)    # mur de 3 blocs
	block(2, 5, 4, 1)    # plafond à 1 bloc au-dessus du rebord : pas la place d'être debout
	await spawn(Vector2(2 * B - 13, FLOOR_Y), 1)
	player.input.press(&"move_up")
	assert_true(await run_until_state(&"LedgeHang", 90), "s'accroche quand même")
	player.input.press(&"move_up")
	await wait_physics(40)
	assert_eq(state(), &"LedgeHang", "reste suspendu : impossible de se hisser")


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


func test_descend_from_edge_to_hang_with_down_held() -> void:
	block(-20, 7, 24, 3)  # plate-forme : dessus à y = 336, bord droit à x = 192
	await spawn(Vector2(4 * B - 14, 7 * B), 1)
	player.input.down = true  # maintenu pendant toute la descente
	assert_true(await run_until_state(&"LedgeDescend", 10))
	assert_true(await run_until_state(&"LedgeHang", 60), "suspendu sous le bord")
	assert_eq(player.facing, -1, "face au mur")
	await wait_physics(30)
	assert_eq(state(), &"LedgeHang", "Bas maintenu depuis la descente : ne lâche pas")
	player.input.down = false
	await wait_physics(2)
	player.input.press(&"move_down")
	assert_true(await run_until_state(&"Fall", 5), "un nouvel appui sur Bas : lâche prise")


func test_descend_refused_without_room_below() -> void:
	block(-20, 7, 24, 3)  # plate-forme, bord à x = 192
	block(4, 8, 3, 2)     # bloc collé sous le bord : pas la place de se suspendre
	await spawn(Vector2(4 * B - 14, 7 * B), 1)
	player.input.down = true
	await wait_physics(3)
	assert_eq(state(), &"Crouch", "s'accroupit au lieu de descendre")
	assert_false(states_seen.has(&"LedgeDescend"), "la place est vérifiée AVANT de commencer la descente")


func test_no_immediate_regrab_after_letting_go() -> void:
	block(2, 7, 4, 3)
	await spawn(Vector2(2 * B - 13, FLOOR_Y), 1)
	player.input.press(&"move_up")
	assert_true(await run_until_state(&"LedgeHang", 90))
	states_seen.clear()
	player.input.press(&"move_down")
	await wait_physics(30)
	assert_false(states_seen.slice(1).has(&"LedgeHang"), "ne se raccroche pas aussitôt (%s)" % [states_seen])


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


func test_slide_needs_momentum() -> void:
	await spawn(Vector2(0, FLOOR_Y))
	player.input.move = 1
	player.input.run = true
	await wait_physics(2)  # la course vient à peine de commencer
	player.input.down = true
	await wait_physics(3)
	assert_true(state() in [&"Crouch", &"CrouchWalk"], "sans élan : on s'accroupit (%s)" % state())


func test_slide_disabled_in_classic_mode() -> void:
	Settings.classic_mode = true
	await spawn(Vector2(0, FLOOR_Y))
	player.input.move = 1
	player.input.run = true
	await wait_physics(30)
	assert_eq(state(), &"Run", "court bien")
	player.input.down = true
	await wait_physics(3)
	assert_true(state() in [&"Crouch", &"CrouchWalk"], "Bas en courant : accroupi, pas de glissade (%s)" % state())


func test_dodge_roll_is_briefly_invulnerable() -> void:
	await spawn(Vector2(0, FLOOR_Y))
	player.input.press(&"roll")
	await wait_physics(10)
	assert_eq(state(), &"Roll")
	assert_true(player.is_invulnerable, "invulnérable pendant l'esquive")
	assert_true(await run_until_state(&"Idle", 60), "fin de la roulade")
	assert_false(player.is_invulnerable)


func test_roll_not_invulnerable_in_classic_mode() -> void:
	Settings.classic_mode = true
	await spawn(Vector2(0, FLOOR_Y))
	player.input.press(&"roll")
	await wait_physics(10)
	assert_eq(state(), &"Roll")
	assert_false(player.is_invulnerable, "pas d'invulnérabilité en classique")


func test_roll_covers_configured_distance() -> void:
	await spawn(Vector2(0, FLOOR_Y))
	player.input.press(&"roll")
	assert_true(await run_until_state(&"Roll", 5))
	var start_x: float = player.global_position.x
	assert_true(await run_until_state(&"Idle", 60), "fin de la roulade")
	var distance: float = (player.global_position.x - start_x) / B
	assert_almost_eq(distance, cfg.roll_distance_blocks, 0.2, "roulade : %.2f blocs" % distance)


func test_input_buffer_chains_jump_after_landing() -> void:
	await _drop_from(1.5)
	assert_true(await run_until_state(&"Land", 60))
	player.input.press(&"jump")  # appuyé PENDANT la réception
	assert_true(await run_until_state(&"Jump", 20), "le saut part dès la fin de la réception")


func test_no_input_buffer_in_classic_mode() -> void:
	Settings.classic_mode = true
	await _drop_from(1.5)
	assert_true(await run_until_state(&"Land", 60))
	player.input.press(&"jump")  # appuyé au début de la réception : oublié en classique
	await wait_physics(20)
	assert_ne(state(), &"Jump", "pas de tampon d'entrée en classique")


# --- Mort et réapparition ----------------------------------------------------

func test_respawn_resets_player() -> void:
	await _drop_from(7.0)
	assert_true(await run_until_state(&"Dead", 90), "meurt d'abord")
	player.respawn(Vector2(0, FLOOR_Y), -1)
	states_seen.clear()
	await wait_physics(10)
	assert_false(player.is_dead)
	assert_eq(state(), &"Idle")
	assert_eq(player.facing, -1)
	assert_false(states_seen.has(&"Land"), "pas de faux atterrissage à la réapparition (%s)" % [states_seen])
