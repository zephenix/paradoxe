extends SentinelState
## Patrouille : elle marche d'un bout à l'autre de son trajet (réglé dans la
## scène : patrol_left_blocks, patrol_right_blocks autour de son point de
## départ), marque une pause à chaque bout, puis repart dans l'autre sens.
## Trajet nul : elle monte la garde sur place, dans son sens de départ.
## Elle s'arrête aussi devant un mur ou un vide.
## Elle voit Élias -> Combat ; elle entend un bruit -> Suspicious.

var _pause: float = 0.0


func enter(_previous: StringName, data: Dictionary) -> void:
	var s: Sentinel = sentinel
	_pause = data.get("pause", 0.0)
	# Hors de son trajet (après une recherche) : elle se tourne vers son poste.
	if s.global_position.x < _left() - 4.0:
		s.facing = 1
	elif s.global_position.x > _right() + 4.0:
		s.facing = -1
	s.visual.play(&"idle")


func snapshot() -> Dictionary:
	return {"pause": _pause}


func physics_update(delta: float) -> void:
	var s: Sentinel = sentinel
	if check_sight():
		return
	if is_equal_approx(_left(), _right()) and absf(s.global_position.x - s.home.x) < 4.0:
		_stand(delta)  # poste de garde fixe
		return
	if _pause > 0.0:
		_pause -= delta
		_stand(delta)
		if _pause <= 0.0:
			s.facing = -s.facing
		return
	var goal: float = _right() if s.facing > 0 else _left()
	var reached: bool = (goal - s.global_position.x) * s.facing <= 2.0
	if reached or not s.can_walk_toward(s.facing):
		_pause = s.config.patrol_pause
		_stand(delta)
		return
	s.play_move_animation(false)
	s.move_at(s.facing * s.config.walk_speed, delta)


func _stand(delta: float) -> void:
	var s: Sentinel = sentinel
	if s.visual.current != &"idle":
		s.visual.play(&"idle")
	s.move_at(0.0, delta)


func _left() -> float:
	return sentinel.home.x - sentinel.patrol_left_blocks * GameUnits.BLOCK


func _right() -> float:
	return sentinel.home.x + sentinel.patrol_right_blocks * GameUnits.BLOCK
