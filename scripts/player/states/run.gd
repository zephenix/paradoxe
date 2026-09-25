extends PlayerState
## Course. On ne s'arrête ni ne se retourne d'un coup : on dérape (état Skid).


func enter(_previous: StringName, _data: Dictionary) -> void:
	player.set_crouched(false)
	player.visual.play(&"run")


func physics_update(delta: float) -> void:
	var p: Player = player
	if not p.is_on_floor() and p.time_since_grounded > AIR_TOLERANCE:
		machine.transition_to(&"Fall")
		return
	if p.wants(&"jump"):
		p.start_jump(&"running")
		return
	if p.wants(&"roll"):
		machine.transition_to(&"Roll", {"landing": false})
		return
	if p.input.down and p.modern():
		machine.transition_to(&"Slide")
		return
	if p.input.move == 0:
		machine.transition_to(&"Skid", {"turn": false})
		return
	if p.input.move != p.facing:
		machine.transition_to(&"Skid", {"turn": true})
		return
	if not p.input.run:
		machine.transition_to(&"Walk")
		return
	p.move_on_ground(p.facing * p.config.run_speed, delta)
