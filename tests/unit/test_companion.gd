extends TestCase
## Tests du compagnon (J7) : suivre, attendre, ordres (court, long), actionner
## un mécanisme, tenir une plaque, prendre l'ascenseur, rembobinage.
##
## Arène : sol à y = 480. Élias et le compagnon sont pilotés par le test.

const ELIAS: PackedScene = preload("res://scenes/player/elias.tscn")
const COMPANION: PackedScene = preload("res://scenes/characters/companion.tscn")
const B: float = 48.0
const FLOOR_Y: float = 480.0

var arena: Node2D
var player: Player
var buddy: Companion
var cfg: CompanionConfig


func before_each() -> void:
	Settings.classic_mode = false
	arena = add_node(Node2D.new())
	block(-20, 10, 80, 4)


func after_each() -> void:
	AudioManager.stop_loop(Elevator.LOOP_ID, 0.0)


func block(x: float, y: float, w: float, h: float) -> SolidBlock:
	var solid := SolidBlock.new()
	solid.position = Vector2(x, y) * B
	solid.size_blocks = Vector2(w, h)
	arena.add_child(solid)
	return solid


func spawn(player_x: float, buddy_x: float, mode: StringName = &"Follow") -> void:
	player = ELIAS.instantiate()
	player.position = Vector2(player_x, FLOOR_Y)
	player.get_node("Foley").free()
	arena.add_child(player)
	player.input.from_devices = false
	buddy = COMPANION.instantiate()
	buddy.position = Vector2(buddy_x, FLOOR_Y)
	buddy.start_mode = mode
	arena.add_child(buddy)
	cfg = buddy.config
	await wait_physics(3)


## Appui sur « Ordre » pendant « seconds » secondes.
func order(seconds: float) -> void:
	player.input.order = true
	await wait_physics_seconds(seconds)
	player.input.order = false
	await wait_physics(2)


func test_follows_elias_at_a_distance() -> void:
	await spawn(600.0, 100.0)
	await wait_physics_seconds(3.0)
	var gap: float = player.global_position.x - buddy.global_position.x
	assert_almost_eq(gap, cfg.follow_distance, 12.0, "il se tient à distance (%.0f px)" % gap)
	player.input.move = -1
	player.input.run = true
	await wait_physics_seconds(1.5)
	player.input.move = 0
	player.input.run = false
	await wait_physics_seconds(2.0)
	gap = buddy.global_position.x - player.global_position.x
	assert_almost_eq(gap, cfg.follow_distance, 12.0, "il suit dans l'autre sens aussi (%.0f px)" % gap)


func test_short_order_toggles_follow_and_wait() -> void:
	await spawn(200.0, 100.0, &"Follow")
	await order(0.1)
	assert_eq(buddy.mode, &"Wait", "appui court : il attend")
	await wait_physics(15)  # le temps de s'arrêter
	var x: float = buddy.global_position.x
	player.input.move = 1
	await wait_physics_seconds(2.0)
	player.input.move = 0
	assert_almost_eq(buddy.global_position.x, x, 1.0, "il n'a pas bougé")
	await order(0.1)
	assert_eq(buddy.mode, &"Follow", "nouvel appui court : il suit")


func test_long_order_activates_the_marked_mechanism() -> void:
	var lever := Lever.new()
	lever.position = Vector2(400, FLOOR_Y)
	lever.companion_can_use = true
	arena.add_child(lever)
	await spawn(300.0, 100.0, &"Wait")
	# Pendant l'appui : l'anneau se remplit et le levier visé est entouré.
	player.input.order = true
	await wait_physics_seconds(cfg.long_press_time * 0.5)
	var ring: OrderIndicator = player.order_indicator
	assert_true(ring.progress > 0.2 and ring.progress < 0.8, "anneau à moitié (%.2f)" % ring.progress)
	assert_eq(ring.target, lever, "le levier visé est montré avant l'ordre")
	assert_ne(buddy.machine.current_name, &"Activate", "pas encore d'ordre")
	await wait_physics_seconds(cfg.long_press_time * 0.5 + 0.1)
	player.input.order = false
	await wait_physics(2)
	assert_true(ring.progress < 0.0, "touche relâchée : l'anneau disparaît")
	assert_eq(buddy.machine.current_name, &"Activate", "« Active ça »")
	assert_true(await wait_until(func() -> bool: return lever.on, 400), "il actionne le levier")
	await wait_physics_seconds(cfg.activate_duration + 0.1)
	assert_eq(buddy.mode, &"Wait", "puis il attend sur place")
	assert_almost_eq(buddy.global_position.x, 400.0, cfg.activate_reach + 2.0)


