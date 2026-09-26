extends CompanionState
## Activer (« Active ça ») : il marche jusqu'au mécanisme désigné, l'actionne,
## puis attend sur place (état Wait). S'il ne peut pas l'atteindre (mur, vide,
## autre étage), il renonce : « rien à faire ici ».
## data["target"] : le mécanisme (Interactable).

var _target: Interactable
var _acting: bool = false
var _act_time: float = 0.0
var _done: bool = false


func enter(_previous: StringName, data: Dictionary) -> void:
	_target = data.get("target") as Interactable
	_acting = false
	_done = false
	_act_time = 0.0


func physics_update(delta: float) -> void:
	var c: Companion = companion
	if not is_instance_valid(_target):
		machine.transition_to(&"Wait")
		return
	if _acting:
		_act_time += delta
		c.move_at(0.0, delta)
		if not _done and _act_time >= c.config.activate_time:
			_done = true
			_target.interact(c)
		if _act_time >= c.config.activate_duration:
			machine.transition_to(&"Wait")
		return
	var offset: float = _target.global_position.x - c.global_position.x
	if absf(_target.global_position.y - c.global_position.y) > 48.0:
		c.refuse()
		machine.transition_to(&"Wait")
		return
	if absf(offset) <= c.config.activate_reach:
		_acting = true
		c.visual.play(&"interact", c.config.activate_duration)
		c.move_at(0.0, delta)
		return
	c.facing = int(signf(offset))
	if not c.can_walk_toward(c.facing):
		c.refuse()
		machine.transition_to(&"Wait")
		return
	c.move_at(c.facing * c.config.walk_speed, delta)
	c.play_locomotion(c.velocity.x)
