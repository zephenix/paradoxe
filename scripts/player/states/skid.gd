extends PlayerState
## Dérapage en fin de course : arrêt, ou demi-tour si data["turn"]. Engagé.

var _turn: bool = false


func enter(_previous: StringName, data: Dictionary) -> void:
	_turn = data.get("turn", false)
	player.visual.play(&"skid", player.config.skid_duration)


func is_committed() -> bool:
	return true


func physics_update(delta: float) -> void:
	var p: Player = player
	var rate: float = absf(p.velocity.x) / maxf(p.config.skid_duration - time_in_state, 0.02)
	p.velocity.x = move_toward(p.velocity.x, 0.0, rate * delta)
	p.move_in_air(delta)
	if not p.is_on_floor() and p.time_since_grounded > 0.05:
		machine.transition_to(&"Fall")
		return
	if time_in_state >= p.config.skid_duration:
		if _turn:
			p.facing = -p.facing
			machine.transition_to(&"Run" if p.input.run and p.input.move == p.facing else &"Idle")
		else:
			machine.transition_to(&"Idle")
