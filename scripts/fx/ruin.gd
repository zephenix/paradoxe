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
## Matière du mur (essai graphique) : vide = aplat, comme avant.
@export var style: SurfaceStyle:
	set(value):
		style = value
		queue_redraw()

const GLOW := Color(0.43, 1.0, 0.69)
const MOSS := Color(0.2, 0.34, 0.22)


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
	if style:
		_draw_textured(outline, rng)
		return
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


## Version texturée (essai graphique) : mur en matière, ombre en bas, fenêtres
## creusées (linteau dans l'ombre, appui éclairé), fers à béton qui dépassent du
## sommet brisé, mousse qui pend des bords, fissures.
func _draw_textured(outline: PackedVector2Array, rng: RandomNumberGenerator) -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var world := PackedVector2Array()
	for point in outline:
		world.append(point + position)
	draw_colored_polygon(outline, color.lightened(style.lighten), style.draw_uvs_for(world), style.canvas_texture())
	# Le bas du mur, plus sombre (humidité, ombre du sol).
	draw_polygon(PackedVector2Array([Vector2(0, -90), Vector2(width, -90), Vector2(width, 0), Vector2(0, 0)]),
			PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.5), Color(0, 0, 0, 0.5)]))
	# Fenêtres.
	var cols: int = maxi(1, int(width / 60.0))
	var rows: int = maxi(1, int(height * 0.7 / 70.0))
	for r in rows:
		for c in cols:
			if rng.randf() < 0.2:
				continue
			var p := Vector2(18.0 + c * (width - 20.0) / cols, -40.0 - (r + 1) * 70.0)
			if -p.y > height * 0.68:
				continue
			var hole := Rect2(p, Vector2(26.0, 36.0))
			draw_rect(hole.grow(3.0), color.darkened(0.25))  # encadrement
			draw_rect(hole, Color(0.01, 0.015, 0.02))
			draw_rect(Rect2(hole.position, Vector2(hole.size.x, 7.0)), Color(0, 0, 0, 0.6))  # linteau : ombre
			draw_rect(Rect2(hole.position + Vector2(-4.0, hole.size.y), Vector2(hole.size.x + 8.0, 4.0)), color.lightened(0.3))  # appui
	# Fissures (sombres, avec un liseré clair d'un côté : elles sont creuses).
	for k in int(width / 60.0):
		var x: float = rng.randf_range(10.0, width - 10.0)
		var y0: float = -rng.randf_range(20.0, height * 0.6)
		var crack := PackedVector2Array([Vector2(x, y0)])
		for i in 4:
			crack.append(crack[i] + Vector2(rng.randf_range(-12, 12), rng.randf_range(10, 22)))
		draw_polyline(crack, Color(color.lightened(0.2), 0.35), 1.0)
		draw_set_transform(Vector2(1, 1))
		draw_polyline(crack, Color(0, 0, 0, 0.7), 2.0)
		draw_set_transform(Vector2.ZERO)
		draw_circle(crack[crack.size() - 1], 2.5, Color(GLOW, 0.55))
	# Sommet brisé : fers à béton tordus, touffes de mousse le long de l'arête,
	# et quelques lianes qui pendent.
	for i in range(1, outline.size() - 2):
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[i + 1]
		if rng.randf() < 0.45:
			var bar := PackedVector2Array([a + Vector2(0, 6)])
			for j in 3:
				bar.append(bar[j] + Vector2(rng.randf_range(-6, 6), -rng.randf_range(6, 12)))
			draw_polyline(bar, Color(0.3, 0.21, 0.16), 2.0)
		var tufts: int = int(a.distance_to(b) / 5.0)
		for j in tufts:
			var at: Vector2 = a.lerp(b, (j + rng.randf()) / maxf(tufts, 1.0)) + Vector2(0, rng.randf_range(0.0, 5.0))
			draw_circle(at, rng.randf_range(2.5, 5.0), MOSS.darkened(rng.randf_range(0.0, 0.35)))
		if rng.randf() < 0.6:
			_draw_vine(a.lerp(b, rng.randf()) + Vector2(0, 3), rng.randf_range(25.0, 90.0), rng)


## Liane : un fil qui pend en ondulant, avec de petites feuilles de chaque côté.
func _draw_vine(from: Vector2, length: float, rng: RandomNumberGenerator) -> void:
	var points := PackedVector2Array()
	var phase: float = rng.randf() * TAU
	var steps: int = int(length / 6.0)
	for k in steps + 1:
		var y: float = length * k / steps
		points.append(from + Vector2(sin(phase + y * 0.08) * 3.0, y))
	draw_polyline(points, MOSS.darkened(0.3), 1.5)
	for k in range(1, points.size(), 2):
		var side: float = 1.0 if k % 4 == 1 else -1.0
		var p: Vector2 = points[k]
		draw_colored_polygon(PackedVector2Array([p, p + Vector2(side * 6.0, -2.0), p + Vector2(side * 3.0, 3.0)]),
				MOSS.lightened(rng.randf_range(0.0, 0.2)))
	draw_circle(points[points.size() - 1], 1.5, Color(GLOW, 0.6))
