extends IntroShot
## Plan 11 — flash blanc, puis le laboratoire vide : l'anneau du portail, debout
## sur son socle, s'éteint (ses dernières braises s'envolent) ; de la fumée ; la
## photo (Élias et Marek) tombe en tournoyant et se pose au premier plan. Fondu au
## noir, et le titre PARADOXE apparaît, sans musique.
##
## L'anneau est un CADRE de métal, debout : à travers, on voit le mur du fond. Un
## disque sombre, ou un anneau couché sur le sol, se lirait comme un trou.
##
## Deux profondeurs : le fond (mur, sol, anneau, socle) dans _draw() ; devant, un
## calque « Front » (fumée, photo, flash, fondu, titre).

const TITLE: String = "PARADOXE"
const FLOOR_Y: float = 560.0
const RING_CENTER := Vector2(640.0, 305.0)
const RING_OUTER: float = 200.0
const RING_INNER: float = 168.0
const RING_SIDES: int = 12

var front: Node2D


func _ready() -> void:
	super._ready()
	front = Node2D.new()
	front.name = "Front"
	front.draw.connect(_draw_front)
	add_child(front)


func _process(delta: float) -> void:
	super._process(delta)
	if visible:
		front.queue_redraw()


## Le fond : le mur du labo (des panneaux), le sol, l'anneau, son socle, les câbles.
func _draw() -> void:
	fill(Color("07090c"))
	for i in 9:
		var x: float = i * 160.0
		tex_poly([Vector2(x + 6.0, 90.0), Vector2(x + 154.0, 90.0), Vector2(x + 154.0, FLOOR_Y), Vector2(x + 6.0, FLOOR_Y)], Color("161c24"), METAL)
		draw_line(Vector2(x + 20.0, 250.0), Vector2(x + 140.0, 250.0), Color("121820"), 2.0)
	tex_poly([Vector2(0.0, FLOOR_Y), Vector2(W, FLOOR_Y), Vector2(W, H), Vector2(0.0, H)], Color("1a1f26"), CONCRETE)
	for i in 12:  # joints du sol, en perspective
		var x: float = -200.0 + i * 150.0
		draw_line(Vector2(640.0 + (x - 640.0) * 0.6, FLOOR_Y), Vector2(x, H), Color("151a21"), 2.0)
	_draw_ring(1.0 - phase(0.05, 0.5))
	# Le socle, qui tient le bas de l'anneau, et les câbles qui en partent.
	poly([Vector2(500, FLOOR_Y), Vector2(780, FLOOR_Y), Vector2(730, 488), Vector2(550, 488)], Color("1a2027"))
	draw_line(Vector2(552, 490), Vector2(728, 490), Color("2a323c"), 3.0)
	for side: float in [-1.0, 1.0]:
		draw_polyline(PackedVector2Array([Vector2(640.0 + side * 110.0, 540.0), Vector2(640.0 + side * 300.0, 600.0),
				Vector2(640.0 + side * 640.0, 610.0)]), Color("141a21"), 6.0)


## L'anneau éteint : douze facettes de métal (plus claires en haut, éclairées par
## les néons du plafond), un liseré vert qui meurt et quelques braises.
## ember : 1 = encore chaud, 0 = froid.
func _draw_ring(ember: float) -> void:
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in RING_SIDES + 1:
		var dir: Vector2 = Vector2.from_angle(TAU * i / RING_SIDES)
		outer.append(RING_CENTER + dir * RING_OUTER)
		inner.append(RING_CENTER + dir * RING_INNER)
	for i in RING_SIDES:
		var normal: Vector2 = ((outer[i] + outer[i + 1]) * 0.5 - RING_CENTER).normalized()
		var shade: Color = Color("262e38").lightened(0.25 * maxf(0.0, -normal.y))
		draw_colored_polygon(PackedVector2Array([outer[i], outer[i + 1], inner[i + 1], inner[i]]), shade)
	draw_polyline(outer, Color("3a4450"), 2.0)
	# Le liseré intérieur : il rougeoie encore en vert, puis s'éteint.
	if ember > 0.0:
		for layer in range(4, 0, -1):
			draw_polyline(inner, Color(GLOW, 0.08 * ember / float(layer)), 4.0 + layer * 8.0)
		draw_polyline(inner, Color(GLOW, 0.7 * ember), 3.0)
		# Braises : elles se détachent du cadre et montent.
		for k in 10:
			var life: float = fposmod(time * 0.35 + k * 0.1, 1.0)
			var at: Vector2 = RING_CENTER + Vector2.from_angle(k * 2.4) * (RING_INNER + 16.0) + Vector2(8.0 * sin(k + time), -70.0 * life)
			draw_circle(at, 2.5 * (1.0 - life), Color(GLOW, ember * (1.0 - life)))
	else:
		draw_polyline(inner, Color("1c2229"), 3.0)


