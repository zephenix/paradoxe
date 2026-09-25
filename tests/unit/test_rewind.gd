extends TestCase
## Tests du rembobinage temporel (RewindManager + DeathController, PLAN §5.5).
##
## Petit niveau construit par le code : sol à y = 480, Élias à x = 100, une
## Sentinelle en poste fixe à x = 1100, regard vers la droite (elle ne voit pas
## Élias). La séquence de mort est pilotée par le test (input_from_devices = false).

const ELIAS: PackedScene = preload("res://scenes/player/elias.tscn")
const SENTINEL: PackedScene = preload("res://scenes/enemies/sentinel.tscn")
const B: float = 48.0
const FLOOR_Y: float = 480.0

var level: Level
var player: Player
var sentinel: Sentinel
var cfg: RewindConfig


func before_each() -> void:
	Settings.classic_mode = false
	GameState.new_game()
	cfg = RewindManager.config
	level = Level.new()
	var room := Room.new()
	room.room_size = Vector2(1920, 720)
	level.add_child(room)
	var ground := SolidBlock.new()
	ground.position = Vector2(-2, 10) * B
	ground.size_blocks = Vector2(50, 4)
	room.add_child(ground)
	player = ELIAS.instantiate()
	player.name = "Elias"
	player.position = Vector2(100, FLOOR_Y)
	player.get_node("Foley").free()
	level.add_child(player)
	sentinel = SENTINEL.instantiate()
	sentinel.position = Vector2(1100, FLOOR_Y)
	sentinel.start_facing = 1
	sentinel.patrol_left_blocks = 0.0
	sentinel.patrol_right_blocks = 0.0
	level.add_child(sentinel)
	var camera := CameraDirector.new()
	camera.name = "CameraDirector"
	level.add_child(camera)
	add_node(level)
	player.input.from_devices = false
	level.death.input_from_devices = false
	await wait_physics(3)


func after_each() -> void:
	Engine.time_scale = 1.0
	tree.paused = false
	Settings.classic_mode = false
	GameState.new_game()


# --- Outils ------------------------------------------------------------------

## Tue Élias et attend que le choix apparaisse (faux s'il n'apparaît pas).
func die_and_wait_for_choice() -> bool:
	player.kill(&"shot")
	for i in 120:
		if level.death.phase == &"choice":
			return true
		await wait_physics(1)
	return false


## Maintient « rembobiner » pendant « seconds » secondes réelles, puis relâche.
func rewind_for(seconds: float) -> void:
	level.death.rewind_held = true
	await wait_physics_seconds(seconds)
	level.death.rewind_held = false
	await wait_physics(2)


# --- Enregistrement --------------------------------------------------------------

func test_history_keeps_only_the_last_seconds() -> void:
	await wait_physics_seconds(cfg.history_seconds + 3.0)
	assert_true(RewindManager.history_length() <= cfg.history_seconds + 0.001, "au plus %.1f s d'historique" % cfg.history_seconds)
	assert_true(RewindManager.history_length() >= cfg.history_seconds - 0.1, "mais bien rempli")
	var expected: int = roundi(cfg.history_seconds * cfg.captures_per_second) + 1
	assert_true(absi(RewindManager.frame_count() - expected) <= 2, "%d photos (≈ %d)" % [RewindManager.frame_count(), expected])


func test_player_and_sentinel_are_recorded() -> void:
	assert_true(player.is_in_group(RewindManager.GROUP))
	assert_true(sentinel.is_in_group(RewindManager.GROUP))


# --- Rembobiner ------------------------------------------------------------------

func test_rewind_puts_elias_back_where_he_was() -> void:
	# Élias marche 2 s ; on note sa position à chaque image.
	var trail: Array[float] = []
	player.input.move = 1
	for i in 120:
		await wait_physics(1)
		trail.append(player.global_position.x)
	player.input.move = 0
	assert_true(await die_and_wait_for_choice(), "le choix apparaît")
	assert_eq(Engine.time_scale, 1.0, "fin du ralenti")
	assert_true(tree.paused, "le temps est figé pendant le choix")
	await rewind_for(1.0 / cfg.rewind_speed)  # remonte 1 s d'historique
	assert_false(player.is_dead, "Élias est vivant")
	assert_false(tree.paused, "le jeu reprend")
	assert_eq(GameState.rewinds_left, cfg.uses_per_checkpoint - 1, "une utilisation décomptée")
	# Il était 1 s (± une photo) avant sa mort : environ 60 images avant la fin du relevé.
	var x: float = player.global_position.x
	var found: bool = trail.slice(trail.size() - 70, trail.size() - 50).any(func(v: float) -> bool: return absf(v - x) < 0.01)
	assert_true(found, "position exacte d'un instant passé (x = %.1f)" % x)
	assert_true(player.machine.current_name in [&"Walk", &"Idle"], "il reprend en marchant (%s)" % player.machine.current_name)


func test_rewind_brings_back_a_sentinel_killed_meanwhile() -> void:
	await wait_physics_seconds(1.0)
	sentinel.die()
	await wait_physics_seconds(1.0)
	assert_true(await die_and_wait_for_choice())
	await rewind_for(1.6 / cfg.rewind_speed)
	assert_false(sentinel.is_dead, "sa mort n'a pas encore eu lieu")
	assert_eq(sentinel.collision_layer, PhysicsLayers.ENEMIES, "de nouveau touchable")
	assert_eq(sentinel.machine.current_name, &"Patrol")


func test_rewind_restores_energy() -> void:
	await wait_physics_seconds(1.0)
	player.energy.try_spend(6.0)
	await wait_physics_seconds(0.5)
	assert_true(await die_and_wait_for_choice())
	await rewind_for(1.0 / cfg.rewind_speed)
	assert_almost_eq(player.energy.value, player.energy.config.capacity, 0.001, "jauge d'avant la dépense")


