extends Node2D
## Anneau du portail, entièrement dessiné par code (aucune image).
##
## Style « polygones aplatis » : un anneau à facettes, un halo fait de
## couches transparentes superposées, une spirale qui tourne lentement et
## quelques étincelles. La fonction _draw() est appelée à chaque image grâce
## à queue_redraw() dans _process().

## Rayon de l'anneau, en pixels.
@export var radius: float = 150.0
## Nombre de facettes de l'anneau.
@export var sides: int = 12
## Couleur principale (vert bioluminescent : le fil rouge du twist).
@export var glow_color: Color = Color("6effbf")
## Vitesse de rotation de la spirale (radians par seconde).
@export var spin_speed: float = 0.35
## Intensité générale (0 = éteint, 1 = normal, >1 = surcharge).
@export_range(0.0, 3.0) var intensity: float = 1.0

var _time: float = 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var pulse: float = 0.5 + 0.5 * sin(_time * 1.7)
	var ring: PackedVector2Array = _polygon_points(radius, _time * 0.04)

	# Halo : couches de plus en plus larges et transparentes.
	for layer in range(7, 0, -1):
		var alpha: float = (0.045 + 0.03 * pulse) * intensity / float(layer)
		draw_polyline(ring, Color(glow_color, alpha), 8.0 + layer * 9.0, true)

	# Fond du portail : disques sombres légèrement teintés.
	draw_circle(Vector2.ZERO, radius * 0.93, Color(0.02, 0.07, 0.06, 0.9))
	draw_circle(Vector2.ZERO, radius * 0.6, Color(glow_color, 0.04 * intensity * (1.0 + pulse)))

	# Spirale : points dont la distance au centre croît avec l'angle.
	var spiral := PackedVector2Array()
	var turns: float = 3.2
	var steps: int = 140
	for i in steps + 1:
		var k: float = float(i) / steps
		var angle: float = k * turns * TAU - _time * spin_speed
		spiral.append(Vector2.from_angle(angle) * (radius * 0.08 + k * radius * 0.78))
	draw_polyline(spiral, Color(glow_color.lightened(0.6), 0.55 * intensity), 3.0, true)

	# Anneau principal, net.
	draw_polyline(ring, Color(glow_color, 0.95 * minf(intensity, 1.0)), 6.0, true)

	# Étincelles : positions pseudo-aléatoires qui changent 12 fois par seconde.
	var tick: int = int(_time * 12.0)
	for i in 5:
		var h: float = sin(float(tick * 7 + i * 13) * 12.9898) * 43758.5453
		h = h - floorf(h)
		if h > 0.55:
			continue
		var spark_angle: float = h * TAU * 3.0
		var spark_pos: Vector2 = Vector2.from_angle(spark_angle) * radius
		draw_circle(spark_pos, 2.0 + 3.0 * h, Color(1.0, 1.0, 1.0, 0.8 * intensity))


## Sommets d'un polygone régulier fermé (le dernier point répète le premier).
func _polygon_points(r: float, rotation_offset: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in sides + 1:
		points.append(Vector2.from_angle(TAU * i / sides + rotation_offset) * r)
	return points
