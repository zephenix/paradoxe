extends PlayerState
## Descendre d'un rebord : Élias s'avance au bord, s'y assoit, se retourne et se
## laisse glisser jusqu'à la suspension. Engagé. On n'entre ici que s'il y a la
## place dessous (vérifié avant, voir Player.can_descend).

var _start: Vector2
var _edge: Vector2
var _hang: Vector2
var _duration: float = 0.5


func enter(_previous: StringName, data: Dictionary) -> void:
	var p: Player = player
	var edge_x: float = data["edge_x"]
	_start = p.global_position
	_hang = p.descend_hang_position(edge_x)
	_edge = Vector2(_hang.x, _start.y)
	if not p.is_space_free(_hang, p.config.stand_height):  # sécurité (normalement vérifié avant)
		machine.transition_to(&"Crouch")
		return
	_duration = p.config.descend_duration
	p.facing = -p.facing  # face au mur pour s'y suspendre
	p.velocity = Vector2.ZERO
	p.visual.play(&"descend", _duration)


func is_committed() -> bool:
	return true


func physics_update(_delta: float) -> void:
	var p: Player = player
	var k: float = clampf(time_in_state / _duration, 0.0, 1.0)
	# ease(t, courbe) : < 1 démarre vite puis ralentit, > 1 démarre lentement
	# (Élias se laisse d'abord glisser doucement, puis descend plus franchement).
	if k < 0.35:
		p.global_position = _start.lerp(_edge, ease(k / 0.35, 0.8))
	else:
		p.global_position = _edge.lerp(_hang, ease((k - 0.35) / 0.65, 1.4))
	if k >= 1.0:
		p.global_position = _hang
		var point := Vector2(_hang.x + p.facing * (p.config.body_width * 0.5 + 1.0), _start.y)
		var ledge := {"point": point, "can_stand": true, "can_climb": true}
		machine.transition_to(&"LedgeHang", {"ledge": ledge})
