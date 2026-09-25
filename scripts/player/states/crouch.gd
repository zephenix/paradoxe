extends PlayerState
## Accroupi, immobile. On ne se relève que s'il y a la place.


func enter(_previous: StringName, _data: Dictionary) -> void:
	player.set_crouched(true)
	player.visual.play(&"crouch")


func physics_update(delta: float) -> void:
	var p: Player = player
	if p.lost_ground():
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
		# Le garde-bord empêche aussi d'avancer accroupi vers un vide dangereux :
		# on reste accroupi (sinon on alternerait avec CrouchWalk à chaque image).
		if not edge_guard_stops():
			machine.transition_to(&"CrouchWalk")
			return
	p.move_on_ground(0.0, delta)
