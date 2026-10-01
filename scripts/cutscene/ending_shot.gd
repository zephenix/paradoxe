extends IntroShot
## Plan final du prototype (J8, écran 8) : la caméra RECULE. On part d'un gros plan
## (une créature agenouillée pose un pendentif en spirale sur le sol) et on
## découvre peu à peu toute la scène : la jungle rayonne depuis un cratère,
## centré sur l'anneau du portail, qui luit du même vert que dans l'intro.
## Le titre apparaît à la fin.
##
## Même principe que les plans de l'intro : « progress » va de 0 à 1 (animé par
## la cinématique) ; le recul est un agrandissement qui diminue (3,2 → 1).

const PortalRing: GDScript = preload("res://scripts/fx/portal_ring.gd")
const RING_CENTER := Vector2(700.0, 470.0)
const PENDANT := Vector2(560.0, 560.0)
const START_ZOOM: float = 3.2

var ring: Node2D
var creature: SentinelVisual


func _ready() -> void:
	super._ready()
	ring = PortalRing.new()
	ring.name = "Ring"
	ring.position = RING_CENTER
	ring.scale = Vector2(1.0, 0.45)  # vu de loin, couché dans le cratère
	ring.set(&"radius", 150.0)
	ring.set(&"intensity", 1.4)
	add_child(ring)
	creature = SentinelVisual.new()
	creature.name = "Creature"
	creature.position = PENDANT + Vector2(-34.0, 6.0)
	add_child(creature)
	creature.set_facing(1)
	visibility_changed.connect(func() -> void:
		if visible:
			creature.play(&"crouch"))


func _process(delta: float) -> void:
	super._process(delta)
	# Le recul de la caméra : tout le plan (et ses enfants) s'agrandit autour du
	# pendentif, de moins en moins.
	var zoom: float = lerpf(START_ZOOM, 1.0, ease_in_out(phase(0.05, 0.75)))
	scale = Vector2(zoom, zoom)
	position = PENDANT * (1.0 - zoom)