func test_long_order_without_a_marked_mechanism_is_refused() -> void:
	var lever := Lever.new()  # non marqué : le compagnon ne sait pas s'en servir
	lever.position = Vector2(400, FLOOR_Y)
	arena.add_child(lever)
	var played: Array[StringName] = []
	var listener := func(id: StringName) -> void: played.append(id)
	AudioManager.sfx_played.connect(listener)
	await spawn(300.0, 100.0, &"Wait")
	player.input.order = true
	await wait_physics_seconds(cfg.long_press_time * 0.5)
	assert_true(player.order_indicator.progress > 0.0, "l'anneau se remplit")
	assert_null(player.order_indicator.target, "rien d'entouré : anneau gris")
	await wait_physics_seconds(cfg.long_press_time * 0.5 + 0.1)
	player.input.order = false
	await wait_physics(2)
	AudioManager.sfx_played.disconnect(listener)
	assert_ne(buddy.machine.current_name, &"Activate")
	assert_true(played.has(&"companion_no"), "il refuse (%s)" % [played])
	assert_false(lever.on)


func test_he_holds_a_pressure_plate() -> void:
	var plate := PressurePlate.new()
	plate.position = Vector2(300, FLOOR_Y)
	arena.add_child(plate)
	var plate_lever := Lever.new()  # un repère marqué sur la plaque
	plate_lever.position = Vector2(300, FLOOR_Y)
	plate_lever.companion_can_use = true
	arena.add_child(plate_lever)
	await spawn(250.0, 100.0, &"Wait")
	await order(cfg.long_press_time + 0.1)
	assert_true(await wait_until(func() -> bool: return plate.on, 300), "il se tient sur la plaque")
	player.global_position = Vector2(900, FLOOR_Y)
	await wait_physics_seconds(2.0)
	assert_true(plate.on, "et il y reste (il attend)")


func test_he_takes_the_elevator_to_join_elias() -> void:
	block(10, 3, 30, 0.5)  # étage : dessus à y = 144, de x 480 à 1920
	var elevator := Elevator.new()
	elevator.position = Vector2(288, FLOOR_Y)
	elevator.width_blocks = 4.0  # de x 288 à 480 : jointive avec l'étage
	elevator.travel = Vector2(0, -(FLOOR_Y - 144.0))
	arena.add_child(elevator)
	await spawn(700.0, 100.0, &"Follow")
	player.global_position = Vector2(700, 144)  # Élias est à l'étage
	await wait_physics_seconds(3.0)
	assert_almost_eq(buddy.global_position.x, elevator.center_x(), 8.0, "il monte sur l'ascenseur")
	elevator.trigger()
	await wait_physics_seconds((FLOOR_Y - 144.0) / elevator.speed + 2.5)
	assert_almost_eq(buddy.global_position.y, 144.0, 3.0, "emporté à l'étage")
	assert_true(absf(player.global_position.x - buddy.global_position.x) <= cfg.follow_distance + 12.0, "et il rejoint Élias")


func test_enemy_shots_pass_through_him() -> void:
	await spawn(600.0, 300.0, &"Wait")
	assert_false(buddy.take_hit(null), "pas une cible")


func test_companion_follows_the_rewind() -> void:
	await spawn(600.0, 100.0, &"Follow")
	var photo: Dictionary = buddy.capture_state()
	await wait_physics_seconds(2.0)
	assert_true(buddy.global_position.x > 300.0)
	buddy.apply_state(photo)
	buddy.resume_state(photo)
	assert_almost_eq(buddy.global_position.x, (photo["position"] as Vector2).x, 0.5, "replacé")
	assert_eq(buddy.machine.current_name, &"Follow", "il reprend son mode")


func wait_until(condition: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if condition.call():
			return true
		await wait_physics(1)
	return condition.call()
