extends PlayerState
## Marche accroupie : lente et silencieuse (compte pour l'infiltration en J6).


func enter(_previous: StringName, _data: Dictionary) -> void:
	player.set_crouched(true)
	player.visual.play(&"crouch_walk")


func physics_update(delta: float) -> void:
	var p: Player = player
	if p.lost_ground():
		machine.transition_to(&"Fall")
		return
	if not p.input.down and p.can_stand():
		machine.transition_to(&"Walk" if p.input.move != 0 else &"Idle")
		return
	if p.input.move == 0 or edge_guard_stops():
		machine.transition_to(&"Crouch")
		return
	p.facing = p.input.move
	p.move_on_ground(p.facing * p.config.crouch_walk_speed, delta)
