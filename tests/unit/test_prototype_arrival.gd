extends TestCase
## Écrans 2 et 3 du prototype (J8) : l'arrivée (chute scénarisée, thème, fuite
## devant le Traqueur) et la canopée (grimper, sauter des trous mortels, passer
## accroupi, descendre en roulade). Élias est piloté comme par un joueur.

const LEVEL: PackedScene = preload("res://scenes/levels/prototype.tscn")

var level: Level
var player: Player
var tracker: Tracker


func setup(opening: bool) -> void:
	GameState.new_game()
	level = LEVEL.instantiate()
	level.play_opening = opening
	level.get_node("Elias/Foley").free()
	add_node(level)
	player = level.player
	player.input.from_devices = false
	level.death.input_from_devices = false
	level.cutscenes.input_from_devices = false
	tracker = level.get_node("Room2/Tracker")
	await wait_physics(3)


func after_each() -> void:
	Engine.time_scale = 1.0
	tree.paused = false
	SceneTransition.fade_in(0.0)
	GameState.new_game()
	AudioManager.set_zone(&"", 0.0)
	AudioManager.music.silence()


func wait_for(condition: Callable, max_frames: int = 1200) -> bool:
	for i in max_frames:
		if condition.call():
			return true
		await wait_physics(1)
	return condition.call()


## Pilote : avance (en courant si « run »), grimpe quand il bute contre un mur,
## saute aux abscisses « jumps », s'accroupit entre les bornes de « crouch ».
## S'arrête quand « done » est vrai (ou qu'Élias meurt).
var jump_log: Array[String] = []


func drive(done: Callable, run: bool, jumps: Array[float], crouch: Vector2 = Vector2.ZERO, max_frames: int = 3000) -> bool:
	var stalled: int = 0
	var calm: int = 0  # images pendant lesquelles il ne court plus (pour grimper)
	var last_x: float = player.global_position.x
	var next_jump: int = 0
	for i in max_frames:
		if done.call() or player.is_dead:
			break
		var x: float = player.global_position.x
		var crouching: bool = x > crouch.x and x < crouch.y
		player.input.move = 1
		player.input.down = crouching
		player.input.run = run and not crouching and calm <= 0
		calm -= 1
		if next_jump < jumps.size() and x >= jumps[next_jump]:
			player.input.press(&"jump")
			jump_log.append("saut à x = %.0f, vitesse %.0f" % [x, player.velocity.x])
			next_jump += 1
		if player.machine.current_name == &"LedgeHang":
			player.input.press(&"move_up")  # rattrapé au bord : il se hisse
		var walking: bool = player.machine.current_name in [&"Idle", &"Walk", &"Run"]
		stalled = stalled + 1 if walking and absf(x - last_x) < 0.5 else 0
		last_x = x
		if stalled >= 10:
			# Contre un mur : on lâche la course, puis Haut (se hisser).
			calm = 20
			if player.machine.current_name != &"Run":
				player.input.press(&"move_up")
				stalled = 0
		await wait_physics(1)
	player.input.move = 0
	player.input.run = false
	player.input.down = false
	return done.call() and not player.is_dead


# --- Écran 2 -------------------------------------------------------------------

func test_arrival_cutscene_lands_elias_safely() -> void:
	await setup(true)
	assert_true(level.cutscenes.playing, "l'arrivée commence toute seule")
	assert_true(await wait_for(func() -> bool: return not level.cutscenes.playing, 900), "cinématique finie")
	var landing: Vector2 = (level.get_node("Room2/Landing") as Node2D).global_position
	assert_almost_eq(player.global_position.x, landing.x, 2.0, "posé au point d'atterrissage")
	assert_false(player.is_dead, "tombé de haut, mais vivant (chute scénarisée)")
	assert_eq(AudioManager.music.theme_id, &"mus_theme_arrival", "le thème d'arrivée")
	assert_eq(level.camera.zoom_override, 0.0, "la caméra a retrouvé son cadrage")
	assert_eq(tracker.mode, Tracker.Mode.DORMANT, "le Traqueur attend, caché")
	assert_false(tracker.visible)


