class_name IntroShot
extends Node2D
## Un PLAN de la cinématique d'ouverture (J8, PLAN §5.12) : une petite composition
## autonome, comme une case de bande dessinée, entièrement dessinée par code
## (polygones, aucune image). Chaque plan est un script à part : on peut en
## remplacer un sans toucher aux autres.
##
## La table de montage (IntroCutscene) montre un plan, puis fait avancer sa
## propriété « progress » de 0 à 1 pendant sa durée : le plan se dessine en
## fonction de cet avancement (un glisseur qui approche, une main qui se pose…).
## « time » compte les secondes depuis que le plan est visible : pour ce qui
## bouge en continu (pluie, néons qui clignotent).
##
## Le cadre fait 1280 × 720 pixels ; les bandes noires de la cinématique en
## cachent le haut et le bas (voir IntroCutscene.BAR_HEIGHT).

const W: float = 1280.0
const H: float = 720.0
const GLOW: Color = Color("6effbf")  # le vert du portail (fil rouge du twist)
## Matières (les mêmes qu'en jeu) : elles donnent du grain aux surfaces des plans.
const CONCRETE: SurfaceStyle = preload("res://resources/art/surfaces/concrete.tres")
const METAL: SurfaceStyle = preload("res://resources/art/surfaces/metal.tres")
const PLANKS: SurfaceStyle = preload("res://resources/art/surfaces/planks.tres")
const EARTH: SurfaceStyle = preload("res://resources/art/surfaces/earth.tres")

## Avancement du plan : 0 au début, 1 à la fin (animé par la table de montage).
@export_range(0.0, 1.0) var progress: float = 0.0:
	set(value):
		progress = value
		queue_redraw()
## Éclair : 0 = rien, 1 = plein éclat (animé par la table de montage).
@export_range(0.0, 1.0) var flash: float = 0.0:
	set(value):
		flash = value
		queue_redraw()

## Secondes écoulées depuis que le plan est visible.
var time: float = 0.0


func _ready() -> void:
	visible = false
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED  # pour les matières (tex_poly)
	visibility_changed.connect(func() -> void: time = 0.0)


func _process(delta: float) -> void:
	if visible:
		time += delta
		queue_redraw()


# --------------------------------------------------------------------------
# Outils de dessin communs
# --------------------------------------------------------------------------

## Remplit tout le cadre.
func fill(color: Color) -> void:
	draw_rect(Rect2(0.0, 0.0, W, H), color)


## Dégradé vertical (ciel, mur) entre deux ordonnées.
func vertical_gradient(top_y: float, bottom_y: float, top: Color, bottom: Color) -> void:
	draw_polygon(PackedVector2Array([Vector2(0, top_y), Vector2(W, top_y), Vector2(W, bottom_y), Vector2(0, bottom_y)]),
			PackedColorArray([top, top, bottom, bottom]))


## Polygone recouvert d'une matière (béton, tôle…), teintée par « color ».
func tex_poly(points: Array, color: Color, style: SurfaceStyle) -> void:
	var p := PackedVector2Array(points)
	draw_colored_polygon(p, color, style.draw_uvs_for(p), style.canvas_texture())


## Polygone en dégradé : couleur « from » du côté opposé à « axis », « to » du
## côté vers lequel pointe « axis » (vers le bas par défaut). Donne du volume.
func shade_poly(points: Array, from: Color, to: Color, axis: Vector2 = Vector2.DOWN) -> void:
	var p := PackedVector2Array(points)
	var low: float = INF
	var high: float = -INF
	for point in p:
		low = minf(low, point.dot(axis))
		high = maxf(high, point.dot(axis))
	var colors := PackedColorArray()
	for point in p:
		colors.append(from.lerp(to, (point.dot(axis) - low) / maxf(high - low, 0.001)))
	draw_polygon(p, colors)


## Halo doux : des disques de plus en plus grands et transparents.
func glow_at(center: Vector2, radius: float, color: Color, layers: int = 6) -> void:
	for i in layers:
		var k: float = float(i + 1) / layers
		draw_circle(center, radius * k, Color(color, color.a * 0.35 * (1.0 - k) + color.a * 0.04))


## Polygone plein à partir d'une liste de points.
func poly(points: Array, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points), color)


