extends TestCase
## Tests des outils d'infiltration (J6) : pierres (ramasser, lancer, diversion),
## « Voir les sons », niveau d'alerte global, rembobinage.
##
## Arène : sol à y = 480, dans une salle (Room) éclairée normalement.

const ELIAS: PackedScene = preload("res://scenes/player/elias.tscn")
const SENTINEL: PackedScene = preload("res://scenes/enemies/sentinel.tscn")
const B: float = 48.0
const FLOOR_Y: float = 480.0

var arena: Node2D
var player: Player
var _saved_show_sounds: bool
var _saved_path: String


func before_each() -> void:
	Settings.classic_mode = false
	_saved_show_sounds = Settings.show_sounds
	_saved_path = Settings.file_path
	Settings.file_path = "user://test_stealth_settings.cfg"
	arena = add_node(Node2D.new())
	var room := Room.new()
	room.position = Vector2(-20, -10) * B
	room.room_size = Vector2(80, 24) * B
	arena.add_child(room)
	block(-20, 10, 80, 4)


func after_each() -> void:
	Settings.classic_mode = false
	Settings.show_sounds = _saved_show_sounds
	Settings.file_path = _saved_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_stealth_settings.cfg"))


func block(x: float, y: float, w: float, h: float) -> SolidBlock:
	var solid := SolidBlock.new()
	solid.position = Vector2(x, y) * B
	solid.size_blocks = Vector2(w, h)
	arena.add_child(solid)
	return solid


func spawn_player(x: float, facing: int = 1) -> void:
	player = ELIAS.instantiate()
	player.position = Vector2(x, FLOOR_Y)
	player.start_facing = facing
	player.get_node("Foley").free()
	arena.add_child(player)
	player.input.from_devices = false
	await wait_physics(3)


func spawn_sentinel(x: float, facing: int) -> Sentinel:
	var s: Sentinel = SENTINEL.instantiate()
	s.position = Vector2(x, FLOOR_Y)
	s.start_facing = facing
	s.patrol_left_blocks = 0.0
	s.patrol_right_blocks = 0.0
	arena.add_child(s)
	return s


func stones_in_flight() -> Array[ThrownStone]:
	var found: Array[ThrownStone] = []
	for node in tree.get_nodes_in_group(&"projectiles"):
		if node is ThrownStone and not node.is_queued_for_deletion():
			found.append(node)
	return found


# --- Pierres ---------------------------------------------------------------------

func test_rubble_pile_gives_stones() -> void:
	var pile := RubblePile.new()
	pile.position = Vector2(300, FLOOR_Y)
	arena.add_child(pile)
	await spawn_player(100.0)
	assert_eq(player.stones, 0)
	player.input.move = 1
	await wait_physics_seconds(2.0)
	player.input.move = 0
	assert_eq(player.stones, player.throw_config.max_stones, "on ramasse de quoi remplir ses poches")


func test_throw_needs_a_stone() -> void:
	await spawn_player(100.0)
	player.input.press(&"throw")
	await wait_physics(10)
	assert_ne(player.machine.current_name, &"Throw", "sans pierre, pas de lancer")


func test_stone_flies_in_an_arc_and_makes_a_noise_where_it_lands() -> void:
	await spawn_player(100.0)
	player.stones = 2
	var noises: Array[Array] = []
	var on_noise := func(at: Vector2, radius: float, source: Node) -> void: noises.append([at, radius, source])
	AudioManager.noise_emitted.connect(on_noise)
	player.input.press(&"throw")
	await wait_physics(3)
	assert_eq(player.machine.current_name, &"Throw", "le geste commence")
	await wait_physics_seconds(player.throw_config.release_time)
	assert_eq(player.stones, 1, "une pierre en moins")
	var stones: Array[ThrownStone] = stones_in_flight()
	assert_eq(stones.size(), 1, "une pierre en vol")
	var stone: ThrownStone = stones[0]
	var landed: Array[Vector2] = []
	stone.landed.connect(func(at: Vector2) -> void: landed.append(at))
	await wait_physics_seconds(2.0)
	AudioManager.noise_emitted.disconnect(on_noise)
	assert_eq(landed.size(), 1, "la pierre retombe")
	var distance: float = landed[0].x - 100.0
	assert_true(distance > player.throw_config.flat_range() * 0.8, "elle porte loin (%.0f px)" % distance)
	var impact_radius: float = AudioManager.library.get_entry(&"stone_impact").noise_radius
	var heard: Array = noises.filter(func(n: Array) -> bool: return is_equal_approx(n[1], impact_radius))
	assert_eq(heard.size(), 1, "un bruit à l'impact")
	assert_eq(heard[0][2], player, "c'est Élias qui l'a causé")
	assert_eq(player.machine.current_name, &"Idle", "le geste est fini")


