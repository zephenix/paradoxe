extends TestCase
## Écrans 6 à 8 du prototype (J8) : le passage des cellules aux ruines, Marek qui
## montre le chemin puis s'en va, l'infiltration par la passerelle, le combat du
## hall et son ascenseur, la poursuite, la porte que Marek ouvre, le plan final.
## Élias est piloté comme par un joueur ; entre deux écrans, on le dépose au
## checkpoint (le parcours complet est dans test_prototype_full.gd).

const LEVEL: PackedScene = preload("res://scenes/levels/prototype.tscn")

var level: Level
var player: Player
var marek: Companion


func before_each() -> void:
	GameState.new_game()
	level = LEVEL.instantiate()
	level.play_opening = false
	level.get_node("Elias/Foley").free()
	(level.get_node("Story/Finale") as FinaleCutscene).return_to_title = false
	add_node(level)
	player = level.player
	player.input.from_devices = false
	level.death.input_from_devices = false
	level.cutscenes.input_from_devices = false
	marek = level.get_node("Room5/Companion")
	await wait_physics(3)


func after_each() -> void:
	Engine.time_scale = 1.0
	tree.paused = false
	SceneTransition.fade_in(0.0)
	AudioManager.restore_from_silence(0.0)
	GameState.new_game()
	AudioManager.set_zone(&"", 0.0)
	AudioManager.music.silence()
	AudioManager.stop_loop(Elevator.LOOP_ID, 0.0)


func wait_for(condition: Callable, max_frames: int = 1200) -> bool:
	for i in max_frames:
		if condition.call():
			return true
		await wait_physics(1)
	return condition.call()


## Dépose Élias (et la caméra) à un endroit.
func place(at: Vector2) -> void:
	player.global_position = at
	player.air_top_y = at.y
	player.velocity = Vector2.ZERO
	level.camera.snap_to_target()
	await wait_physics(3)


## Marek est parti par le conduit (fin de l'écran 6) : il attend à l'écran 8.
func send_marek_away() -> void:
	marek.mode = &"Wait"
	marek.away = true
	marek.global_position = (level.get_node("Room8/Hideout") as Node2D).global_position
	marek.machine.transition_to(&"Wait")


## Pilote : avance (en courant si « run »), grimpe quand il bute, se hisse quand
## il est suspendu, saute aux abscisses « jumps », s'accroupit dans « crouch ».
## « run_after » : ne court qu'au-delà de cette abscisse.
func drive(done: Callable, run: bool, jumps: Array[float], crouch: Vector2 = Vector2.ZERO, max_frames: int = 3000,
		run_after: float = -INF) -> bool:
	var stalled: int = 0
	var calm: int = 0
	var last_x: float = player.global_position.x
	var next_jump: int = 0
	for i in max_frames:
		if done.call() or player.is_dead or level.cutscenes.playing:
			break
		var x: float = player.global_position.x
		var crouching: bool = x > crouch.x and x < crouch.y
		player.input.move = 1
		player.input.down = crouching
		player.input.run = (run or x > run_after) and calm <= 0 and not (crouching and not run)
		calm -= 1
		if next_jump < jumps.size() and x >= jumps[next_jump]:
			player.input.press(&"jump")
			next_jump += 1
		if player.machine.current_name == &"LedgeHang":
			player.input.press(&"move_up")
		var walking: bool = player.machine.current_name in [&"Idle", &"Walk", &"Run", &"Crouch"]
		stalled = stalled + 1 if walking and absf(x - last_x) < 0.5 else 0
		last_x = x
		if stalled >= 10:
			calm = 20
			if player.machine.current_name != &"Run":
				player.input.down = false
				player.input.press(&"move_up")
				stalled = 0
		await wait_physics(1)
	player.input.move = 0
	player.input.run = false
	player.input.down = false
	return done.call() and not player.is_dead


# --- Écran 5 -> 6 ----------------------------------------------------------------