## Devant l'anneau : la fumée, la photo, le flash, le fondu, le titre.
func _draw_front() -> void:
	# Fumée : des nappes rondes, grises, qui montent et s'étalent (bords flous).
	for k in 9:
		var life: float = fposmod(progress * 1.3 + k * 0.11, 1.0)
		var p := Vector2(420.0 + k * 55.0 + 40.0 * sin(k * 2.1 + time * 0.3), FLOOR_Y - 40.0 - life * 300.0)
		var r: float = 50.0 + 110.0 * life
		for layer in 3:
			front.draw_circle(p, r * (0.6 + 0.2 * layer), Color(0.55, 0.6, 0.62, 0.05 * (1.0 - life)))
	_draw_photo()
	# Flash blanc au début, qui s'éteint.
	var white: float = 1.0 - phase(0.0, 0.12)
	if white > 0.0:
		front.draw_rect(Rect2(0.0, 0.0, W, H), Color(1.0, 1.0, 1.0, white))
	# Fondu au noir, puis le titre.
	var dark: float = phase(0.55, 0.7)
	if dark > 0.0:
		front.draw_rect(Rect2(0.0, 0.0, W, H), Color(0.0, 0.0, 0.0, dark))
	var title_alpha: float = phase(0.76, 0.9)
	if title_alpha > 0.0:
		_draw_title(title_alpha)


## La photo du plan 6 : elle tombe en tournoyant, à droite de l'anneau, et se pose
## sur le sol, au premier plan (au-dessus de la bande noire du bas, y = 640). On y
## reconnaît les deux visages et, en vert, le pendentif.
func _draw_photo() -> void:
	var fall: float = phase(0.05, 0.4)
	var pos := Vector2(lerpf(1000.0, 940.0, fall) + 45.0 * sin(fall * 9.0), lerpf(110.0, 600.0, fall * fall))
	var angle: float = lerpf(0.4, 0.12, fall) + 0.5 * sin(fall * 11.0) * (1.0 - fall)
	var squash: float = lerpf(1.0, 0.35, phase(0.37, 0.4))  # posée à plat : vue en biais
	front.draw_set_transform(pos, angle, Vector2(1.0, squash))
	front.draw_rect(Rect2(-56, -40, 112, 80), Color("d9d4c8"))
	front.draw_rect(Rect2(-49, -33, 98, 66), Color("5d7a8c"))
	for side: float in [-1.0, 1.0]:
		var c := Vector2(side * 20.0, 4.0)
		front.draw_rect(Rect2(c.x - 13.0, c.y + 6.0, 26.0, 23.0), Color("b9c6cc") if side < 0.0 else Color("3d4a3f"))
		front.draw_circle(c, 9.0, Color("d6a387"))
		front.draw_arc(c + Vector2(0, -2), 9.5, PI * 1.05, PI * 1.95, 8, Color("241d1f") if side < 0.0 else Color("6b4a33"), 5.0)
	front.draw_circle(Vector2(20.0, 20.0), 2.5, GLOW)  # le pendentif
	front.draw_set_transform(Vector2.ZERO)


## Le titre, lettres espacées, centré.
func _draw_title(alpha: float) -> void:
	var font: Font = ThemeDB.fallback_font
	var size: int = 84
	var spacing: float = 30.0
	var widths: Array[float] = []
	var total: float = 0.0
	for letter: String in TITLE:
		var w: float = font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		widths.append(w)
		total += w + spacing
	total -= spacing
	var x: float = (W - total) / 2.0
	for i in TITLE.length():
		front.draw_string(font, Vector2(x, 395.0), TITLE[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.86, 1.0, 0.94, alpha))
		x += widths[i] + spacing
	front.draw_line(Vector2(W / 2.0 - 160.0 * alpha, 430.0), Vector2(W / 2.0 + 160.0 * alpha, 430.0), Color(GLOW, 0.6 * alpha), 2.0)
