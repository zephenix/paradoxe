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
	# Villes en ruine à l'horizon.
	for i in 12:
		var x: float = -200.0 + i * 150.0
		var h: float = 80.0 + 60.0 * fposmod(i * 0.618, 1.0)
		draw_rect(Rect2(x, 400.0 - h, 110.0, h + 40.0), Color("0b1116"))
	# La jungle rayonne depuis le cratère : des traînées vertes qui s'éloignent.
	for k in 28:
		var a: float = PI + k / 27.0 * PI  # vers le haut et les côtés
		var reach: float = 420.0 + 200.0 * fposmod(k * 0.37, 1.0)
		var tip: Vector2 = RING_CENTER + Vector2(cos(a) * reach * 1.6, sin(a) * reach * 0.45)
		draw_line(RING_CENTER, tip, Color(GLOW, 0.05 + 0.04 * sin(time + k)), 14.0)
		draw_circle(tip, 5.0, Color(GLOW, 0.5))
	# Le cratère : une cuvette sombre, bordée de végétation lumineuse.
	var bowl := PackedVector2Array()
	for i in 33:
		var a: float = i / 32.0 * TAU
		bowl.append(RING_CENTER + Vector2(cos(a) * 420.0, sin(a) * 120.0 + 60.0))
	draw_colored_polygon(bowl, Color("070b0c"))
	draw_polyline(bowl, Color(GLOW, 0.35), 3.0)
	draw_rect(Rect2(-400.0, 600.0, W + 800.0, 400.0), Color("070b0c"))
	# Le pendentif posé au sol : une spirale qui brille.
	var spiral := PackedVector2Array()
	for i in 26:
		var a: float = i / 25.0 * 2.0 * TAU
		spiral.append(PENDANT + Vector2(cos(a), sin(a) * 0.6) * 7.0 * (i / 25.0))
	draw_circle(PENDANT, 14.0, Color(GLOW, 0.2 + 0.1 * sin(time * 3.0)))
	draw_polyline(spiral, GLOW, 1.6)
	# Titre, à la fin.
	var title: float = phase(0.8, 0.95)
	if title > 0.0:
		var font: Font = ThemeDB.fallback_font
		draw_string(font, Vector2(0.0, 160.0), "PARADOXE", HORIZONTAL_ALIGNMENT_CENTER, W, 64, Color(0.86, 1.0, 0.94, title))
		draw_string(font, Vector2(0.0, 200.0), "fin du prototype", HORIZONTAL_ALIGNMENT_CENTER, W, 22, Color(0.6, 0.8, 0.74, title))
