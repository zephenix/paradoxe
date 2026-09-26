extends IntroShot
## Plan 8 — contre-plongée : l'anneau du portail s'allume, lueur VERTE, arcs
## électriques de plus en plus nombreux. Le même anneau que sur l'écran titre
## (portal_ring.gd), vu d'en bas.

const PortalRing: GDScript = preload("res://scripts/fx/portal_ring.gd")
const CENTER := Vector2(640.0, 330.0)
const RADIUS: float = 230.0

var ring: Node2D
## Calque des arcs électriques, au-dessus de l'anneau (un enfant se dessine
## après son parent et ses frères précédents).
var arcs: Node2D


func _ready() -> void:
	super._ready()
	ring = PortalRing.new()
	ring.name = "Ring"
	ring.position = CENTER
	ring.scale = Vector2(1.0, 0.82)  # vu d'en bas : légèrement écrasé
	ring.set(&"radius", RADIUS)
	ring.set(&"intensity", 0.0)
	add_child(ring)
	arcs = Node2D.new()
	arcs.name = "Arcs"
	arcs.draw.connect(_draw_arcs)
	add_child(arcs)


func _process(delta: float) -> void:
	super._process(delta)
	if visible:
		ring.set(&"intensity", 0.05 + 2.4 * pow(progress, 1.4))
		ring.set(&"spin_speed", 0.3 + 2.5 * progress)
		arcs.queue_redraw()


func _draw() -> void:
	fill(Color("05070a"))
	# Poutres du plafond qui fuient vers le haut (effet de contre-plongée).
	var vanish := Vector2(640.0, -500.0)
	for i in 9:
		var x: float = -200.0 + i * 210.0
		draw_line(Vector2(x, H), vanish.lerp(Vector2(x, H), 0.55), Color("11161d"), 14.0)
	# Sol : une lueur verte qui grandit sous l'anneau.
	var glow: float = pow(progress, 1.2)
	draw_circle(Vector2(640.0, 760.0), 420.0, Color(GLOW, 0.1 * glow))
	# Câbles qui montent vers l'anneau.
	for side: float in [-1.0, 1.0]:
		draw_line(Vector2(640.0 + side * 520.0, H), CENTER + Vector2(side * RADIUS, 40.0), Color("1a2027"), 6.0)


## Arcs électriques entre deux points de l'anneau, de plus en plus nombreux ;
## chacun change de forme plusieurs fois par seconde.
func _draw_arcs() -> void:
	var count: int = int(progress * 8.0)
	var frame: int = int(time * 12.0)
	for k in count:
		var rng := RandomNumberGenerator.new()
		rng.seed = frame * 31 + k * 7
		var a: float = rng.randf() * TAU
		var b: float = a + rng.randf_range(0.6, 2.2)
		var from: Vector2 = CENTER + Vector2(cos(a), sin(a) * 0.82) * RADIUS
		var to: Vector2 = CENTER + Vector2(cos(b), sin(b) * 0.82) * RADIUS
		var points := PackedVector2Array([from])
		for j in range(1, 8):
			var mid: Vector2 = from.lerp(to, j / 8.0).lerp(CENTER, 0.25 * sin(j / 8.0 * PI))
			points.append(mid + Vector2(rng.randf_range(-14, 14), rng.randf_range(-14, 14)))
		points.append(to)
		arcs.draw_polyline(points, Color(GLOW, 0.35), 7.0)
		arcs.draw_polyline(points, Color(0.9, 1.0, 0.95, 0.9), 2.0)
