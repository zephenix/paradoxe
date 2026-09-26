@tool
class_name Duct
extends Node2D
## Bouche de conduit (J8, décor de l'écran 6) : une grille basse dans un mur,
## par laquelle Marek s'en va. Pur décor. L'origine est au sol, au milieu.

@export var size: Vector2 = Vector2(70.0, 46.0):
	set(value):
		size = value
		queue_redraw()


func _draw() -> void:
	var rect := Rect2(-size.x * 0.5, -size.y, size.x, size.y)
	draw_rect(rect.grow(6.0), Color("2a3038"))
	draw_rect(rect, Color("050608"))
	for i in range(1, 6):
		var x: float = rect.position.x + i * size.x / 6.0
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), Color("3a424c"), 2.0)
