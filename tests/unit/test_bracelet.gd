extends TestCase
## Tests du bracelet holographique et du ramassage des pierres (J9, PLAN §5.10).
##
## Arène : sol à y = 480, dans une salle (Room) éclairée normalement.

const ELIAS: PackedScene = preload("res://scenes/player/elias.tscn")
const B: float = 48.0
const FLOOR_Y: float = 480.0

var arena: Node2D
var room: Room
var player: Player
var played: Array[StringName] = []


func before_each() -> void:
	Settings.classic_mode = false
	Settings.infinite_rewinds = false
	played.clear()
	AudioManager.sfx_played.connect(_on_played)
	arena = add_node(Node2D.new())
	room = Room.new()
	room.position = Vector2(-20, -10) * B
	room.room_size = Vector2(80, 24) * B
	arena.add_child(room)
	var solid := SolidBlock.new()
	solid.position = Vector2(-20, 10) * B
	solid.size_blocks = Vector2(80, 4)
	arena.add_child(solid)


func after_each() -> void:
	AudioManager.sfx_played.disconnect(_on_played)
	Settings.classic_mode = false
	Settings.infinite_rewinds = false
	GameState.new_game()


func _on_played(id: StringName) -> void:
	played.append(id)


func spawn_player(x: float) -> void:
	player = ELIAS.instantiate()
	player.position = Vector2(x, FLOOR_Y)
	player.get_node("Foley").free()
	arena.add_child(player)
	player.input.from_devices = false
	await wait_physics(3)
	player.bracelet.hide_now()  # (l'énergie remplie au départ a pu l'afficher)
	played.clear()


func add_pile(x: float) -> RubblePile:
	var pile := RubblePile.new()
	pile.position = Vector2(x, FLOOR_Y)
	arena.add_child(pile)
	return pile


# --- La touche « Bracelet » ---------------------------------------------------

func test_bracelet_key_opens_the_hologram_and_elias_looks_at_his_wrist() -> void:
	await spawn_player(100.0)
	assert_false(player.bracelet.is_showing(), "pas d'interface permanente")
	player.input.press(&"bracelet")
	await wait_physics(2)
	assert_true(player.bracelet.is_open, "l'hologramme s'ouvre")
	assert_eq(player.machine.current_name, &"WristCheck", "à l'arrêt, il lève le poignet")
	assert_true(played.has(&"bracelet_open"), "un son l'accompagne")
	var rows: Array[StringName] = player.bracelet.visible_rows()
	for row: StringName in [&"energy", &"pockets", &"rewinds"]:
		assert_true(rows.has(row), "ligne %s affichée : %s" % [row, rows])
	await wait_physics_seconds(player.bracelet.config.show_time + player.bracelet.config.fade_time + 0.1)
	assert_false(player.bracelet.is_showing(), "il s'efface tout seul")
	assert_eq(player.machine.current_name, &"Idle", "et Élias baisse le bras")


func test_a_second_press_closes_it() -> void:
	await spawn_player(100.0)
	player.input.press(&"bracelet")
	await wait_physics(2)
	player.input.press(&"bracelet")
	await wait_physics(2)
	assert_false(player.bracelet.is_open)
	assert_true(played.has(&"bracelet_close"))
	assert_eq(player.machine.current_name, &"Idle")
	await wait_physics_seconds(player.bracelet.config.fade_time + 0.05)
	assert_false(player.bracelet.is_showing())


func test_the_game_goes_on_while_it_is_open() -> void:
	await spawn_player(100.0)
	player.input.press(&"bracelet")
	await wait_physics(2)
	player.input.move = 1
	await wait_physics(6)
	assert_eq(player.machine.current_name, &"Walk", "une commande fait quitter la pose")
	assert_true(player.bracelet.is_open, "l'hologramme reste ouvert")
	player.input.run = true
	await wait_physics_seconds(0.5)
	player.bracelet.close()
	player.input.press(&"bracelet")
	await wait_physics(2)
	assert_true(player.bracelet.is_open, "il s'ouvre aussi en courant")
	assert_eq(player.machine.current_name, &"Run", "sans arrêter Élias")


func test_death_hides_it() -> void:
	await spawn_player(100.0)
	player.input.press(&"bracelet")
	await wait_physics(2)
	player.kill(&"test")
	assert_false(player.bracelet.is_showing())


# --- Affichages brefs ---------------------------------------------------------

