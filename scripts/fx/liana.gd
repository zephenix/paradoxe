@tool
class_name Liana
extends Node2D
## Lianes (J8, décor de la canopée) : des tiges qui pendent et se balancent
## doucement, avec des feuilles et des points lumineux. Pur décor.
## L'origine est le point d'accroche (en haut).

@export var count: int = 5:
	set(value):
		count = value
		queue_redraw()
@export var length: float = 220.0:
	set(value):
		length = value
		queue_redraw()
@export var spread: float = 160.0:
	set(value):
		spread = value
		queue_redraw()
@export var seed_value: int = 1

const STEM := Color(0.1, 0.22, 0.2)
const GLOW := Color(0.43, 1.0, 0.69)

var _time: float = 0.0


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	queue_redraw()


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in count:
		var x: float = rng.randf_range(0.0, spread)
		var l: float = length * rng.randf_range(0.5, 1.0)
		var phase: float = rng.randf_range(0.0, TAU)
		var points := PackedVector2Array()
		for k in 9:
			var u: float = k / 8.0
			points.append(Vector2(x + sin(_time * 0.8 + phase + u * 2.0) * 10.0 * u, u * l))
		draw_polyline(points, STEM, 3.0)
		for k in range(2, 9, 2):
			draw_circle(points[k] + Vector2(5, 0), 4.0, STEM.lightened(0.15))
		draw_circle(points[8], 3.0, Color(GLOW, 0.7))
