extends TestCase
## Tests de la salle de test complète (scenes/levels/test_level.tscn) : on
## vérifie qu'un joueur peut réellement la parcourir, et que la mort ramène
## Élias à un endroit d'où il peut repartir.
##
## Repères : 1 bloc = 48 px. Salle A : x 0 à 1280 ; B : 1280 à 2560 ;
## C : 2560 à 3840 ; D (le puits) sous C ; E (grand hall) à droite de C.

const LEVEL: PackedScene = preload("res://scenes/levels/test_level.tscn")
const B: float = 48.0

var level: Level
var player: Player


func before_each() -> void:
	level = LEVEL.instantiate()
	level.get_node("Elias").get_node("Foley").free()  # parcours muet
	add_node(level)
	player = level.player
	player.input.from_devices = false
	await wait_physics(3)


func test_room_a_leads_to_room_b() -> void:
	# Pilote simple : avancer ; s'accroupir dans le tunnel (x de 17,2 à 23,6 blocs) ;
	# si bloqué contre un obstacle, appuyer sur Haut (se hisser). Avant la
	# correction de l'audit, le tunnel débouchait sous le plafond, contre le mur :
	# ce test restait bloqué dans la salle A.
	var stalled: int = 0
	var last_x: float = player.global_position.x
	for i in 1500:
		var x: float = player.global_position.x
		player.input.move = 1
		player.input.down = x > 17.2 * B and x < 23.6 * B
		# Bloqué = immobile pendant 12 images en marchant (pas pendant une réception).
		var walking: bool = player.machine.current_name in [&"Idle", &"Walk"]
		stalled = stalled + 1 if walking and absf(x - last_x) < 0.5 else 0
		last_x = x
		if stalled >= 12:
			player.input.press(&"move_up")
			stalled = 0
		if x > 1300.0:
			break
		await wait_physics(1)
	assert_true(player.global_position.x > 1300.0, "atteint la salle B (x = %.0f, état %s)" % [player.global_position.x, player.machine.current_name])
	assert_false(player.is_dead)


func test_death_in_the_shaft_respawns_in_room_c() -> void:
	var room_c: Room = level.get_node("RoomC")
	# Élias se tient d'abord sur le sol de C, juste avant le puits…
	player.respawn(Vector2(2560 + 19.5 * B, 11 * B), 1)
	level.camera.snap_to_target()
	await wait_physics(5)
	assert_eq(level.respawn_room(), room_c, "C est la salle de réapparition")
	# … puis tombe dans le puits (x de 21 à 22,5 blocs dans C).
	player.respawn(Vector2(2560 + 21.75 * B, 10 * B), 1)
	player.air_top_y = player.global_position.y
	player.machine.transition_to(&"Fall")
	assert_true(await _wait_until(func() -> bool: return player.is_dead, 300), "chute mortelle dans le puits")
	var total: float = level.respawn.total_time()
	await wait_physics_seconds(total + 0.3)
	assert_false(player.is_dead, "réapparu")
	assert_eq(level.respawn_room(), room_c, "le puits (D) n'est pas devenu la salle de réapparition")
	assert_true(room_c.world_rect().has_point(player.global_position + Vector2(0, -10)), "réapparaît dans la salle C")
	await wait_physics(10)
	assert_true(player.is_on_floor(), "sur un sol")


func test_respawn_takes_less_than_two_seconds() -> void:
	assert_true(level.respawn.total_time() < 2.0, "PLAN §5.7 : retour en jeu en moins de 2 s")


func test_shaft_uses_a_cut() -> void:
	var shaft: Room = level.get_node("RoomD")
	assert_eq(shaft.transition, Room.Transition.CUT, "chute dans le puits : coupure franche")


func test_tunnel_and_obstacle_leave_exactly_one_and_a_half_blocks() -> void:
	# Tunnel de A : plafond (Block4) au-dessus du sol (Block1) ; obstacle de B (Block5) au-dessus de B/Block4.
	var gaps: Array = [["RoomA/Block4", "RoomA/Block1"], ["RoomB/Block5", "RoomB/Block4"]]
	for pair: Array in gaps:
		var ceiling: SolidBlock = level.get_node(pair[0])
		var ground: SolidBlock = level.get_node(pair[1])
		var gap: float = ground.global_position.y - (ceiling.global_position.y + ceiling.pixel_size().y)
		assert_almost_eq(gap, 1.5 * B, 0.1, "passage bas %s" % pair[0])


func _wait_until(condition: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if condition.call():
			return true
		await wait_physics(1)
	return condition.call()
