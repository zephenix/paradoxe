extends PlayerState
## Accroupi, immobile. On ne se relève que s'il y a la place.


func enter(previous: StringName, data: Dictionary) -> void:
	player.set_crouched(true)
	player.visual.play(&"crouch")
	# Bruit de vêtements en s'accroupissant (pas en passant de CrouchWalk à Crouch).
	if previous != &"CrouchWalk" and not data.get("resumed", false):
		player.anim_event.emit(&"crouch")


func physics_update(delta: float) -> void:
	var p: Player = player
	if p.lost_ground():
		machine.transition_to(&"Fall")
		return
	# Tirer ou se protéger : Élias se relève pour dégainer (s'il y a la place).
	if handle_combat_actions():
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
