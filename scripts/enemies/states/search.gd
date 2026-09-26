extends SentinelState
## Recherche : elle marche jusqu'à l'endroit de l'indice (bruit, dernier endroit
## où elle a vu Élias), puis regarde autour d'elle en se retournant. Au bout de
## search_duration secondes sans rien trouver, elle reprend sa patrouille.
## Elle voit Élias -> Combat. Un nouveau bruit relance la recherche.

var _clue: Vector2 = Vector2.ZERO
var _arrived: bool = false
var _look_timer: float = 0.0


func enter(_previous: StringName, data: Dictionary) -> void:
	var s: Sentinel = sentinel
	_clue = data.get("clue", s.global_position)
	_arrived = false
	_look_timer = s.config.search_look_interval
	if not data.get("resumed", false):
		s.say(&"search")


func snapshot() -> Dictionary:
	return {"clue": _clue}


func physics_update(delta: float) -> void:
	var s: Sentinel = sentinel
	if check_sight():
		return
	if time_in_state >= s.config.search_duration:
		s.say(&"calm")  # rien trouvé : intonation descendante, retour au calme
		s.suspicion = 0.0
		machine.transition_to(&"Patrol")
		return
	if not _arrived:
		s.face_toward(_clue)
		if absf(_clue.x - s.global_position.x) < 12.0 or not s.can_walk_toward(s.facing):
			_arrived = true
			s.visual.play(&"idle")
		else:
			s.play_move_animation(false)
			s.move_at(s.facing * s.config.walk_speed, delta)
			return
	s.move_at(0.0, delta)
	_look_timer -= delta
	if _look_timer <= 0.0:
		s.facing = -s.facing  # regarde de l'autre côté
		_look_timer = s.config.search_look_interval


func on_noise(at: Vector2) -> void:
	_clue = at
	_arrived = false
	time_in_state = 0.0
