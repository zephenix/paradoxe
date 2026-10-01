extends IntroShot
## Plan 6 — insert : sur le bureau, une photo d'Élias et de son collègue Marek,
## qui porte un PENDENTIF EN SPIRALE (on le retrouvera). Élias la regarde un
## instant : la caméra s'approche doucement de la photo.

const FRAME := Rect2(-190.0, -135.0, 380.0, 270.0)  # autour du centre de la photo


func _draw() -> void:
	fill(Color("12100f"))
	# Bureau : dégradé, un bord éclairé par la lampe.
	tex_poly([Vector2(0, 200), Vector2(W, 200), Vector2(W, H), Vector2(0, H)], Color("5a4334"), PLANKS)
	shade_poly([Vector2(0, 200), Vector2(W, 200), Vector2(W, H), Vector2(0, H)], Color(0, 0, 0, 0.35), Color(0, 0, 0, 0.75))
	draw_circle(Vector2(1040.0, 260.0), 260.0, Color(1.0, 0.85, 0.6, 0.05))
	# Tasse et tablette (pour situer le bureau).
	draw_rect(Rect2(930, 420, 70, 90), Color("3d4148"))
	draw_arc(Vector2(1005, 460), 20.0, -PI / 2.0, PI / 2.0, 12, Color("3d4148"), 8.0)
	poly([Vector2(120, 520), Vector2(420, 500), Vector2(440, 640), Vector2(130, 660)], Color("0c0f13"))
	# La photo, légèrement inclinée ; la caméra s'en approche.
	var zoom: float = 1.0 + 0.18 * ease_in_out(progress)
	draw_set_transform(Vector2(640.0, 380.0), -0.05, Vector2(zoom, zoom))
	draw_rect(FRAME.grow(12.0), Color("d9d4c8"))
	draw_rect(FRAME, Color("5d7a8c"))
	draw_rect(Rect2(FRAME.position.x, 20.0, FRAME.size.x, FRAME.end.y - 20.0), Color("41515c"))  # fond : une salle
	_draw_person(Vector2(-80.0, 135.0), Color("241d1f"), Color("b9c6cc"), 1.0, false)  # Élias
	_draw_person(Vector2(80.0, 135.0), Color("6b4a33"), Color("3d4a3f"), 1.08, true)   # Marek, jeune
	# Reflet sur le verre du cadre.
	draw_colored_polygon(PackedVector2Array([Vector2(40, -135), Vector2(110, -135), Vector2(-10, 135), Vector2(-80, 135)]),
			Color(1, 1, 1, 0.05))
	draw_set_transform(Vector2.ZERO)
	# L'épaule d'Élias, floue, au premier plan à gauche : il regarde la photo.
	draw_circle(Vector2(40.0, 700.0), 230.0, Color(0.0, 0.0, 0.0, 0.55))


## Un buste souriant. « pendant » : le pendentif en spirale sur la poitrine.
func _draw_person(base: Vector2, hair: Color, jacket: Color, k: float, pendant: bool) -> void:
	var skin: Color = Color("d6a387")
	poly([base + Vector2(-62, 0) * k, base + Vector2(-52, -70) * k, base + Vector2(52, -70) * k, base + Vector2(62, 0) * k], jacket)
	poly([base + Vector2(-12, -70) * k, base + Vector2(12, -70) * k, base + Vector2(10, -84) * k, base + Vector2(-10, -84) * k], skin)
	draw_circle(base + Vector2(0, -112) * k, 30.0 * k, skin)
	draw_arc(base + Vector2(0, -118) * k, 31.0 * k, PI * 1.05, PI * 1.95, 12, hair, 14.0 * k)
	draw_arc(base + Vector2(0, -104) * k, 12.0 * k, 0.3, PI - 0.3, 8, Color("7a4a3a"), 2.0)  # sourire
	draw_circle(base + Vector2(-10, -116) * k, 2.2 * k, Color("2a1a14"))
	draw_circle(base + Vector2(10, -116) * k, 2.2 * k, Color("2a1a14"))
	if pendant:
		draw_line(base + Vector2(-14, -70) * k, base + Vector2(0, -42) * k, Color("c8c2b0"), 1.0)
		draw_line(base + Vector2(14, -70) * k, base + Vector2(0, -42) * k, Color("c8c2b0"), 1.0)
		var spiral := PackedVector2Array()
		for i in 22:
			var a: float = i / 21.0 * 2.0 * TAU
			spiral.append(base + Vector2(0, -36) * k + Vector2(cos(a), sin(a)) * 8.0 * k * (i / 21.0))
		draw_polyline(spiral, GLOW, 2.0)