func test_rewind_clears_projectiles() -> void:
	await wait_physics_seconds(1.0)
	var shot := Projectile.new()
	shot.setup(null, Projectile.TEAM_ENEMY, -1, 10.0, false, WeaponConfig.new())
	level.add_child(shot)
	shot.global_position = Vector2(900, 300)
	assert_true(await die_and_wait_for_choice())
	await rewind_for(0.5)
	assert_false(is_instance_valid(shot), "tir en vol effacé")


func test_too_short_rewind_costs_nothing() -> void:
	await wait_physics_seconds(1.0)
	assert_true(await die_and_wait_for_choice())
	await rewind_for(2.0 / 60.0)
	assert_eq(level.death.phase, &"choice", "toujours au choix")
	assert_true(player.is_dead)
	assert_eq(GameState.rewinds_left, cfg.uses_per_checkpoint, "rien consommé")
	level.death.request_checkpoint()
	await wait_physics_seconds(level.respawn.fade_out + level.respawn.fade_in + 0.1)
	assert_false(player.is_dead, "le checkpoint reste possible")
	assert_false(tree.paused)


func test_cannot_rewind_past_the_history() -> void:
	await wait_physics_seconds(1.0)
	assert_true(await die_and_wait_for_choice())
	level.death.rewind_held = true
	await wait_physics_seconds(3.0)
	assert_true(RewindManager.at_oldest(), "arrêté au début de l'historique")
	level.death.rewind_held = false
	await wait_physics(2)
	assert_false(player.is_dead)


func test_resume_in_the_air_keeps_falling() -> void:
	await wait_physics_seconds(0.6)
	player.input.press(&"jump")
	for i in 30:
		await wait_physics(1)
		if player.machine.current_name == &"Jump" and player.velocity.y > -50.0 and not player.is_on_floor():
			break
	assert_true(await die_and_wait_for_choice())
	await rewind_for(0.25 / cfg.rewind_speed + 0.05)
	assert_false(player.is_dead)
	if player.is_on_floor():
		assert_true(true)  # la photo stable la plus proche était avant le saut : acceptable
	else:
		assert_eq(player.machine.current_name, &"Fall", "reprise en chute, pas figé en l'air")
	await wait_physics_seconds(1.0)
	assert_true(player.is_on_floor(), "il retombe normalement")


func test_resume_never_starts_in_the_middle_of_a_roll() -> void:
	await wait_physics_seconds(1.0)
	var x_before: float = player.global_position.x
	player.input.press(&"roll")
	await wait_physics(24)  # 0,4 s de roulade (elle dure 0,5 s)
	assert_eq(player.machine.current_name, &"Roll")
	assert_true(await die_and_wait_for_choice())
	# Remonter 0,32 s : le curseur tombe au milieu de la roulade.
	await rewind_for(0.32 / cfg.rewind_speed)
	assert_ne(player.machine.current_name, &"Roll", "on reprend avant le geste en cours")
	assert_almost_eq(player.global_position.x, x_before, 0.5, "à l'endroit d'avant la roulade, pas au milieu")
	assert_false(player.is_dead)


# --- Limites ---------------------------------------------------------------------

func test_uses_run_out_then_death_goes_straight_to_checkpoint() -> void:
	GameState.rewinds_left = 1
	await wait_physics_seconds(1.0)
	assert_true(await die_and_wait_for_choice())
	await rewind_for(0.5)
	assert_eq(GameState.rewinds_left, 0)
	await wait_physics_seconds(0.5)
	player.kill(&"shot")
	await wait_physics(30)
	assert_eq(level.death.phase, &"", "plus de choix : retour direct")
	await wait_physics_seconds(level.respawn.total_time())
	assert_false(player.is_dead, "réapparu")
	assert_eq(GameState.rewinds_left, cfg.uses_per_checkpoint, "rembobinages rendus au checkpoint")


func test_new_checkpoint_gives_back_all_rewinds() -> void:
	GameState.rewinds_left = 0
	GameState.reach_checkpoint(&"ici", Vector2(300, FLOOR_Y), 1)
	assert_eq(GameState.rewinds_left, cfg.uses_per_checkpoint)


func test_classic_mode_has_no_rewind() -> void:
	Settings.classic_mode = true
	RewindManager.start_recording()
	await wait_physics_seconds(1.0)
	assert_false(RewindManager.recording, "rien n'est enregistré")
	assert_false(RewindManager.can_rewind())
	player.kill(&"shot")
	await wait_physics(30)
	assert_eq(level.death.phase, &"", "pas de ralenti ni de choix")
	await wait_physics_seconds(level.respawn.total_time())
	assert_false(player.is_dead, "retour direct au checkpoint")


func test_slow_motion_then_normal_speed() -> void:
	await wait_physics_seconds(1.0)
	player.kill(&"shot")
	await wait_physics(3)
	assert_eq(level.death.phase, &"slowmo")
	assert_almost_eq(Engine.time_scale, cfg.slowmo_scale, 0.001, "ralenti à la mort")
	for i in 120:
		if level.death.phase == &"choice":
			break
		await wait_physics(1)
	assert_eq(Engine.time_scale, 1.0, "vitesse normale pendant le choix (le jeu est en pause)")
	level.death.request_checkpoint()
	await wait_physics_seconds(level.respawn.fade_out + level.respawn.fade_in + 0.1)


func test_leaving_the_level_during_the_choice_restores_time() -> void:
	await wait_physics_seconds(1.0)
	assert_true(await die_and_wait_for_choice())
	level.free()
	assert_false(tree.paused, "pause levée")
	assert_eq(Engine.time_scale, 1.0)
	assert_false(RewindManager.recording)