func test_cells_exit_leads_to_the_ruins_and_marek_leaves() -> void:
	var exit: Node2D = level.get_node("Room5/Exit")
	marek.global_position = exit.global_position + Vector2(40.0, 0.0)
	await place(exit.global_position + Vector2(20.0, 0.0))
	assert_true(await wait_for(func() -> bool: return level.cutscenes.playing, 60), "la sortie lance le passage")
	assert_true(await wait_for(func() -> bool: return not level.cutscenes.playing, 1800), "passage puis Marek montre le chemin")
	var room6: Room = level.get_node("Room6")
	assert_true(room6.world_rect().has_point(player.global_position + Vector2(0, -10)), "Élias est dans les ruines")
	assert_eq(GameState.checkpoint_id, &"ruines", "nouveau checkpoint")
	assert_true(marek.away, "Marek est parti par le conduit")
	assert_false(marek.visible)
	assert_true((level.get_node("Room8") as Room).world_rect().has_point(marek.global_position + Vector2(0, -10)),
			"il attend à l'écran 8")
	player.input.order = true
	await wait_physics_seconds(marek.config.long_press_time + 0.1)
	player.input.order = false
	await wait_physics(3)
	assert_ne(marek.machine.current_name, &"Activate", "parti : il ne reçoit plus d'ordres")


# --- Écran 6 ---------------------------------------------------------------------

func test_ruins_are_crossed_by_the_catwalk_unseen() -> void:
	send_marek_away()
	await place((level.get_node("Room6/Entry") as Node2D).global_position)
	var guard: Sentinel = level.get_node("Room6/Sentinel1")
	var alarmed: Array[bool] = [false]
	var catwalk: SolidBlock = level.get_node("Room6/Catwalk")
	var catwalk_end: float = catwalk.global_position.x + catwalk.pixel_size().x
	# Accroupi sur la passerelle : ses pas sont muets. Au bout, il se relève et
	# court pour sauter en bas (en marchant, le « garde-bord » l'arrêterait au bord).
	var crossed: bool = await drive(func() -> bool:
		if guard.machine.current_name == &"Combat":
			alarmed[0] = true
		return player.global_position.x > 2600.0, false, [], Vector2(catwalk.global_position.x + 20.0, catwalk_end - 60.0),
		3000, catwalk_end - 60.0)
	assert_true(crossed, "arrivé au hall (x = %.0f, y = %.0f, état %s)" % [player.global_position.x, player.global_position.y, player.machine.current_name])
	assert_false(alarmed[0], "sans être repéré")


# --- Écran 7 ---------------------------------------------------------------------

func test_hall_can_be_won_and_the_elevator_leads_on() -> void:
	send_marek_away()
	var room: Room = level.get_node("Room7")
	var sentinels: Array[Sentinel] = []
	for node in room.find_children("*", "Sentinel", false, false):
		sentinels.append(node as Sentinel)
	assert_eq(sentinels.size(), 2, "deux Sentinelles dans le hall")
	player.respawn((level.get_node("Room7/Checkpoint") as Checkpoint).global_position, 1)
	level.camera.snap_to_target()
	await wait_physics(5)
	var cfg: EnergyConfig = player.energy.config
	var deaths: int = 0
	var stalled: int = 0
	var last_x: float = player.global_position.x
	var elevator: Elevator = level.get_node("Room7/Elevator")
	for frame in 60 * 100:
		if player.global_position.y < elevator.top_y() - 150.0 or player.global_position.x > 4480.0:
			break
		if player.is_dead:
			deaths += 1
			await die_and_respawn()
			continue
		var input: PlayerInput = player.input
		var alive: Array[Sentinel] = sentinels.filter(func(s: Sentinel) -> bool: return not s.is_dead)
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
	player.input.move = 0
	assert_eq(sentinels.filter(func(s: Sentinel) -> bool: return not s.is_dead).size(), 0,
			"les deux Sentinelles vaincues (morts d'Élias : %d)" % deaths)
	assert_true(deaths <= 2, "sans trop mourir (%d)" % deaths)
	assert_true(await wait_for(func() -> bool: return elevator.is_at_top(), 600), "monté sur l'ascenseur, il l'a emmené en haut")
	player.input.move = 1
	assert_true(await wait_for(func() -> bool: return player.global_position.x > 4500.0, 300), "il sort vers l'écran 8")
	player.input.move = 0


