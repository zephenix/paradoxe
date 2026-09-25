extends PlayerState
## Accroupi, immobile. On ne se relève que s'il y a la place.


func enter(_previous: StringName, _data: Dictionary) -> void:
	player.set_crouched(true)
	player.visual.play(&"crouch")


func physics_update(delta: float) -> void:
	var p: Player = player
	if not p.is_on_floor() and p.time_since_grounded > 0.05:
		machine.transition_to(&"Fall")
		return
	if p.wants(&"roll"):
		machine.transition_to(&"Roll", {"landing": false})
		return
	if not p.input.down and p.can_stand():
		machine.transition_to(&"Idle")
		return
	if p.input.move != 0:
		p.facing = p.input.move
		machine.transition_to(&"CrouchWalk")
		return
	p.move_on_ground(0.0, delta)
