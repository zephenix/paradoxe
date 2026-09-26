extends TestCase
## Tests des objets interactifs (J7) : leviers, plaque de pression, portes,
## ascenseur, terminal, objet à ramasser, et le geste « Interagir » d'Élias.
##
## Arène : sol à y = 480. Élias est piloté par ses intentions.

const ELIAS: PackedScene = preload("res://scenes/player/elias.tscn")
const B: float = 48.0
const FLOOR_Y: float = 480.0

var arena: Node2D
var player: Player


func before_each() -> void:
	Settings.classic_mode = false
	GameState.new_game()
	arena = add_node(Node2D.new())
	block(-20, 10, 80, 4)


func after_each() -> void:
	GameState.new_game()
	AudioManager.stop_loop(Elevator.LOOP_ID, 0.0)


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


func lever(x: float, hold: float = 0.0) -> Lever:
	var l := Lever.new()
	l.position = Vector2(x, FLOOR_Y)
	l.hold_time = hold
	arena.add_child(l)
	return l


func door(x: float, switches: Array[Node], all: bool = false, latched: bool = false) -> Door:
	var d := Door.new()
	d.position = Vector2(x, FLOOR_Y - 3 * B)
	d.size_blocks = Vector2(0.5, 3)
	d.require_all = all
	d.latch = latched
	arena.add_child(d)
	var paths: Array[NodePath] = []
	for node in switches:
		paths.append(d.get_path_to(node))
	d.switches = paths
	d.connect_switches()
	return d


# --- Leviers et portes ---------------------------------------------------------------

func test_toggle_lever_and_spring_lever() -> void:
	var toggle: Lever = lever(100.0)
	var spring: Lever = lever(200.0, 0.5)
	await wait_physics(1)
	toggle.interact(null)
	assert_true(toggle.on, "à bascule : enclenché")
	toggle.interact(null)
	assert_false(toggle.on, "à bascule : relâché")
	spring.interact(null)
	assert_true(spring.on)
	await wait_physics_seconds(0.6)
	assert_false(spring.on, "à ressort : revenu seul")


func test_door_needs_both_levers_at_once_and_latches() -> void:
	var a: Lever = lever(100.0, 1.0)
	var b: Lever = lever(400.0, 1.0)
	var d: Door = door(600.0, [a, b], true, true)
	await wait_physics(2)
	a.interact(null)
	await wait_physics_seconds(1.2)  # a est revenu avant que b soit actionné
	b.interact(null)
	await wait_physics_seconds(1.0)
	assert_false(d.is_open(), "l'un après l'autre : rien")
	a.interact(null)
	b.interact(null)
	await wait_physics_seconds(d.move_time + 0.1)
	assert_true(d.is_open(), "ensemble : ouverte")
	await wait_physics_seconds(1.5)
	assert_true(d.is_open(), "et elle le reste (verrouillée ouverte)")
	assert_eq(d.collision_layer, 0, "ouverte : on passe")


func test_pressure_plate_holds_a_door_open() -> void:
	var plate := PressurePlate.new()
	plate.position = Vector2(300, FLOOR_Y)
	arena.add_child(plate)
	var d: Door = door(600.0, [plate])
	await spawn_player(100.0)
	assert_false(d.is_open())
	player.global_position = Vector2(300, FLOOR_Y)
	await wait_physics_seconds(d.move_time + 0.2)
	assert_true(plate.on, "Élias sur la plaque")
	assert_true(d.is_open(), "la porte s'ouvre")
	player.global_position = Vector2(100, FLOOR_Y)
	await wait_physics_seconds(d.move_time + 0.2)
	assert_false(plate.on)
	assert_false(d.is_open(), "plus personne : elle se referme")
	assert_eq(d.collision_layer, PhysicsLayers.WORLD, "fermée : elle bloque")


func test_closed_door_blocks_elias() -> void:
	var d: Door = door(300.0, [])
	await spawn_player(100.0)
	player.input.move = 1
	await wait_physics_seconds(3.0)
	assert_true(player.global_position.x < 300.0, "arrêté par la porte (x = %.0f)" % player.global_position.x)
	d.trigger()
	await wait_physics_seconds(3.0)
	assert_true(player.global_position.x > 320.0, "porte ouverte par une impulsion : il passe")


# --- Ascenseur et terminal -----------------------------------------------------------

