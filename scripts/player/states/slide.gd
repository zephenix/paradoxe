extends PlayerState
## Glissade (course + bas) : passe sous les obstacles bas. Engagée au début.
## N'existe pas en mode classique.


func enter(_previous: StringName, _data: Dictionary) -> void:
	player.set_crouched(true)
	player.velocity.x = player.facing * player.config.run_speed * player.config.slide_speed_factor
	player.visual.play(&"slide")
	player.anim_event.emit(&"slide")


func is_committed() -> bool:
	return time_in_state < player.config.slide_min_duration


func physics_update(delta: float) -> void:
	var p: Player = player
	p.velocity.x = move_toward(p.velocity.x, 0.0, p.config.slide_friction * delta)
	p.move_in_air(delta)
	if not p.is_on_floor() and p.time_since_grounded > 0.08:
		machine.transition_to(&"Fall")
		return
	if time_in_state < p.config.slide_min_duration:
		return
	var slow: bool = absf(p.velocity.x) < p.config.crouch_walk_speed
	if slow or not p.input.down:
		if p.can_stand():
			machine.transition_to(&"Run" if p.input.run and p.input.move == p.facing else &"Idle")
		elif slow:
			machine.transition_to(&"Crouch")
