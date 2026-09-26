extends IntroShot
## Plan 10 — très gros plan : les yeux d'Élias se lèvent vers le portail. Un
## reflet vert grandit dans ses yeux. Le son vient d'être coupé net : silence total.

const SKIN: Color = Color("c99479")
const SKIN_DARK: Color = Color("a8775f")


func _draw() -> void:
	fill(SKIN_DARK)
	# Front et pommettes : bandes de peau plus claires ; léger tremblement.
	var shake := Vector2(sin(time * 31.0), cos(time * 27.0)) * 1.5
	draw_set_transform(shake)
	poly([Vector2(-20, 90), Vector2(W + 20, 90), Vector2(W + 20, 250), Vector2(-20, 280)], SKIN)
	poly([Vector2(-20, 470), Vector2(W + 20, 460), Vector2(W + 20, H), Vector2(-20, H)], SKIN)
	var look: float = ease_in_out(phase(0.1, 0.6))  # le regard monte
	var glow: float = ease_in_out(phase(0.3, 1.0))
	for cx: float in [410.0, 870.0]:
		_draw_eye(Vector2(cx, 370.0), look, glow)
	# Sourcils : ils se lèvent un peu avec le regard.
	for side: float in [-1.0, 1.0]:  # gauche, droite (symétriques)
		var cx: float = 640.0 + side * 230.0
		var inner: float = 250.0 - 24.0 * look  # le côté du nez se lève plus
		var outer: float = 236.0 - 12.0 * look
		poly([Vector2(cx - side * 150, inner), Vector2(cx + side * 165, outer), Vector2(cx + side * 160, outer + 20),
				Vector2(cx - side * 145, inner + 22)], Color("2b2020"))
	# Le vert du portail éclaire le visage.
	fill(Color(GLOW, 0.12 * glow))
	draw_set_transform(Vector2.ZERO)


func _draw_eye(center: Vector2, look: float, glow: float) -> void:
	# Blanc de l'œil (amande), iris, pupille, reflet vert, paupière supérieure.
	var almond := PackedVector2Array()
	for i in 24:
		var a: float = i / 24.0 * TAU
		almond.append(center + Vector2(cos(a) * 150.0, sin(a) * (62.0 if sin(a) < 0.0 else 50.0)))
	draw_colored_polygon(almond, Color("e9e2da"))
	var iris_c: Vector2 = center + Vector2(0.0, 10.0 - 34.0 * look)
	draw_circle(iris_c, 48.0, Color("4a3426"))
	draw_circle(iris_c, 48.0, Color(GLOW, 0.55 * glow))
	draw_circle(iris_c, 20.0 + 4.0 * glow, Color("0b0908"))
	draw_circle(iris_c + Vector2(-14.0, -14.0), 7.0 + 5.0 * glow, Color(GLOW.lerp(Color.WHITE, 0.5), 0.5 + 0.5 * glow))
	# Paupière : couvre le haut de l'œil (moins quand le regard monte).
	var lid: float = lerpf(26.0, 8.0, look)
	poly([center + Vector2(-160, -70), center + Vector2(160, -70), center + Vector2(152, -62 + lid),
			center + Vector2(0, -56 + lid), center + Vector2(-152, -60 + lid)], SKIN_DARK)
	draw_polyline(PackedVector2Array([center + Vector2(-150, -58 + lid), center + Vector2(0, -54 + lid), center + Vector2(150, -60 + lid)]),
			Color("2b1d18"), 4.0)
