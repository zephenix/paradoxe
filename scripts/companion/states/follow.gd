extends CompanionState
## Suivre : il se tient à follow_distance d'Élias, marche ou court pour le
## rattraper, et s'arrête au bord d'un vide ou devant un mur.
## Si Élias est à un autre étage, il monte sur l'ascenseur à son niveau, s'il y
## en a un, et attend que quelqu'un le fasse partir.


func enter(_previous: StringName, _data: Dictionary) -> void:
	companion.mode = &"Follow"


func physics_update(delta: float) -> void:
	var c: Companion = companion
	var p: Player = c.target
	if p == null:
		c.move_at(0.0, delta)
		return
	var goal_x: float = c.global_position.x
	if absf(p.global_position.y - c.global_position.y) > c.config.other_floor_height:
		var elevator: Elevator = c.elevator_at_my_level()
		if elevator:
			goal_x = elevator.center_x()
	else:
		var dx: float = p.global_position.x - c.global_position.x
		if absf(dx) > c.config.follow_distance:
			goal_x = p.global_position.x - signf(dx) * c.config.follow_distance
	var offset: float = goal_x - c.global_position.x
	var speed: float = 0.0
	if absf(offset) > 6.0:
		var far: bool = absf(p.global_position.x - c.global_position.x) > c.config.run_distance
		speed = signf(offset) * (c.config.run_speed if far else c.config.walk_speed)
		c.facing = int(signf(offset))
	else:
		c.face_toward(p.global_position)
	c.move_at(speed, delta)
	c.play_locomotion(c.velocity.x)
