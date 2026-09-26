extends IntroShot
## Plan 3 — plan large : un glisseur arrive dans la pluie, phares balayant la
## route, et se pose devant l'entrée éclairée du laboratoire.

const GROUND_Y: float = 540.0


func _draw() -> void:
	vertical_gradient(0.0, GROUND_Y, Color("080c13"), Color("141c27"))
	# Façade de l'entrée à droite, porte éclairée, auvent.
	poly([Vector2(820, GROUND_Y), Vector2(820, 250), Vector2(W, 230), Vector2(W, GROUND_Y)], Color("121821"))
	draw_rect(Rect2(930, 420, 90, GROUND_Y - 420), Color("d9e8e0"))
	draw_rect(Rect2(900, 400, 150, GROUND_Y - 400), Color(0.85, 0.95, 0.9, 0.1))
	poly([Vector2(890, 405), Vector2(1060, 405), Vector2(1080, 390), Vector2(870, 390)], Color("2b3440"))
	for i in 5:
		draw_rect(Rect2(1090 + (i % 3) * 55, 290 + floorf(i / 3.0) * 60, 30, 36), Color("e8d9a6") if i != 2 else Color("1b2430"))
	# Sol mouillé : reflet de la porte.
	draw_rect(Rect2(0, GROUND_Y, W, H - GROUND_Y), Color("0a0e14"))
	draw_rect(Rect2(930, GROUND_Y, 90, 80), Color(0.85, 0.95, 0.9, 0.08))
	# Le glisseur : il entre par la gauche, ralentit, descend et se pose.
	var k: float = 1.0 - pow(1.0 - clampf(progress / 0.78, 0.0, 1.0), 2.4)  # freine en arrivant
	var pos := Vector2(lerpf(-260.0, 700.0, k), lerpf(360.0, GROUND_Y - 30.0, ease_in_out(k)))
	var tilt: float = lerpf(0.08, 0.0, k)
	var lights_on: float = 1.0 - phase(0.85, 1.0)
	# Faisceau des phares : un triangle transparent devant lui, qui balaie la route.
	var beam_dir := Vector2(1.0, 0.18 + 0.12 * sin(time * 1.3)).rotated(tilt).normalized()
	var tip: Vector2 = pos + Vector2(100, -4)
	var side: Vector2 = beam_dir.orthogonal() * 120.0
	draw_colored_polygon(PackedVector2Array([tip, tip + beam_dir * 520.0 + side, tip + beam_dir * 520.0 - side]),
			Color(1.0, 0.97, 0.85, 0.13 * lights_on))
	draw_set_transform(pos, tilt)
	poly([Vector2(-110, 8), Vector2(-90, -14), Vector2(-20, -24), Vector2(60, -22), Vector2(108, -6), Vector2(104, 10), Vector2(-100, 16)], Color("303946"))
	poly([Vector2(-30, -22), Vector2(10, -38), Vector2(56, -34), Vector2(70, -20)], Color("5c7488"))  # verrière
	draw_line(Vector2(-100, 17), Vector2(100, 11), Color(GLOW, 0.8), 3.0)  # lueur sous la coque
	draw_circle(Vector2(102, -2), 5.0, Color(1.0, 0.97, 0.85, lights_on))
	draw_circle(Vector2(-106, 2), 3.5, Color(1.0, 0.2, 0.15, 0.9))
	draw_set_transform(Vector2.ZERO)
	# Lueur verte au sol sous le glisseur, qui grandit quand il approche du sol.
	var hover: float = clampf(1.0 - (GROUND_Y - 30.0 - pos.y) / 180.0, 0.0, 1.0)
	draw_rect(Rect2(pos.x - 110, GROUND_Y, 220, 6), Color(GLOW, 0.25 * hover))
	draw_rain(150)