func test_running_escapes_the_tracker() -> void:
	await setup(false)
	var emerged: Array[bool] = [false]
	var closest: Array[float] = [INF]
	var ledge_x: float = (level.get_node("Room2/Ledge") as Node2D).global_position.x
	var escaped: bool = await drive(func() -> bool:
		if tracker.mode != Tracker.Mode.DORMANT:
			emerged[0] = true
		if tracker.mode == Tracker.Mode.CHASE:
			closest[0] = minf(closest[0], absf(player.global_position.x - tracker.global_position.x))
		return player.global_position.x > ledge_x + 200.0 and player.is_on_floor(), true, [-3905.0])
	assert_true(emerged[0], "le Traqueur a surgi")
	assert_true(closest[0] < 450.0, "c'est une vraie poursuite : il se rapproche (%.0f px au plus près)" % closest[0])
	assert_true(escaped, "en courant, Élias lui échappe et grimpe (x = %.0f, mort : %s)" % [player.global_position.x, player.is_dead])
	assert_true(await wait_for(func() -> bool: return tracker.mode == Tracker.Mode.BLOCKED, 600), "il ne grimpe pas : bloqué au pied du mur")
	assert_true(tracker.global_position.x < ledge_x, "resté en bas")


func test_walking_gets_caught() -> void:
	await setup(false)
	await drive(func() -> bool: return false, false, [-3905.0], Vector2.ZERO, 60 * 20)
	assert_true(player.is_dead, "en marchant, le Traqueur le rattrape")
	assert_eq(tracker.mode, Tracker.Mode.FED)


func test_tracker_hides_again_when_elias_respawns() -> void:
	await setup(false)
	player.global_position = Vector2(-4200.0, 672.0)
	assert_true(await wait_for(func() -> bool: return tracker.mode == Tracker.Mode.CHASE, 200), "la poursuite commence")
	player.respawn(Vector2(-4950.0, 672.0), 1)
	assert_eq(tracker.mode, Tracker.Mode.DORMANT, "réapparition : il retourne se cacher")
	assert_false(tracker.visible)


func test_tracker_follows_the_rewind() -> void:
	await setup(false)
	var photo: Dictionary = tracker.capture_state()
	player.global_position = Vector2(-4200.0, 672.0)
	assert_true(await wait_for(func() -> bool: return tracker.mode == Tracker.Mode.CHASE, 200))
	tracker.apply_state(photo)
	assert_eq(tracker.mode, Tracker.Mode.DORMANT, "rembobiné : de nouveau caché")
	assert_almost_eq(tracker.global_position.x, photo["position"].x, 0.5)


# --- Écran 3 -------------------------------------------------------------------

func test_canopy_can_be_crossed() -> void:
	await setup(false)
	var checkpoint: Checkpoint = level.get_node("Room3/Checkpoint")
	player.respawn(checkpoint.global_position, 1)
	level.camera.snap_to_target()
	await wait_physics(5)
	assert_eq(GameState.checkpoint_id, &"canopee", "checkpoint de la canopée")
	var crossed: bool = await drive(func() -> bool: return player.global_position.x > 60.0 and player.is_on_floor(),
			true, [-1516.0, -728.0], Vector2(-1262.0, -1090.0))
	assert_true(crossed, "canopée traversée jusqu'à la clairière (x = %.0f, y = %.0f, état %s, mort : %s ; %s)" % [
			player.global_position.x, player.global_position.y, player.machine.current_name, player.is_dead, jump_log])


func test_canopy_gaps_are_deadly() -> void:
	await setup(false)
	player.global_position = Vector2(-1420.0, 300.0)  # au-dessus du premier trou
	player.air_top_y = player.global_position.y
	player.machine.transition_to(&"Fall")
	assert_true(await wait_for(func() -> bool: return player.is_dead, 300), "chute de plus de 5 blocs : mortelle")
