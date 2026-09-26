extends IntroShot
## Plan 7 — gros plan : les mains d'Élias sur le terminal. À l'écran, des courbes
## et des pictogrammes (aucun texte) : les courbes s'emballent à mesure que
## l'expérience se lance.

const SCREEN := Rect2(170.0, 110.0, 940.0, 380.0)
const SKIN: Color = Color("d6a387")


func _draw() -> void:
	fill(Color("07090c"))
	# Écran : fond, grille.
	draw_rect(SCREEN.grow(10.0), Color("1c232b"))
	draw_rect(SCREEN, Color("041412"))
	for i in range(1, 10):
		var x: float = SCREEN.position.x + i * SCREEN.size.x / 10.0
		draw_line(Vector2(x, SCREEN.position.y), Vector2(x, SCREEN.end.y), Color(GLOW, 0.07), 1.0)
	for i in range(1, 5):
		var y: float = SCREEN.position.y + i * SCREEN.size.y / 5.0
		draw_line(Vector2(SCREEN.position.x, y), Vector2(SCREEN.end.x, y), Color(GLOW, 0.07), 1.0)
	# Trois courbes dont l'amplitude et la fréquence montent avec l'avancement.
	var energy: float = ease_in_out(progress)
	var colors: Array[Color] = [GLOW, Color("7fd8ff"), Color("ffc46b")]
	for c in 3:
		var points := PackedVector2Array()
		for i in 120:
			var u: float = i / 119.0
			var x: float = SCREEN.position.x + 20.0 + u * (SCREEN.size.x * 0.62)
			var amp: float = (18.0 + 70.0 * energy) * (1.0 - 0.25 * c)
			var y: float = SCREEN.position.y + 110.0 + c * 90.0 + amp * sin(u * (6.0 + 10.0 * energy + c * 3.0) * PI + time * (2.0 + c))
			points.append(Vector2(x, y))
		draw_polyline(points, colors[c], 2.0)
	# Pictogrammes : un anneau qui se remplit (la charge), des barres, un triangle d'alerte.
	var ring_c := Vector2(SCREEN.end.x - 150.0, SCREEN.position.y + 120.0)
	draw_arc(ring_c, 62.0, 0.0, TAU, 40, Color(GLOW, 0.2), 6.0)
	draw_arc(ring_c, 62.0, -PI / 2.0, -PI / 2.0 + TAU * energy, 40, GLOW, 6.0)
	for i in 5:
		var h: float = 20.0 + 90.0 * clampf(energy * 1.4 - i * 0.12, 0.05, 1.0)
		draw_rect(Rect2(SCREEN.end.x - 250.0 + i * 36.0, SCREEN.end.y - 30.0 - h, 22.0, h), Color(colors[i % 3], 0.8))
	if energy > 0.7 and fmod(time, 0.5) < 0.3:
		poly([Vector2(ring_c.x, ring_c.y - 34), Vector2(ring_c.x + 28, ring_c.y + 18), Vector2(ring_c.x - 28, ring_c.y + 18)], Color("ffc46b"))
	# Clavier et mains au premier plan ; les doigts tapent (petits sauts).
	poly([Vector2(120, 560), Vector2(1160, 560), Vector2(1240, H), Vector2(40, H)], Color("15191f"))
	for r in 3:
		for k in 16:
			draw_rect(Rect2(170.0 + k * 58.0 + r * 12.0, 572.0 + r * 30.0, 48.0, 22.0), Color("22282f"))
	var typing: float = 1.0 - phase(0.55, 0.7)  # il tape, puis s'arrête et regarde
	_draw_hand(Vector2(430.0, 610.0), 1.0, typing)
	_draw_hand(Vector2(850.0, 610.0), -1.0, typing)


func _draw_hand(at: Vector2, side: float, typing: float) -> void:
	poly([at + Vector2(-70 * side, 110), at + Vector2(-40 * side, 20), at + Vector2(60 * side, 10), at + Vector2(90 * side, 110)], Color("b9c6cc"))
	poly([at + Vector2(-44 * side, 24), at + Vector2(-30 * side, -26), at + Vector2(56 * side, -30), at + Vector2(60 * side, 14)], SKIN)
	for f in 4:
		var bob: float = typing * maxf(0.0, sin(time * 11.0 + f * 1.9 + side)) * 10.0
		var x: float = (-24.0 + f * 22.0) * side
		poly([at + Vector2(x, -26 - bob), at + Vector2(x + 14 * side, -26 - bob), at + Vector2(x + 16 * side, -64 - bob),
				at + Vector2(x + 2 * side, -64 - bob)], SKIN)