func test_stone_lures_a_sentinel() -> void:
	await spawn_player(100.0)
	player.stones = 1
	# Une Sentinelle dos tournée, au loin : elle entend la pierre et va voir.
	var s: Sentinel = spawn_sentinel(900.0, 1)
	await wait_physics(3)
	player.input.press(&"throw")
	var clue: Array[Vector2] = []
	await wait_physics_seconds(player.throw_config.release_time + 0.05)
	stones_in_flight()[0].landed.connect(func(at: Vector2) -> void: clue.append(at))
	await wait_physics_seconds(1.5)
	assert_eq(clue.size(), 1)
	assert_true(s.machine.current_name in [&"Suspicious", &"Search"], "intriguée (%s)" % s.machine.current_name)
	assert_eq(s.facing, -1, "elle se tourne vers le bruit")
	assert_almost_eq(s.last_clue.x, clue[0].x, 1.0, "là où la pierre est tombée")


func test_crouched_throw_keeps_elias_down() -> void:
	await spawn_player(100.0)
	player.stones = 1
	player.input.down = true
	await wait_physics(15)
	player.input.press(&"throw")
	await wait_physics_seconds(player.throw_config.duration + 0.1)
	assert_eq(player.stones, 0)
	assert_true(player.is_crouched, "il reste accroupi")
	assert_eq(player.machine.current_name, &"Crouch")


func test_a_stone_breaks_a_lamp() -> void:
	await spawn_player(100.0)
	var lamp := LightSource.new()
	arena.add_child(lamp)
	var stone := ThrownStone.new()
	stone.setup(player, Vector2(600, 0), player.throw_config)
	arena.add_child(stone)
	stone.global_position = Vector2(200, 300)
	lamp.global_position = Vector2(260, 310)
	await wait_physics(20)
	assert_false(lamp.lit, "la lampe est brisée")


func test_rewind_restores_stones_and_clears_those_in_flight() -> void:
	await spawn_player(100.0)
	player.stones = 3
	var photo: Dictionary = player.capture_state()
	player.input.press(&"throw")
	await wait_physics_seconds(player.throw_config.release_time + 0.05)
	assert_eq(player.stones, 2)
	assert_eq(stones_in_flight().size(), 1)
	player.apply_state(photo)
	assert_eq(player.stones, 3, "pierre rendue par le rembobinage")
	RewindManager.start_recording()
	RewindManager.begin_rewind()
	RewindManager.cancel_rewind()
	RewindManager.recording = false
	RewindManager.clear()
	await wait_physics(1)
	assert_eq(stones_in_flight().size(), 0, "le rembobinage efface les pierres en vol")


# --- Voir les sons -------------------------------------------------------------------

func test_noise_rings_show_elias_noises_only_when_enabled() -> void:
	var rings := NoiseRings.new()
	arena.add_child(rings)
	await spawn_player(100.0)
	var s: Sentinel = spawn_sentinel(900.0, 1)
	Settings.show_sounds = false
	AudioManager.emit_noise(Vector2(100, FLOOR_Y), 300.0, player)
	assert_eq(rings.rings.size(), 0, "option désactivée : rien")
	Settings.show_sounds = true
	AudioManager.emit_noise(Vector2(100, FLOOR_Y), 300.0, player)
	assert_eq(rings.rings.size(), 1, "un cercle")
	assert_almost_eq(rings.rings[0][1], 300.0, 0.001, "de la taille exacte du rayon de bruit")
	AudioManager.emit_noise(Vector2(900, FLOOR_Y), 650.0, s)
	assert_eq(rings.rings.size(), 1, "les bruits des Sentinelles ne sont pas montrés")
	await wait_seconds(NoiseRings.LIFE + 0.1)
	assert_eq(rings.rings.size(), 0, "le cercle s'efface")


func test_show_sounds_setting_is_saved() -> void:
	Settings.show_sounds = true
	assert_eq(Settings.save_settings(), OK)
	Settings.show_sounds = false
	Settings.load_settings()
	assert_true(Settings.show_sounds, "réglage relu")


# --- Niveau d'alerte ------------------------------------------------------------------

func test_level_reports_the_global_alert_level() -> void:
	var level: Level = load("res://scenes/levels/test_level.tscn").instantiate()
	level.get_node("Elias/Foley").free()
	add_node(level)
	level.player.input.from_devices = false
	level.death.input_from_devices = false
	await wait_physics(3)
	var levels: Array[float] = []
	var listener := func(value: float) -> void: levels.append(value)
	Events.alert_level_changed.connect(listener)
	var s: Sentinel = level.get_node("RoomG/Sentinel1")
	s.hear(s.global_position + Vector2(-100, 0), 0.6)
	await wait_physics(3)
	assert_almost_eq(level.alert_level, s.suspicion, 0.05, "le plus inquiet des ennemis")
	s.machine.transition_to(&"Combat")
	await wait_physics(3)
	assert_almost_eq(level.alert_level, 1.0, 0.001, "combat : alerte maximale")
	Events.alert_level_changed.disconnect(listener)
	assert_true(levels.size() >= 2, "la musique (J8) est prévenue : %s" % [levels])
	assert_almost_eq(levels[-1], 1.0, 0.001)
	level.free()
	AudioManager.set_zone(&"", 0.0)
