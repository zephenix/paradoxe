extends PlayerState
## À l'arrêt, debout. Point de départ de presque toutes les actions au sol.


func enter(_previous: StringName, _data: Dictionary) -> void:
	player.set_crouched(false)
	player.visual.play(&"idle")


func physics_update(delta: float) -> void:
	var p: Player = player
	if handle_ground_actions():
		return
	if handle_combat_actions():
		return
	if handle_throw_action():
		return
	if p.input.move != 0:
		if p.input.move != p.facing:
			machine.transition_to(&"Turn")
		elif p.input.run:
			machine.transition_to(&"Run")
		elif not edge_guard_stops():
			machine.transition_to(&"Walk")
	p.move_on_ground(0.0, delta)