# --- Écran 8 ---------------------------------------------------------------------

func test_chase_door_and_final_shot() -> void:
	send_marek_away()
	await place((level.get_node("Room8/Checkpoint") as Node2D).global_position)
	var lever: Lever = level.get_node("Room8/Lever")
	var door: Door = level.get_node("Room8/Door")
	var pursuers: Array[Pursuer] = [level.get_node("Room8/Pursuer1"), level.get_node("Room8/Pursuer2")]
	var chase_music: Array[bool] = [false]
	await drive(func() -> bool:
		if AudioManager.music.theme_id == &"mus_chase_loop":
			chase_music[0] = true
		return false, true, [5130.0, 5560.0, 6378.0], Vector2(5925.0, 6080.0), 60 * 40)
	assert_false(player.is_dead, "Élias n'a pas été rattrapé (x = %.0f)" % player.global_position.x)
	assert_true(pursuers.all(func(p: Pursuer) -> bool: return p.mode != Pursuer.Mode.DORMANT), "les Sentinelles l'ont poursuivi")
	assert_true(chase_music[0], "musique de poursuite")
	assert_false(marek.away, "Marek est revenu")
	assert_true(lever.on, "il a tiré le levier : la porte s'est ouverte")
	assert_true(level.cutscenes.playing, "passé la porte : la fin commence")
	var shot: IntroShot = level.get_node("Story/EndingLayer/EndingShot")
	assert_true(await wait_for(func() -> bool: return shot.visible, 900), "le plan final")
	assert_eq(AudioManager.music.theme_id, &"mus_theme_end", "le thème de fin")
	assert_true(await wait_for(func() -> bool: return not door.is_open(), 60), "Marek a refermé la porte")
	level.cutscenes.skip_held = true
	assert_true(await wait_for(func() -> bool: return not level.cutscenes.playing, 200), "fin")
	level.cutscenes.skip_held = false
	for p in pursuers:
		assert_true(p.global_position.x < door.global_position.x, "les poursuivants sont restés de l'autre côté")


func test_caught_in_the_chase_respawns_at_the_chase_start() -> void:
	send_marek_away()
	var checkpoint: Node2D = level.get_node("Room8/Checkpoint")
	await place(checkpoint.global_position)
	player.input.move = 1
	await wait_physics_seconds(3.0)  # il marche jusqu'à les réveiller…
	player.input.move = 0  # … puis s'arrête : ils le rattrapent
	assert_true(await wait_for(func() -> bool: return player.is_dead, 600), "attrapé")
	await die_and_respawn()
	assert_false(player.is_dead)
	assert_almost_eq(player.global_position.x, checkpoint.global_position.x, 2.0, "au début de la poursuite")
	var pursuer: Pursuer = level.get_node("Room8/Pursuer1")
	assert_eq(pursuer.mode, Pursuer.Mode.DORMANT, "les poursuivants attendent de nouveau")
	await wait_physics_seconds(1.2)
	assert_ne(AudioManager.music.theme_id, &"mus_chase_loop", "la musique de poursuite s'est arrêtée")


# --- Outils -------------------------------------------------------------------------

func _incoming_threat() -> bool:
	for node in tree.get_nodes_in_group(&"projectiles"):
		var p: Projectile = node as Projectile
		if p == null or p.team != Projectile.TEAM_ENEMY or p.is_queued_for_deletion():
			continue
		var dx: float = player.global_position.x - p.global_position.x
		if signf(dx) == p.direction and absf(dx) < p.speed * 0.5:
			return true
	return false


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
