extends PlayerState
## Saut : vertical, sans élan (en marchant) ou avec élan (en courant).
## Engagé : une fois lancé, la trajectoire ne se corrige pas en l'air.
## Les sauts sur place et sans élan commencent par une courte impulsion
## (genoux pliés) ; le saut avec élan part immédiatement.

var _kind: StringName = &"vertical"
var _airborne: bool = false


func enter(_previous: StringName, data: Dictionary) -> void:
	_kind = data.get("kind", &"vertical")
	_airborne = false
	player.set_crouched(false)
	if _kind == &"running":
		_take_off()
	else:
		player.visual.play(&"jump_windup", player.config.jump_windup)


func is_committed() -> bool:
	return true


func physics_update(delta: float) -> void:
	var p: Player = player
	if not _airborne:
		p.move_on_ground(0.0, delta)
		if time_in_state >= p.config.jump_windup:
			_take_off()
		return
	p.move_in_air(delta)
	if p.velocity.y > 0.0 and p.visual.current != &"fall":
		p.visual.play(&"fall")
	if p.try_grab():
		return
	if p.is_on_floor() and time_in_state > 0.05:
		p.land()


func _take_off() -> void:
	var p: Player = player
	var v: Vector2
	match _kind:
		&"running":
			v = p.config.running_jump_velocity()
		&"standing":
			v = p.config.standing_jump_velocity()
		_:
			v = p.config.vertical_jump_velocity()
	p.velocity = Vector2(v.x * p.facing, v.y)
	p.air_top_y = p.global_position.y
	_airborne = true
	time_in_state = 0.0
	p.visual.play(&"leap" if _kind == &"running" else &"jump")
	p.anim_event.emit(&"jump")
