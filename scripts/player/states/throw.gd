extends PlayerState
## Lancer une pierre (J6) : geste engagé de throw_config.duration secondes. La
## pierre part à release_time, dans le sens du regard, en cloche. Debout ou
## accroupi (Élias reste alors accroupi : utile derrière un couvert).
## data["crouched"] : lancer accroupi.

var _crouched: bool = false
var _released: bool = false


func enter(_previous: StringName, data: Dictionary) -> void:
	var p: Player = player
	_crouched = data.get("crouched", false)
	_released = false
	p.set_crouched(_crouched)
	p.visual.play(&"crouch_throw" if _crouched else &"throw", p.throw_config.duration)


func is_committed() -> bool:
	return true


func physics_update(delta: float) -> void:
	var p: Player = player
	p.move_on_ground(0.0, delta)
	if p.lost_ground():
		machine.transition_to(&"Fall")
		return
	if not _released and time_in_state >= p.throw_config.release_time:
		_released = true
		p.throw_stone(_crouched)
	if time_in_state >= p.throw_config.duration:
		machine.transition_to(&"Crouch" if _crouched else &"Idle")
