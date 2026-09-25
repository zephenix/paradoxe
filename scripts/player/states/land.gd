extends PlayerState
## Réception au sol : légère (brève) ou lourde (genoux fléchis, plus longue). Engagée.

var _duration: float = 0.1


func enter(_previous: StringName, data: Dictionary) -> void:
	var heavy: bool = data.get("heavy", false)
	_duration = player.config.heavy_land_recovery if heavy else player.config.land_recovery
	player.visual.play(&"land_heavy" if heavy else &"land", _duration)
	player.anim_event.emit(&"land_heavy" if heavy else &"land")


func is_committed() -> bool:
	return true


func physics_update(delta: float) -> void:
	player.move_on_ground(0.0, delta)
	if time_in_state >= _duration:
		machine.transition_to(&"Idle")
