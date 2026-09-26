@tool
class_name Ruin
extends Node2D
## Façade en ruine (J8, décor des écrans 2, 3, 6, 8) : un immeuble effondré,
## sommet déchiqueté, fenêtres vides, mousse luminescente dans les fissures.
## Pur décor (aucune collision) : les sols et murs praticables sont des SolidBlock.
## L'origine est au sol, au bord gauche de la façade.

@export var width: float = 300.0:
	set(value):
		width = value
		queue_redraw()
@export var height: float = 420.0:
	set(value):
		height = value
		queue_redraw()
@export var seed_value: int = 1:
	set(value):
		seed_value = value
		queue_redraw()
@export var color: Color = Color("1b2129"):
	set(value):
		color = value
		queue_redraw()

const GLOW := Color(0.43, 1.0, 0.69)


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	# Silhouette : bas droit, sommet brisé en dents irrégulières.
	var outline := PackedVector2Array([Vector2(0, 0)])
	var steps: int = maxi(3, int(width / 40.0))
	for i in steps + 1:
		var x: float = width * i / steps
		outline.append(Vector2(x, -height * rng.randf_range(0.7, 1.0)))
	outline.append(Vector2(width, 0))
	draw_colored_polygon(outline, color)
	# Fenêtres : une grille, certaines vides (noires), d'autres éboulées.
	var cols: int = maxi(1, int(width / 60.0))
	var rows: int = maxi(1, int(height * 0.7 / 70.0))
	for r in rows:
		for c in cols:
			if rng.randf() < 0.2:
				continue
			var p := Vector2(18.0 + c * (width - 20.0) / cols, -40.0 - (r + 1) * 70.0)
			if -p.y > height * 0.68:
				continue
			draw_rect(Rect2(p, Vector2(26.0, 36.0)), color.darkened(0.55))
	# Fissures et mousse qui brille.
	for k in int(width / 70.0):
		var x: float = rng.randf_range(10.0, width - 10.0)
		var y0: float = -rng.randf_range(20.0, height * 0.6)
		var crack := PackedVector2Array([Vector2(x, y0), Vector2(x + rng.randf_range(-15, 15), y0 + 30), Vector2(x + rng.randf_range(-20, 20), y0 + 60)])
		draw_polyline(crack, color.darkened(0.4), 2.0)
		draw_circle(crack[2], 3.0, Color(GLOW, 0.6))
