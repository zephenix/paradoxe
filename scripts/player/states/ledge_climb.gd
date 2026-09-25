extends PlayerState
## Se hisser sur un rebord (depuis la suspension ou depuis le sol si le
## rebord est à portée de main). Engagé. Le corps suit un chemin en deux
## temps : monter à la verticale, puis avancer sur le rebord. Les collisions
## sont ignorées pendant le mouvement : c'est pourquoi on n'entre ici que si le
## trajet et l'arrivée sont libres (voir Player.find_ledge, « can_climb »).

var _start: Vector2
var _top: Vector2
var _end: Vector2
var _duration: float = 0.6


func enter(_previous: StringName, data: Dictionary) -> void:
	var p: Player = player
	var ledge: Dictionary = data["ledge"]
	var point: Vector2 = ledge["point"]
	_start = p.global_position
	_top = Vector2(_start.x, point.y)
	_end = p.climb_end_for(point)
	var height: float = _start.y - point.y
	# Une marche basse se franchit plus vite qu'un mur à hauteur de mains.
	_duration = p.config.climb_duration * clampf(height / p.config.hang_hand_height, p.config.climb_min_duration_factor, 1.0)
	p.velocity = Vector2.ZERO
	p.set_crouched(false)
	p.visual.play(&"climb", _duration)
	p.anim_event.emit(&"climb")


func is_committed() -> bool:
	return true


func physics_update(_delta: float) -> void:
	var p: Player = player
	var k: float = clampf(time_in_state / _duration, 0.0, 1.0)
	# ease(t, courbe) déforme une progression t de 0 à 1 : une courbe < 1 démarre
	# vite puis ralentit (effort qui s'essouffle), > 1 démarre lentement.
	if k < 0.6:
		p.global_position = _start.lerp(_top, ease(k / 0.6, 0.6))
	else:
		p.global_position = _top.lerp(_end, ease((k - 0.6) / 0.4, 0.8))
	if k >= 1.0:
		p.global_position = _end
		p.air_top_y = _end.y
		machine.transition_to(&"Idle")