func _draw() -> void:
	vertical_gradient(-200.0, H + 200.0, Color("050810"), Color("0e1a1c"))
	for i in 90:  # étoiles
		var star := Vector2(fposmod(i * 211.7, W + 800.0) - 400.0, fposmod(i * 97.3, 380.0) - 160.0)
		draw_circle(star, 1.0 + fposmod(i * 0.37, 1.0), Color(0.8, 0.9, 1.0, 0.25 + 0.4 * fposmod(i * 0.618, 1.0)))
	# Villes en ruine à l'horizon : silhouettes en béton, sommets brisés.
	for i in 12:
		var x: float = -200.0 + i * 150.0
		var h: float = 80.0 + 60.0 * fposmod(i * 0.618, 1.0)
		tex_poly([Vector2(x, 440.0), Vector2(x, 400.0 - h), Vector2(x + 40.0, 400.0 - h - 12.0), Vector2(x + 70.0, 400.0 - h + 10.0),
				Vector2(x + 110.0, 400.0 - h - 4.0), Vector2(x + 110.0, 440.0)], Color("141c22"), CONCRETE)
	# Le sol de la jungle, puis les arbres couchés en étoile autour du cratère,
	# tous dans le même sens : quelque chose a soufflé depuis le centre.
	tex_poly([Vector2(-400, 400), Vector2(W + 400, 400), Vector2(W + 400, H + 400), Vector2(-400, H + 400)], Color("1c2a24"), EARTH)
	shade_poly([Vector2(-400, 400), Vector2(W + 400, 400), Vector2(W + 400, H + 400), Vector2(-400, H + 400)], Color(0, 0, 0, 0.65), Color(0, 0, 0, 0.2))
	for k in 34:
		var a: float = PI + (k + 0.5) / 34.0 * PI  # vers le haut et les côtés
		var dir := Vector2(cos(a) * 1.6, sin(a) * 0.45)
		var start: Vector2 = RING_CENTER + Vector2(0, 60) + dir * (300.0 + 30.0 * fposmod(k * 0.37, 1.0))
		var tip: Vector2 = start + dir * (140.0 + 120.0 * fposmod(k * 0.61, 1.0))
		_fallen_tree(start, tip, 10.0 - 4.0 * fposmod(k * 0.7, 1.0), k)
	# Le cratère : une cuvette de terre, éclairée de vert par l'anneau au centre.
	var bowl := PackedVector2Array()
	for i in 41:
		var a: float = i / 40.0 * TAU
		bowl.append(RING_CENTER + Vector2(cos(a) * 420.0, sin(a) * 120.0 + 60.0))
	tex_poly(Array(bowl), Color("1a2520"), EARTH)
	for i in 6:  # la lueur verte : des ellipses de plus en plus petites et claires
		var k: float = 1.0 - i * 0.15
		var glow := PackedVector2Array()
		for j in 33:
			var a: float = j / 32.0 * TAU
			glow.append(RING_CENTER + Vector2(cos(a) * 400.0 * k, sin(a) * 110.0 * k + 55.0))
		draw_colored_polygon(glow, Color(GLOW, 0.035))
	# Le bord : terre retournée, plus claire, et des blocs de roche.
	draw_polyline(bowl, Color("3a4a3c"), 5.0)
	draw_polyline(bowl, Color(GLOW, 0.25), 2.0)
	for i in 22:
		var a: float = i / 22.0 * TAU + 0.1
		var rock: Vector2 = RING_CENTER + Vector2(cos(a) * 425.0, sin(a) * 124.0 + 58.0)
		var r: float = 5.0 + 6.0 * fposmod(i * 0.618, 1.0)
		shade_poly([rock + Vector2(-r, 0), rock + Vector2(-r * 0.5, -r * 0.8), rock + Vector2(r * 0.6, -r * 0.7), rock + Vector2(r, 0)],
				Color("4c5a50"), Color("1c2420"))
	tex_poly([Vector2(-400.0, 600.0), Vector2(W + 400.0, 600.0), Vector2(W + 400.0, 1000.0), Vector2(-400.0, 1000.0)], Color("0d1310"), EARTH)
	# Le pendentif posé au sol : une spirale qui brille.
	var spiral := PackedVector2Array()
	for i in 26:
		var a: float = i / 25.0 * 2.0 * TAU
		spiral.append(PENDANT + Vector2(cos(a), sin(a) * 0.6) * 7.0 * (i / 25.0))
	glow_at(PENDANT, 16.0, Color(GLOW, 0.35 + 0.15 * sin(time * 3.0)))
	draw_polyline(spiral, GLOW, 1.6)
	# Titre, à la fin.
	var title: float = phase(0.8, 0.95)
	if title > 0.0:
		var font: Font = ThemeDB.fallback_font
		draw_string(font, Vector2(0.0, 160.0), "PARADOXE", HORIZONTAL_ALIGNMENT_CENTER, W, 64, Color(0.86, 1.0, 0.94, title))
		draw_string(font, Vector2(0.0, 200.0), "fin du prototype", HORIZONTAL_ALIGNMENT_CENTER, W, 22, Color(0.6, 0.8, 0.74, title))


## Un arbre couché : un tronc qui s'amincit (la base, côté cratère, est arrachée),
## quelques branches cassées, et de la mousse qui luit.
func _fallen_tree(base: Vector2, tip: Vector2, width: float, seed_value: int) -> void:
	var normal: Vector2 = (tip - base).orthogonal().normalized()
	shade_poly([base + normal * width, tip + normal * width * 0.3, tip - normal * width * 0.3, base - normal * width],
			Color("3a3128"), Color("16120f"), normal * -1.0)
	for b in 3:
		var u: float = 0.3 + 0.22 * b
		var at: Vector2 = base.lerp(tip, u)
		var side: float = 1.0 if (seed_value + b) % 2 == 0 else -1.0
		draw_line(at, at + (tip - base).normalized() * 14.0 + normal * side * 16.0, Color("2a231d"), 2.0)
	draw_circle(base.lerp(tip, 0.15), 2.5, Color(GLOW, 0.5 + 0.2 * sin(time * 2.0 + seed_value)))