func test_elevator_carries_elias_up_and_terminal_calls_it() -> void:
	block(-20, 3, 30, 0.5)  # palier du haut : dessus à y = 144 (x de -960 à 480)
	var elevator := Elevator.new()
	elevator.position = Vector2(480, FLOOR_Y)
	elevator.width_blocks = 3.0
	elevator.travel = Vector2(0, -(FLOOR_Y - 144.0))
	arena.add_child(elevator)
	# Le plancher sous la plate-forme : elle repose dans une fosse (sol plus bas).
	var terminal := Terminal.new()
	terminal.position = Vector2(400, 144)
	arena.add_child(terminal)
	terminal.targets = [terminal.get_path_to(elevator)]
	await spawn_player(550.0)
	player.global_position = Vector2(550, FLOOR_Y)
	await wait_physics(10)
	assert_true(player.is_on_floor(), "Élias sur la plate-forme")
	elevator.trigger()
	await wait_physics_seconds((FLOOR_Y - 144.0) / elevator.speed + 0.5)
	assert_true(elevator.is_at_top(), "arrivé en haut (progress %.2f goal %.1f y %.0f)" % [elevator.progress, elevator.goal, elevator.global_position.y])
	assert_almost_eq(player.global_position.y, 144.0, 3.0, "Élias emporté en haut")
	terminal.interact(player)
	await wait_physics_seconds(0.5)
	assert_false(elevator.is_at_top(), "le terminal le renvoie en bas")


func test_spring_lever_sends_the_elevator() -> void:
	var l: Lever = lever(100.0, 0.5)
	var elevator := Elevator.new()
	elevator.position = Vector2(480, FLOOR_Y)
	elevator.travel = Vector2(0, -96)
	arena.add_child(elevator)
	elevator.switches = [elevator.get_path_to(l)]
	elevator.connect_switches()
	await wait_physics(1)
	l.interact(null)
	await wait_physics_seconds(96.0 / elevator.speed + 0.3)
	assert_true(elevator.is_at_top(), "une impulsion : en haut")
	await wait_physics_seconds(0.6)  # le levier revient : pas d'impulsion
	assert_true(elevator.is_at_top(), "il y reste")
	l.interact(null)
	await wait_physics_seconds(96.0 / elevator.speed + 0.3)
	assert_true(elevator.is_at_bottom(), "nouvelle impulsion : en bas")


# --- Objet à ramasser et geste d'Élias ---------------------------------------------

func test_elias_interacts_with_what_is_in_front_of_him() -> void:
	var l: Lever = lever(135.0)
	var behind: Lever = lever(75.0)  # plus près que l'autre, mais derrière lui
	await spawn_player(100.0, 1)
	player.input.press(&"interact")
	await wait_physics(3)
	assert_eq(player.machine.current_name, &"Interact", "le geste")
	await wait_physics_seconds(player.config.interact_duration)
	assert_true(l.on, "le levier devant lui")
	assert_false(behind.on, "pas celui derrière lui")
	assert_eq(player.machine.current_name, &"Idle")


func test_nothing_in_reach_means_no_gesture() -> void:
	lever(400.0)
	await spawn_player(100.0, 1)
	player.input.press(&"interact")
	await wait_physics(5)
	assert_ne(player.machine.current_name, &"Interact")


func test_picking_up_the_pistol_gives_the_weapon_back() -> void:
	GameState.remove_item(&"pistol")
	assert_true(GameState.unarmed)
	var pickup := ItemPickup.new()
	pickup.position = Vector2(130, FLOOR_Y)
	pickup.item = &"pistol"
	arena.add_child(pickup)
	await spawn_player(100.0, 1)
	player.input.press(&"fire")
	await wait_physics(10)
	assert_ne(player.machine.current_name, &"Aim", "désarmé : il ne dégaine pas")
	player.input.press(&"interact")
	await wait_physics_seconds(player.config.interact_duration + 0.1)
	assert_true(pickup.taken)
	assert_true(GameState.has_item(&"pistol"))
	assert_false(GameState.unarmed, "il a retrouvé son arme")
	player.input.press(&"fire")
	await wait_physics(5)
	assert_eq(player.machine.current_name, &"Aim", "il peut de nouveau dégainer")


# --- Rembobinage ------------------------------------------------------------------------

func test_mechanisms_follow_the_rewind() -> void:
	var l: Lever = lever(100.0)
	var d: Door = door(600.0, [l])
	var pickup := ItemPickup.new()
	pickup.item = &"cle"
	arena.add_child(pickup)
	await wait_physics(1)
	var photos: Array[Dictionary] = [l.capture_state(), d.capture_state(), pickup.capture_state()]
	l.interact(null)
	await spawn_player(0.0)
	pickup.interact(player)
	await wait_physics_seconds(d.move_time + 0.1)
	assert_true(d.is_open())
	assert_true(GameState.has_item(&"cle"))
	l.apply_state(photos[0])
	d.apply_state(photos[1])
	pickup.apply_state(photos[2])
	assert_false(l.on, "levier revenu")
	assert_false(d.is_open(), "porte refermée")
	assert_eq(d.collision_layer, PhysicsLayers.WORLD)
	assert_false(pickup.taken, "objet de nouveau là")
	assert_false(GameState.has_item(&"cle"), "et plus dans l'inventaire")
