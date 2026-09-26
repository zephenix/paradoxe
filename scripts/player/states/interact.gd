extends PlayerState
## Interagir (J7) : Élias tend la main vers l'objet (levier, terminal, casier…).
## Geste engagé de interact_duration secondes ; l'objet réagit quand la main le
## touche (interact_time). data["target"] : l'objet visé (Interactable).

var _target: Interactable
var _done: bool = false


func enter(_previous: StringName, data: Dictionary) -> void:
	var p: Player = player
	p.set_crouched(false)
	_target = data.get("target") as Interactable
	_done = false
	p.visual.play(&"interact", p.config.interact_duration)


func is_committed() -> bool:
	return true


func physics_update(delta: float) -> void:
	var p: Player = player
	p.move_on_ground(0.0, delta)
	if p.lost_ground():
		machine.transition_to(&"Fall")
		return
	if not _done and time_in_state >= p.config.interact_time:
		_done = true
		if is_instance_valid(_target):
			_target.interact(p)
	if time_in_state >= p.config.interact_duration:
		machine.transition_to(&"Idle")
