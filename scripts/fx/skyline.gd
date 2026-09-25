@tool
class_name Skyline
extends Node2D
## Silhouette de ville dessinée par code (fond en parallaxe).
## Des immeubles de hauteurs aléatoires (graine fixe : même dessin à chaque
## lancement), quelques fenêtres allumées. À placer dans un Parallax2D.

@export var width: float = 8000.0:
	set(value):
		width = value
		queue_redraw()
@export var base_y: float = 720.0
@export var min_height: float = 120.0
@export var max_height: float = 420.0
@export var color: Color = Color("141b26"):
	set(value):
		color = value
		queue_redraw()
@export var window_color: Color = Color(0.55, 0.85, 0.75, 0.35)
@export var seed_value: int = 7:
	set(value):
		seed_value = value
		queue_redraw()


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var x: float = -200.0
	while x < width:
		var w: float = rng.randf_range(60.0, 170.0)
		var h: float = rng.randf_range(min_height, max_height)
		var top: float = base_y - h
		var points := PackedVector2Array([Vector2(x, base_y), Vector2(x, top), Vector2(x + w, top), Vector2(x + w, base_y)])
		if rng.randf() < 0.3:  # toit en pente
			points = PackedVector2Array([Vector2(x, base_y), Vector2(x, top + 20), Vector2(x + w * 0.5, top - 10), Vector2(x + w, top + 20), Vector2(x + w, base_y)])
		draw_colored_polygon(points, color)
		for i in rng.randi_range(0, 5):
			var wx: float = x + rng.randf_range(8.0, w - 16.0)
			var wy: float = top + rng.randf_range(20.0, h - 20.0)
			draw_rect(Rect2(wx, wy, 6, 9), window_color)
		x += w + rng.randf_range(4.0, 30.0)
