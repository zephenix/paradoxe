extends IntroShot
## Plan 11 — flash blanc, puis le laboratoire vide : de la fumée, l'anneau éteint,
## la photo qui tombe au sol en tournoyant. Fondu au noir, et le titre PARADOXE
## apparaît, sans musique.

const TITLE: String = "PARADOXE"
const FLOOR_Y: float = 560.0


func _draw() -> void:
	fill(Color("06080b"))
	# La salle vide : l'anneau éteint (juste un contour), le sol.
	draw_rect(Rect2(0, FLOOR_Y, W, H - FLOOR_Y), Color("0d1116"))
	var ring := PackedVector2Array()
	for i in 13:
		var a: float = i / 12.0 * TAU
		ring.append(Vector2(640.0, 330.0) + Vector2(cos(a) * 220.0, sin(a) * 180.0))
	draw_polyline(ring, Color("1b232c"), 10.0)
	draw_polyline(ring, Color(GLOW, 0.06 * (1.0 - phase(0.1, 0.5))), 4.0)
	# Fumée : des nappes rondes, grises, qui montent et s'étalent.
	for k in 9:
		var life: float = fposmod(progress * 1.3 + k * 0.11, 1.0)
		var p := Vector2(420.0 + k * 55.0 + 40.0 * sin(k * 2.1 + time * 0.3), FLOOR_Y - 60.0 - life * 300.0)
		var r: float = 50.0 + 110.0 * life
		for layer in 3:  # trois couches de plus en plus larges et transparentes : un bord flou
			draw_circle(p, r * (0.6 + 0.2 * layer), Color(0.55, 0.6, 0.62, 0.05 * (1.0 - life)))
	# La photo : elle tombe en tournoyant, puis reste au sol.
	var fall: float = phase(0.05, 0.4)
	var photo_pos := Vector2(lerpf(760.0, 700.0, fall) + 40.0 * sin(fall * 9.0), lerpf(140.0, FLOOR_Y - 4.0, fall * fall))
	var angle: float = lerpf(0.3, 1.52, fall) + 0.4 * sin(fall * 11.0) * (1.0 - fall)
	var squash: float = lerpf(1.0, 0.18, phase(0.37, 0.4))  # à plat : vue par la tranche
	draw_set_transform(photo_pos, angle, Vector2(1.0, squash))
	draw_rect(Rect2(-40, -30, 80, 60), Color("d9d4c8"))
	draw_rect(Rect2(-34, -24, 68, 48), Color("5d7a8c"))
	draw_set_transform(Vector2.ZERO)
	# Flash blanc au début, qui s'éteint.
	var white: float = 1.0 - phase(0.0, 0.12)
	if white > 0.0:
		fill(Color(1.0, 1.0, 1.0, white))
	# Fondu au noir, puis le titre.
	var dark: float = phase(0.55, 0.7)
	if dark > 0.0:
		fill(Color(0.0, 0.0, 0.0, dark))
	var title_alpha: float = phase(0.76, 0.9)
	if title_alpha > 0.0:
		_draw_title(title_alpha)


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
		draw_string(font, Vector2(x, 395.0), TITLE[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.86, 1.0, 0.94, alpha))
		x += widths[i] + spacing
	draw_line(Vector2(W / 2.0 - 160.0 * alpha, 430.0), Vector2(W / 2.0 + 160.0 * alpha, 430.0), Color(GLOW, 0.6 * alpha), 2.0)
