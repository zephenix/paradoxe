extends SentinelState
## Poursuite : elle a perdu Élias de vue en plein combat. Elle court vers le
## dernier endroit où elle l'a vu (sans sauter des plates-formes). Elle le
## revoit -> Combat ; elle arrive (ou bute sur un obstacle) ou le temps passe
## -> Search autour de ce dernier endroit.


func enter(_previous: StringName, _data: Dictionary) -> void:
	sentinel.play_move_animation(true)


func physics_update(delta: float) -> void:
	var s: Sentinel = sentinel
	if check_sight():
		return
	var goal: Vector2 = s.last_seen_position
	s.face_toward(goal)
	var arrived: bool = absf(goal.x - s.global_position.x) < 12.0
	if arrived or time_in_state >= s.config.chase_duration or not s.can_walk_toward(s.facing):
		machine.transition_to(&"Search", {"clue": goal})
		return
	s.play_move_animation(true)
	s.move_at(s.facing * s.config.run_speed, delta)


## Un bruit pendant la poursuite : elle court vers lui.
func on_noise(at: Vector2) -> void:
	sentinel.last_seen_position = at
