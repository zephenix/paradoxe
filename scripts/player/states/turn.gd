extends PlayerState
## Demi-tour à l'arrêt ou en marchant. Le sens change à mi-animation. Engagé.

var _flipped: bool = false


func enter(_previous: StringName, _data: Dictionary) -> void:
	_flipped = false
	player.visual.play(&"turn", player.config.turn_duration)


func is_committed() -> bool:
	return true


func physics_update(delta: float) -> void:
	var p: Player = player
	p.move_on_ground(0.0, delta)
	if not _flipped and time_in_state >= p.config.turn_duration * 0.5:
		_flipped = true
		p.facing = -p.facing
	if time_in_state >= p.config.turn_duration:
		machine.transition_to(&"Idle")