func test_shooting_shows_the_energy_line_only() -> void:
	await spawn_player(100.0)
	player.input.press(&"fire")
	await wait_physics_seconds(0.4)
	assert_false(player.bracelet.is_open, "pas tout l'hologramme")
	assert_eq(player.bracelet.visible_rows(), [&"energy"] as Array[StringName], "seulement l'énergie")
	# Elle reste affichée tant que la jauge se recharge, puis s'efface.
	while player.energy.value < player.energy.config.capacity:
		await wait_physics(10)
	await wait_physics_seconds(player.bracelet.config.brief_time + player.bracelet.config.fade_time + 0.1)
	assert_false(player.bracelet.is_showing(), "puis il s'efface")


func test_rewinds_line_shows_what_is_left_and_disappears_in_classic_mode() -> void:
	await spawn_player(100.0)
	player.bracelet.open()
	assert_true(player.bracelet.visible_rows().has(&"rewinds"))
	Settings.classic_mode = true
	assert_false(player.bracelet.visible_rows().has(&"rewinds"), "mode classique : pas de rembobinage")


func test_hologram_is_not_dimmed_by_the_darkness() -> void:
	await spawn_player(100.0)
	var layer: CanvasLayer = player.bracelet
	assert_true(layer.follow_viewport_enabled, "il se place dans le monde")
	assert_true(layer.layer > 5, "au-dessus du jeu et des textes des salles (hors de la teinte du niveau)")


# --- Objectif -----------------------------------------------------------------

func test_objective_arrow_points_to_the_room_target() -> void:
	var target := Marker2D.new()
	target.name = "Goal"
	target.position = Vector2(40, 20) * B  # (dans la salle) à droite, au sol
	room.add_child(target)
	room.objective = "Atteindre la sortie"
	room.objective_target = room.get_path_to(target)
	await spawn_player(100.0)
	player.bracelet.open()
	assert_true(player.bracelet.visible_rows().has(&"objective"))
	assert_eq(player.bracelet.objective_text(), "Atteindre la sortie")
	var direction: Vector2 = player.bracelet.objective_direction()
	assert_true(direction.x > 0.99, "la flèche pointe vers la cible : %s" % direction)
	player.global_position = target.global_position + Vector2(-20, 0)
	assert_eq(player.bracelet.objective_direction(), Vector2.ZERO, "sur place : plus de flèche")
	room.objective = ""
	assert_false(player.bracelet.visible_rows().has(&"objective"), "salle sans objectif : pas de ligne")


# --- Ramassage ----------------------------------------------------------------

func test_full_pockets_rattle_and_take_nothing() -> void:
	add_pile(160.0)
	await spawn_player(130.0)
	player.stones = player.throw_config.max_stones
	player.input.press(&"interact")
	await wait_physics_seconds(1.0)
	assert_eq(player.stones, player.throw_config.max_stones)
	assert_false(played.has(&"stone_take"), "aucune pierre prise")
	assert_true(played.has(&"stone_pickup"), "les pierres de la poche s'entrechoquent")
	assert_true(player.bracelet.visible_rows().has(&"pockets"), "le compteur plein s'affiche")


func test_crouched_pickup_keeps_elias_down() -> void:
	add_pile(160.0)
	await spawn_player(130.0)
	player.input.down = true
	await wait_physics_seconds(0.3)
	assert_eq(player.machine.current_name, &"Crouch")
	player.input.press(&"interact")
	await wait_physics(2)
	assert_eq(player.machine.current_name, &"PickUp", "on ramasse sans se relever")
	await wait_physics_seconds(1.2)
	assert_eq(player.machine.current_name, &"Crouch", "et on reste accroupi")
	assert_eq(player.stones, player.throw_config.max_stones)


func test_only_the_missing_stones_are_taken() -> void:
	add_pile(160.0)
	await spawn_player(130.0)
	player.stones = player.throw_config.max_stones - 1
	player.input.press(&"interact")
	await wait_physics_seconds(1.0)
	assert_eq(played.count(&"stone_take"), 1, "une seule pierre manquait")
	assert_eq(player.stones, player.throw_config.max_stones)


func test_throwing_shows_the_counter() -> void:
	await spawn_player(100.0)
	player.stones = 2
	player.input.press(&"throw")
	await wait_physics_seconds(0.5)
	assert_eq(player.stones, 1)
	assert_true(player.bracelet.visible_rows().has(&"pockets"))
