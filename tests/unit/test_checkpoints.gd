extends TestCase
## Tests des checkpoints, de la mort et de la réapparition (Level + GameState).
##
## Petit niveau construit par le code : une salle d'un écran (sol à y = 480),
## Élias à x = 100, un checkpoint à x = 400, une Sentinelle à x = 1100.

const ELIAS: PackedScene = preload("res://scenes/player/elias.tscn")
const CHECKPOINT: PackedScene = preload("res://scenes/props/checkpoint.tscn")
const SENTINEL: PackedScene = preload("res://scenes/enemies/sentinel.tscn")
const B: float = 48.0
const FLOOR_Y: float = 480.0

var level: Level
var player: Player
var checkpoint: Checkpoint


func before_each() -> void:
	GameState.new_game()
	level = Level.new()
	var room := Room.new()
	room.room_size = Vector2(1280, 720)
	level.add_child(room)
	var ground := SolidBlock.new()
	ground.position = Vector2(-2, 10) * B
	ground.size_blocks = Vector2(40, 4)
	room.add_child(ground)
	checkpoint = CHECKPOINT.instantiate()
	checkpoint.name = "CheckpointA"
	checkpoint.position = Vector2(400, FLOOR_Y)
	checkpoint.facing = -1
	room.add_child(checkpoint)
	player = ELIAS.instantiate()
	player.name = "Elias"
	player.position = Vector2(100, FLOOR_Y)
	player.get_node("Foley").free()
	level.add_child(player)
	var camera := CameraDirector.new()
	camera.name = "CameraDirector"
	level.add_child(camera)
	add_node(level)
	player.input.from_devices = false
	await wait_physics(3)


func after_each() -> void:
	GameState.new_game()


func walk_onto_checkpoint() -> void:
	player.input.move = 1
	for i in 240:
		if GameState.has_checkpoint():
			break
		await wait_physics(1)
	player.input.move = 0


func test_level_start_forgets_previous_game() -> void:
	GameState.reach_checkpoint(&"old", Vector2(5, 5), 1)
	var other := Level.new()
	var elias: Player = ELIAS.instantiate()
	elias.name = "Elias"
	elias.get_node("Foley").free()
	other.add_child(elias)
	var camera := CameraDirector.new()
	camera.name = "CameraDirector"
	other.add_child(camera)
	add_node(other)
	assert_false(GameState.has_checkpoint(), "charger un niveau commence une nouvelle partie")


func test_touching_checkpoint_records_it_once() -> void:
	var reached: Array[StringName] = []
	var listener := func(id: StringName) -> void: reached.append(id)
	Events.checkpoint_reached.connect(listener)
	await walk_onto_checkpoint()
	await wait_physics(30)
	Events.checkpoint_reached.disconnect(listener)
	assert_eq(reached, [&"CheckpointA"] as Array[StringName], "un seul signal, même en restant dessus")
	assert_eq(GameState.checkpoint_position, checkpoint.global_position)
	assert_eq(GameState.checkpoint_facing, -1)
	assert_true(checkpoint.is_active, "balise allumée")


func test_dead_player_does_not_trigger_checkpoint() -> void:
	player.kill(&"shot")
	player.global_position = checkpoint.global_position
	await wait_physics(10)
	assert_false(GameState.has_checkpoint())


func test_only_the_latest_checkpoint_is_active() -> void:
	var second: Checkpoint = CHECKPOINT.instantiate()
	second.name = "CheckpointB"
	second.position = Vector2(800, FLOOR_Y)
	level.add_child(second)
	await walk_onto_checkpoint()
	GameState.reach_checkpoint(second.id(), second.global_position, 1)
	assert_false(checkpoint.is_active, "l'ancien s'éteint")
	assert_true(second.is_active)


func test_death_without_checkpoint_respawns_at_start() -> void:
	player.input.move = 1
	await wait_physics(20)
	player.input.move = 0
	player.kill(&"shot")
	await wait_physics_seconds(level.respawn.total_time() + 0.2)
	assert_false(player.is_dead)
	assert_almost_eq(player.global_position.x, 100.0, 1.0, "point de départ")


func test_death_respawns_at_checkpoint_quickly_with_full_energy() -> void:
	await walk_onto_checkpoint()
	player.input.move = 1
	await wait_physics(30)
	player.input.move = 0
	player.energy.try_spend(5.0)
	player.kill(&"shot")
	assert_true(level.respawn.total_time() < 2.0, "retour en jeu en moins de 2 s (PLAN §5.7)")
	await wait_physics_seconds(level.respawn.total_time() + 0.1)
	assert_false(player.is_dead, "réapparu")
	assert_almost_eq(player.global_position.x, checkpoint.global_position.x, 1.0, "au checkpoint")
	assert_eq(player.facing, -1, "tourné comme le checkpoint le demande")
	assert_almost_eq(player.energy.value, player.energy.config.capacity, 0.001, "jauge pleine")


func test_respawn_clears_projectiles_in_flight() -> void:
	var shot := Projectile.new()
	shot.setup(null, Projectile.TEAM_ENEMY, -1, 10.0, false, WeaponConfig.new())
	level.add_child(shot)
	shot.global_position = Vector2(1000, 300)
	player.kill(&"fall")
	await wait_physics_seconds(level.respawn.total_time() + 0.1)
	assert_false(is_instance_valid(shot), "tir effacé à la réapparition")


func test_respawn_puts_sentinels_back_on_duty() -> void:
	var sentinel: Sentinel = SENTINEL.instantiate()
	sentinel.position = Vector2(1100, FLOOR_Y)
	sentinel.patrol_left_blocks = 0.0  # poste fixe : sa position ne bouge pas après la remise en place
	sentinel.patrol_right_blocks = 0.0
	level.add_child(sentinel)
	await wait_physics(2)
	sentinel.die()
	player.kill(&"shot")
	await wait_physics_seconds(level.respawn.total_time() + 0.1)
	assert_false(sentinel.is_dead, "la Sentinelle tuée depuis le checkpoint revient")
	assert_almost_eq(sentinel.global_position.x, 1100.0, 1.0)
