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
## Version détaillée (essai graphique) : arête éclairée par la lune, rangées de
## fenêtres, toits encombrés (antennes, réservoirs), sommets effondrés, brume
## au pied des immeubles.
@export var detailed: bool = false:
	set(value):
		detailed = value
		queue_redraw()
## Version détaillée : les immeubles descendent sous base_y de cette hauteur.
const DEPTH: float = 1400.0
## Couleur de la brume qui noie le pied des immeubles (version détaillée).
@export var haze_color: Color = Color(0.12, 0.2, 0.2, 0.9)


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
		if detailed:
			points[0].y = base_y + DEPTH
			points[points.size() - 1].y = base_y + DEPTH
			_draw_building(points, x, w, top, rng)
		else:
			draw_colored_polygon(points, color)
			for i in rng.randi_range(0, 5):
				var wx: float = x + rng.randf_range(8.0, w - 16.0)
				var wy: float = top + rng.randf_range(20.0, h - 20.0)
				draw_rect(Rect2(wx, wy, 6, 9), window_color)
		x += w + rng.randf_range(4.0, 30.0)
	if detailed:
		# Brume au pied de la ville : un dégradé sur toute la largeur.
		# Elle s'efface aussi vers le bas : les immeubles continuent dessous (on
		# ne voit jamais de bord net quand la caméra descend).
		var clear := Color(haze_color, 0.0)
		draw_polygon(PackedVector2Array([Vector2(-200, base_y - 220), Vector2(width, base_y - 220), Vector2(width, base_y), Vector2(-200, base_y)]),
				PackedColorArray([clear, clear, haze_color, haze_color]))
		draw_polygon(PackedVector2Array([Vector2(-200, base_y), Vector2(width, base_y), Vector2(width, base_y + 260), Vector2(-200, base_y + 260)]),
				PackedColorArray([haze_color, haze_color, clear, clear]))


## Un immeuble détaillé : sommet parfois effondré, arête gauche éclairée par la
## lune, fenêtres en rangées (presque toutes éteintes), objets sur le toit.
func _draw_building(points: PackedVector2Array, x: float, w: float, top: float, rng: RandomNumberGenerator) -> void:
	if points.size() == 4 and rng.randf() < 0.35:  # sommet effondré, en dents de scie
		points = PackedVector2Array([Vector2(x, base_y + DEPTH), Vector2(x, top)])
		var teeth: int = rng.randi_range(3, 6)
		for i in range(1, teeth):
			points.append(Vector2(x + w * i / teeth, top + rng.randf_range(0.0, 45.0)))
		points.append(Vector2(x + w, top + rng.randf_range(10.0, 50.0)))
		points.append(Vector2(x + w, base_y + DEPTH))
	var shade: Color = color.darkened(rng.randf_range(0.0, 0.25))
	draw_colored_polygon(points, shade)
	draw_line(Vector2(x + 1.0, top + 4.0), Vector2(x + 1.0, base_y + DEPTH), shade.lightened(0.1), 2.0)  # arête éclairée
	# Fenêtres : une grille régulière, quelques-unes allumées.
	var columns: int = maxi(2, int(w / 14.0))
	var gap: float = w / columns
	var y: float = top + 14.0
	while y < base_y + DEPTH - 30.0:
		for c in columns:
			var wx: float = x + gap * c + gap * 0.3
			if rng.randf() < 0.04:
				draw_rect(Rect2(wx, y, 4.0, 6.0), window_color)
			elif rng.randf() < 0.35:
				draw_rect(Rect2(wx, y, 4.0, 6.0), shade.darkened(0.25))
		y += 16.0
	# Sur le toit : antenne, réservoir sur pieds, ou rien.
	var roll: float = rng.randf()
	var roof_x: float = x + rng.randf_range(10.0, w - 20.0)
	var roof_y: float = top
	for i in range(1, points.size() - 1):
		if points[i].x <= roof_x and points[i + 1].x >= roof_x:
			roof_y = lerpf(points[i].y, points[i + 1].y, (roof_x - points[i].x) / maxf(points[i + 1].x - points[i].x, 1.0))
	if roll < 0.3:
		draw_line(Vector2(roof_x, roof_y), Vector2(roof_x, roof_y - rng.randf_range(20.0, 50.0)), shade, 1.5)
		draw_line(Vector2(roof_x - 6.0, roof_y - 18.0), Vector2(roof_x + 6.0, roof_y - 18.0), shade, 1.0)
	elif roll < 0.5:
		draw_rect(Rect2(roof_x - 8.0, roof_y - 22.0, 16.0, 12.0), shade)
		draw_line(Vector2(roof_x - 6.0, roof_y - 10.0), Vector2(roof_x - 6.0, roof_y), shade, 1.5)
		draw_line(Vector2(roof_x + 6.0, roof_y - 10.0), Vector2(roof_x + 6.0, roof_y), shade, 1.5)
