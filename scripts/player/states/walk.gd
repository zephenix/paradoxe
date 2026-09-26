extends PlayerState
## Marche. S'arrête seul au bord d'un vide dangereux (garde-bord, sauf mode classique).


func enter(_previous: StringName, _data: Dictionary) -> void:
	player.set_crouched(false)
	player.visual.play(&"walk")


func physics_update(delta: float) -> void:
	var p: Player = player
	if handle_ground_actions():
		return
	if handle_combat_actions():
		return
	if handle_throw_action():
		return
	if p.input.move == 0 or edge_guard_stops():
		machine.transition_to(&"Idle")
		return
	if p.input.move != p.facing:
		machine.transition_to(&"Turn")
		return
	if p.input.run:
		machine.transition_to(&"Run")
		return
	p.move_on_ground(p.facing * p.config.walk_speed, delta)
