extends PlayerState
## Descendre d'un rebord : Élias se retourne, s'assoit sur le bord et se
## laisse glisser jusqu'à la suspension. Engagé.

var _start: Vector2
var _edge: Vector2
var _hang: Vector2
var _duration: float = 0.5


func enter(_previous: StringName, data: Dictionary) -> void:
	var p: Player = player
	var edge_x: float = data["edge_x"]
	var outward: int = p.facing
	_start = p.global_position
	_edge = Vector2(edge_x + outward * (p.config.body_width * 0.5 + 1.0), _start.y)
	_hang = Vector2(_edge.x, _start.y + p.config.hang_hand_height)
	if not p.is_space_free(_hang, p.config.stand_height):
		machine.transition_to(&"Crouch")
		return
	_duration = p.config.descend_duration
	p.facing = -outward  # face au mur pour s'y suspendre
	p.velocity = Vector2.ZERO
	p.visual.play(&"descend", _duration)


func is_committed() -> bool:
	return true


func physics_update(_delta: float) -> void:
	var p: Player = player
	var k: float = clampf(time_in_state / _duration, 0.0, 1.0)
	if k < 0.35:
		p.global_position = _start.lerp(_edge, ease(k / 0.35, 0.8))
	else:
		p.global_position = _edge.lerp(_hang, ease((k - 0.35) / 0.65, 1.4))
	if k >= 1.0:
		p.global_position = _hang
		var ledge := {"point": Vector2(_edge.x + p.facing * p.config.body_width * 0.5, _start.y), "can_stand": true}
		machine.transition_to(&"LedgeHang", {"ledge": ledge})