## Pluie : des traits obliques qui tombent. Chaque goutte a une position de départ
## fixe (calculée par une petite formule) et descend avec le temps.
func draw_rain(count: int = 160, color: Color = Color(0.7, 0.8, 0.95, 0.28), speed: float = 900.0,
		slant: float = 0.22, length: float = 26.0) -> void:
	for i in count:
		var seed_x: float = fposmod(i * 97.13, W + 200.0) - 100.0
		var offset: float = fposmod(i * 53.7, H)
		var y: float = fposmod(offset + time * speed * (0.85 + 0.3 * fposmod(i * 0.618, 1.0)), H + 60.0) - 30.0
		var x: float = seed_x - y * slant
		draw_line(Vector2(x, y), Vector2(x - length * slant, y - length), color, 1.2)


## Éclair : une ligne brisée de « from » à « to », avec quelques branches.
## « seed » fixe la forme (le même éclair à chaque image).
func draw_bolt(from: Vector2, to: Vector2, seed: int, color: Color, width: float = 3.0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var points := PackedVector2Array([from])
	var steps: int = 12
	for k in range(1, steps):
		var base: Vector2 = from.lerp(to, float(k) / steps)
		points.append(base + Vector2(rng.randf_range(-28.0, 28.0), rng.randf_range(-8.0, 8.0)))
	points.append(to)
	draw_polyline(points, Color(color, color.a * 0.35), width * 4.0)  # halo
	draw_polyline(points, color, width)
	for b in 3:  # branches
		var start: Vector2 = points[rng.randi_range(2, steps - 3)]
		var end: Vector2 = start + Vector2(rng.randf_range(-110.0, 110.0), rng.randf_range(60.0, 150.0))
		draw_polyline(PackedVector2Array([start, start.lerp(end, 0.5) + Vector2(rng.randf_range(-20, 20), 0), end]),
				Color(color, color.a * 0.7), width * 0.5)


## Courbe douce : 0 → 1 lent au début et à la fin.
static func ease_in_out(x: float) -> float:
	var t: float = clampf(x, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## Avancement ramené à une sous-partie du plan : 0 avant « a », 1 après « b ».
func phase(a: float, b: float) -> float:
	return clampf((progress - a) / maxf(b - a, 0.0001), 0.0, 1.0)


## Le laboratoire sur sa falaise (plans 2 et 9) : un bloc principal, une tour à
## antenne, la coupole de la salle du portail. « at » = coin bas-gauche du bâtiment,
## « k » = échelle, « lit » = couleur des fenêtres, « light » = éclairage par
## l'éclair (0 à 1) : les façades pâlissent.
func draw_lab(at: Vector2, k: float, lit: Color, light: float) -> void:
	var wall: Color = Color("0d1219").lerp(Color("55657a"), light)
	var edge: Color = Color("151c26").lerp(Color("8fa2b8"), light)
	# Coupole (demi-disque) derrière le bloc principal.
	var dome := PackedVector2Array()
	for i in 13:
		var a: float = PI + PI * i / 12.0
		dome.append(at + Vector2(210.0 + cos(a) * 120.0, -110.0 + sin(a) * 90.0) * k)
	draw_colored_polygon(dome, wall.darkened(0.15))
	tex_poly([at, at + Vector2(0, -110) * k, at + Vector2(330, -110) * k, at + Vector2(330, 0) * k], wall.lightened(0.15), CONCRETE)
	# Tour et antenne.
	tex_poly([at + Vector2(270, -110) * k, at + Vector2(270, -200) * k, at + Vector2(318, -200) * k, at + Vector2(318, -110) * k], wall.lightened(0.15), CONCRETE)
	draw_line(at + Vector2(294, -200) * k, at + Vector2(294, -262) * k, edge, 3.0 * k)
	draw_circle(at + Vector2(294, -262) * k, 3.5 * k, Color(1.0, 0.25, 0.2, 0.9))  # feu de balisage
	draw_line(at + Vector2(0, -110) * k, at + Vector2(330, -110) * k, edge, 2.0)
	# Fenêtres : une rangée, quelques-unes allumées.
	for i in 9:
		var x: float = 18.0 + i * 28.0
		var on: bool = (i * 7) % 3 != 0
		var c: Color = lit if on else Color("1b2430")
		draw_rect(Rect2(at + Vector2(x, -78) * k, Vector2(14, 20) * k), c)
		if on:
			glow_at(at + Vector2(x + 7, -68) * k, 26.0 * k, Color(lit, 0.5))
