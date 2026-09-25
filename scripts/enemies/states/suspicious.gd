extends SentinelState
## Alerte : un indice l'a intriguée (bruit, silhouette entrevue). Elle
## s'arrête, se tourne vers lui et « grogne » (intonation montante), pendant
## suspicious_duration secondes. Ensuite :
##   - sa suspicion a atteint search_threshold -> elle va voir (Search) ;
##   - sinon, ce n'était rien : retour à la patrouille (intonation descendante).
## Si elle voit nettement Élias entre-temps : Combat. Si elle l'entrevoit
## encore, elle garde les yeux sur lui (sa suspicion continue de monter).
## Un nouveau bruit la fait se retourner et relance l'attente.

var _clue: Vector2 = Vector2.ZERO


func enter(_previous: StringName, data: Dictionary) -> void:
	var s: Sentinel = sentinel
	_clue = data.get("clue", s.global_position)
	s.face_toward(_clue)
	if not data.get("resumed", false):  # pas de nouveau cri en reprenant après un rembobinage
		s.say(&"curious")
	s.visual.play(&"idle")


func snapshot() -> Dictionary:
	return {"clue": _clue}


func physics_update(delta: float) -> void:
	var s: Sentinel = sentinel
	s.move_at(0.0, delta)
	if check_sight():
		return
	if s.sees_target:
		_clue = s.last_clue
		s.face_toward(_clue)
	if time_in_state >= s.config.suspicious_duration:
		if s.suspicion >= s.config.search_threshold:
			machine.transition_to(&"Search", {"clue": _clue})
		else:
			# Ce n'était rien : elle se rassure (sa jauge redescend sous le seuil
			# d'alerte, sinon elle s'alerterait de nouveau aussitôt).
			s.say(&"calm")
			s.suspicion = minf(s.suspicion, s.config.suspicious_threshold * 0.5)
			machine.transition_to(&"Patrol")


func on_noise(at: Vector2) -> void:
	_clue = at
	sentinel.face_toward(at)
	time_in_state = 0.0
