@tool
class_name Vegetation
extends Node2D
## Jungle luminescente (J7, décor) : des tiges, des feuilles et des pointes qui
## brillent du même vert que le portail de l'intro (indice du twist, PLAN §4.3).
## Tout est dessiné par le code : changer « seed_value » donne une autre touffe.
## L'origine du nœud est au sol, au bord gauche de la bande de végétation.

@export var width: float = 400.0:
	set(value):
		width = value
		queue_redraw()
@export var max_height: float = 180.0:
	set(value):
		max_height = value
		queue_redraw()
@export var seed_value: int = 1:
	set(value):
		seed_value = value
		queue_redraw()
@export var color: Color = Color(0.1, 0.22, 0.2)

const GLOW := Color(0.43, 1.0, 0.69)


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var count: int = int(width / 22.0)
	for i in count:
		var x: float = rng.randf_range(0.0, width)
		var height: float = rng.randf_range(max_height * 0.3, max_height)
		var lean: float = rng.randf_range(-30.0, 30.0)
		var tip := Vector2(x + lean, -height)
		draw_line(Vector2(x, 0), tip, color, rng.randf_range(2.0, 4.0))
		# Feuilles le long de la tige.
		for k in 3:
			var t: float = rng.randf_range(0.3, 0.9)
			var base: Vector2 = Vector2(x, 0).lerp(tip, t)
			var side: float = -1.0 if k % 2 == 0 else 1.0
			draw_colored_polygon(PackedVector2Array([base, base + Vector2(side * 22.0, -8.0),
					base + Vector2(side * 30.0, 4.0)]), color.lightened(0.08 * k))
		# Pointe lumineuse.
		draw_circle(tip, rng.randf_range(2.0, 3.5), GLOW)
		draw_circle(tip, 8.0, Color(GLOW, 0.12))
