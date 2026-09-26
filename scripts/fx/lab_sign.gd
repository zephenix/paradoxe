@tool
class_name LabSign
extends Node2D
## Enseigne tordue du laboratoire (J8, écran 2) : un panneau de métal plié, à
## moitié mangé par la jungle, qui porte le LOGO du labo de l'intro (un anneau
## barré). Indice du twist : Élias n'est pas ailleurs, il est plus tard.
## draw_logo() dessine le même logo partout (intro, ruines).

## Taille du panneau (pixels).
@export var size: Vector2 = Vector2(200.0, 90.0):
	set(value):
		size = value
		queue_redraw()
## Inclinaison du panneau (degrés) : il s'est effondré.
@export var tilt_degrees: float = -14.0:
	set(value):
		tilt_degrees = value
		queue_redraw()

const METAL: Color = Color("4b5460")
const RUST: Color = Color("6b4a33")
const LOGO: Color = Color("c9d6d2")
const GLOW: Color = Color(0.43, 1.0, 0.69)


## Le logo du laboratoire : un anneau traversé par une barre, un point au centre.
## « canvas » : le nœud qui dessine (appelé pendant SON _draw()).
static func draw_logo(canvas: CanvasItem, center: Vector2, radius: float, color: Color, width: float = 4.0) -> void:
	canvas.draw_arc(center, radius, 0.0, TAU, 32, color, width)
	canvas.draw_line(center + Vector2(-radius * 1.55, 0.0), center + Vector2(radius * 1.55, 0.0), color, width)
	canvas.draw_circle(center, width * 0.9, color)


func _draw() -> void:
	# Pied tordu, puis le panneau incliné, plié en deux, rouillé ; une liane dessus.
	draw_line(Vector2(0, 0), Vector2(-10, -size.y * 0.6), METAL.darkened(0.3), 8.0)
	draw_set_transform(Vector2(-10.0, -size.y * 0.6), deg_to_rad(tilt_degrees))
	var half: float = size.x * 0.5
	draw_colored_polygon(PackedVector2Array([Vector2(-half, -size.y), Vector2(0, -size.y + 8), Vector2(0, 8), Vector2(-half, 0)]), METAL)
	draw_colored_polygon(PackedVector2Array([Vector2(0, -size.y + 8), Vector2(half, -size.y + 26), Vector2(half, 22), Vector2(0, 8)]), METAL.darkened(0.2))
	draw_colored_polygon(PackedVector2Array([Vector2(half * 0.3, -18), Vector2(half, 2), Vector2(half, 22), Vector2(half * 0.2, 6)]), RUST)
	draw_logo(self, Vector2(-half * 0.45, -size.y * 0.5), size.y * 0.24, LOGO, 5.0)
	draw_polyline(PackedVector2Array([Vector2(-half - 10, -size.y - 6), Vector2(-half * 0.4, -size.y + 20), Vector2(0, -size.y + 4),
			Vector2(half * 0.5, -size.y + 40), Vector2(half * 0.7, 10)]), Color(0.1, 0.22, 0.2), 4.0)
	for k in 4:
		draw_circle(Vector2(-half * 0.8 + k * half * 0.45, -size.y + 12 + (k % 2) * 20), 3.0, Color(GLOW, 0.8))
	draw_set_transform(Vector2.ZERO)
