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
	GameState.new_game()
	level = LEVEL.instantiate()
	level.get_node("Elias").get_node("Foley").free()  # parcours muet
	add_node(level)
	player = level.player
	player.input.from_devices = false
	level.death.input_from_devices = false
	await wait_physics(3)


func after_each() -> void:
	GameState.new_game()


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


func test_death_in_the_shaft_respawns_at_room_c_checkpoint() -> void:
	var checkpoint: Checkpoint = level.get_node("RoomC/Checkpoint")
	# Élias passe sur le checkpoint à l'entrée de C…
	player.respawn(checkpoint.global_position, 1)
	level.camera.snap_to_target()
	await wait_physics(5)
	assert_eq(GameState.checkpoint_id, checkpoint.id(), "checkpoint de C atteint")
	# … puis tombe dans le puits (x de 21 à 22,5 blocs dans C).
	player.global_position = Vector2(2560 + 21.75 * B, 10 * B)
	player.air_top_y = player.global_position.y
	player.machine.transition_to(&"Fall")
	assert_true(await _wait_until(func() -> bool: return player.is_dead, 300), "chute mortelle dans le puits")
	await die_and_respawn()
	assert_false(player.is_dead, "réapparu")
	assert_almost_eq(player.global_position.x, checkpoint.global_position.x, 1.0, "au checkpoint de C")
	await wait_physics(10)
	assert_true(player.is_on_floor(), "sur un sol")


func test_every_screen_after_the_first_has_a_checkpoint() -> void:
	for room_name: String in ["RoomB", "RoomC", "RoomE", "RoomF"]:
		var checkpoint: Checkpoint = level.get_node_or_null(room_name + "/Checkpoint")
		assert_not_null(checkpoint, "%s : checkpoint à l'entrée" % room_name)
		if checkpoint:
			var room: Room = level.get_node(room_name)
			assert_true(room.world_rect().has_point(checkpoint.global_position + Vector2(0, -10)), "%s : dans la salle" % room_name)


func test_combat_room_has_two_sentinels_and_low_cover() -> void:
	var sentinels: Array[Node] = level.get_node("RoomF").find_children("*", "Sentinel", false, false)
	assert_eq(sentinels.size(), 2, "deux Sentinelles")
	for cover: String in ["RoomF/Cover1", "RoomF/Cover2"]:
		var block: SolidBlock = level.get_node(cover)
		assert_almost_eq(block.size_blocks.y, 1.5, 0.001, "%s : muret de 1,5 bloc" % cover)


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


func test_combat_room_can_be_won() -> void:
	# « Combat jouable contre 2 sentinelles » (PLAN §9, J3) : un pilote simple,
	# comme un joueur prudent, doit gagner.
	#   - un tir ennemi arrive : bouclier ;
	#   - sinon, s'il a l'énergie : un tir puis, détente maintenue, un tir chargé
	#     (qui brise un bouclier ou tue) ;
	#   - aucune Sentinelle ne le voit : il avance vers la suivante.
	var room: Room = level.get_node("RoomF")
	var sentinels: Array[Sentinel] = []
	for node in room.find_children("*", "Sentinel", false, false):
		sentinels.append(node as Sentinel)
	player.respawn((level.get_node("RoomF/Checkpoint") as Checkpoint).global_position, 1)
	level.camera.snap_to_target()
	await wait_physics(5)
	var cfg: EnergyConfig = player.energy.config
	var deaths: int = 0
	var stalled: int = 0
	var last_x: float = player.global_position.x
	var frame: int = 0
	while frame < 60 * 90:
		frame += 1
		var alive: Array[Sentinel] = sentinels.filter(func(s: Sentinel) -> bool: return not s.is_dead)
		if alive.is_empty():
			break
		if player.is_dead:
			deaths += 1
			await die_and_respawn()
			continue
		var input: PlayerInput = player.input
		var fighting: bool = alive.any(func(s: Sentinel) -> bool: return s.sees_target)
		if _incoming_threat():
			input.move = 0
			input.fire = false
			input.shield = true
		elif fighting:
			input.move = 0
			input.shield = false
			var state: StringName = player.machine.current_name
			if state == &"Charge":
				input.fire = not player.weapon.is_charged()
			elif state in [&"Idle", &"Aim"] and player.energy.value >= cfg.shot_cost + cfg.charged_shot_cost:
				input.press(&"fire")
				input.fire = true
			else:
				input.fire = false
		else:
			# Personne ne le voit : il avance, et escalade les murets qui le bloquent.
			input.shield = false
			input.fire = false
			input.move = 1
			var walking: bool = player.machine.current_name in [&"Idle", &"Walk"]
			stalled = stalled + 1 if walking and absf(player.global_position.x - last_x) < 0.5 else 0
			if stalled >= 10:
				input.press(&"move_up")
				stalled = 0
		last_x = player.global_position.x
		await wait_physics(1)
	var survivors: int = sentinels.filter(func(s: Sentinel) -> bool: return not s.is_dead).size()
	assert_eq(survivors, 0, "les deux Sentinelles vaincues (morts d'Élias : %d)" % deaths)
	assert_true(deaths <= 2, "un joueur prudent s'en sort sans trop mourir (%d morts)" % deaths)


## Vrai si un tir ennemi arrive sur Élias (moins de 0,5 s avant l'impact).
func _incoming_threat() -> bool:
	for node in tree.get_nodes_in_group(&"projectiles"):
		var p: Projectile = node as Projectile
		if p == null or p.team != Projectile.TEAM_ENEMY or p.is_queued_for_deletion():
			continue
		var dx: float = player.global_position.x - p.global_position.x
		if signf(dx) == p.direction and absf(dx) < p.speed * 0.5:
			return true
	return false


## Fait mourir Élias puis, si le choix « rembobiner / checkpoint » apparaît,
## choisit le checkpoint ; attend la fin de la réapparition.
func die_and_respawn(cause: StringName = &"shot") -> void:
	if not player.is_dead:
		player.kill(cause)
	for i in 120:
		if level.death.phase == &"choice" or not player.is_dead:
			break
		await wait_physics(1)
	if level.death.phase == &"choice":
		level.death.request_checkpoint()
	await wait_physics_seconds(level.respawn.total_time() + 0.1)


func _wait_until(condition: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if condition.call():
			return true
		await wait_physics(1)
	return condition.call()
