extends PlayerState
## Course. On ne s'arrête ni ne se retourne d'un coup : avec de l'élan, on
## dérape (état Skid). Le saut avec élan et la glissade demandent eux aussi
## d'avoir pris de la vitesse (voir Player.has_momentum).


func enter(_previous: StringName, _data: Dictionary) -> void:
	player.set_crouched(false)
	player.visual.play(&"run")


func physics_update(delta: float) -> void:
	var p: Player = player
	if p.lost_ground():
		machine.transition_to(&"Fall")
		return
	# En mode classique, aucune action pendant l'image de tolérance sans sol.
	var can_act: bool = p.is_on_floor() or p.modern()
	if can_act and p.wants(&"jump"):
		p.start_jump(&"running" if p.has_momentum() else &"standing")
		return
	if can_act and p.wants(&"roll"):
		machine.transition_to(&"Roll", {"landing": false})
		return
	# Tirer ou se protéger en courant : Élias s'arrête net en dégainant.
	if handle_combat_actions():
		return
	if p.input.down:
		# Glissade avec de l'élan (mode moderne) ; sinon, on s'accroupit.
		machine.transition_to(&"Slide" if p.modern() and p.has_momentum() else &"Crouch")
		return
	if p.input.move == 0:
		if p.has_momentum():
			machine.transition_to(&"Skid", {"turn": false})
		else:
			machine.transition_to(&"Idle")
		return
	if p.input.move != p.facing:
		if p.has_momentum():
			machine.transition_to(&"Skid", {"turn": true})
		else:
			machine.transition_to(&"Turn")
		return
	if not p.input.run:
		machine.transition_to(&"Walk")
		return
	p.move_on_ground(p.facing * p.config.run_speed, delta)
