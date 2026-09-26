extends TestCase
## Tests de la machine à états générique (indépendamment du joueur).

## État de test qui note ce qui lui arrive. S'il reçoit {"redirect": nom}, il
## demande lui-même un autre état depuis enter() (cas de LedgeDescend).
class Probe extends State:
	var log: Array[String] = []

	func enter(previous: StringName, data: Dictionary) -> void:
		log.append("enter %s from %s %s" % [name, previous, data.get("tag", "")])
		if data.has("redirect"):
			machine.transition_to(data["redirect"])

	func exit() -> void:
		log.append("exit %s" % name)


var machine: StateMachine
var a: Probe
var b: Probe


func before_each() -> void:
	machine = StateMachine.new()
	machine.initial_state = &"A"
	a = Probe.new()
	a.name = "A"
	b = Probe.new()
	b.name = "B"
	machine.add_child(a)
	machine.add_child(b)
	add_node(machine)
	machine.setup(machine)


func test_starts_in_initial_state() -> void:
	assert_eq(machine.current_name, &"A")
	assert_eq(a.log, ["enter A from  "] as Array[String])


func test_transition_calls_exit_then_enter_with_data() -> void:
	var changes: Array[Array] = []
	machine.state_changed.connect(func(from: StringName, to: StringName) -> void: changes.append([from, to]))
	machine.transition_to(&"B", {"tag": "x"})
	assert_eq(a.log.back(), "exit A")
	assert_eq(b.log.back(), "enter B from A x")
	assert_eq(machine.previous_name, &"A")
	assert_eq(changes, [[&"A", &"B"]])


func test_time_in_state_counts_and_resets() -> void:
	machine.physics_update(0.5)
	machine.physics_update(0.25)
	assert_almost_eq(a.time_in_state, 0.75)
	machine.transition_to(&"B")
	assert_almost_eq(b.time_in_state, 0.0)


func test_every_player_state_has_a_script_and_animation() -> void:
	var elias: Node = load("res://scenes/player/elias.tscn").instantiate()
	var states: Node = elias.get_node("StateMachine")
	assert_eq(states.get_child_count(), 22, "16 états de déplacement + 4 de combat + lancer (J6) + interagir (J7)")
	for child in states.get_children():
		assert_true(child is PlayerState, "%s hérite de PlayerState" % child.name)
	elias.free()
	# Toutes les animations demandées par les états (visual.play(&"…")) existent
	# dans les tables : on les relève directement dans le code des états.
	var regex := RegEx.create_from_string("visual\\.play\\(&\"([a-z_]+)\"")
	var requested: Array[String] = []
	for file in DirAccess.get_files_at("res://scripts/player/states"):
		if file.ends_with(".gd"):
			for m in regex.search_all(FileAccess.get_file_as_string("res://scripts/player/states".path_join(file))):
				requested.append(m.get_string(1))
	assert_true(requested.size() >= 20, "animations trouvées : %s" % [requested])
	for anim_name in requested:
		assert_true(EliasPoses.ANIMATIONS.has(anim_name), "animation %s" % anim_name)


func test_transition_requested_from_enter_keeps_signal_order() -> void:
	var c := Probe.new()
	c.name = "C"
	machine.add_child(c)
	machine.setup(machine)
	var changes: Array[Array] = []
	machine.state_changed.connect(func(from: StringName, to: StringName) -> void: changes.append([from, to]))
	machine.transition_to(&"B", {"redirect": &"C"})
	assert_eq(machine.current_name, &"C", "l'état demandé depuis enter() est bien appliqué")
	assert_eq(changes, [[&"A", &"B"], [&"B", &"C"]], "signaux dans l'ordre réel")
	assert_eq(machine.previous_name, &"B")
