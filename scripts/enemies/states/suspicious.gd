extends SentinelState
## Alerte : un bruit l'a intriguée. Elle s'arrête, se tourne vers lui et
## « grogne » (intonation montante), pendant suspicious_duration secondes.
## Puis elle va voir (Search). Si elle voit Élias entre-temps : Combat.
## Un nouveau bruit la fait se retourner et relance l'attente.

var _clue: Vector2 = Vector2.ZERO


func enter(_previous: StringName, data: Dictionary) -> void:
	var s: Sentinel = sentinel
	_clue = data.get("clue", s.global_position)
	s.face_toward(_clue)
	s.say(&"curious")
	s.visual.play(&"idle")


func physics_update(delta: float) -> void:
	var s: Sentinel = sentinel
	s.move_at(0.0, delta)
	if check_sight():
		return
	if time_in_state >= s.config.suspicious_duration:
		machine.transition_to(&"Search", {"clue": _clue})


func on_noise(at: Vector2) -> void:
	_clue = at
	sentinel.face_toward(at)
	time_in_state = 0.0
