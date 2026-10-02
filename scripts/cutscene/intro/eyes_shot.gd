extends IntroShot
## Plan 10 — très gros plan : les yeux d'Élias se lèvent vers le portail. Un
## reflet vert grandit dans ses yeux. Le son vient d'être coupé net : silence total.
##
## Redessiné après la v0.8 (essai graphique) : la peau est modelée par des
## dégradés (front éclairé, orbites dans l'ombre, arête du nez), les yeux ont
## deux paupières avec leur pli, des cils, un iris strié avec son anneau sombre, un
## reflet blanc, et les sourcils sont faits de poils.

const SKIN: Color = Color("cf9a7e")
const SKIN_LIGHT: Color = Color("e0b195")
const SKIN_SHADOW: Color = Color("8d5f4b")
const HAIR: Color = Color("2b2020")
const IRIS: Color = Color("5a4030")
const EYE_Y: float = 370.0


func _draw() -> void:
	var shake := Vector2(sin(time * 31.0), cos(time * 27.0)) * 1.5 * Settings.shake_factor()  # léger tremblement
	draw_set_transform(shake)
	var look: float = ease_in_out(phase(0.1, 0.6))  # le regard monte
	var glow: float = ease_in_out(phase(0.3, 1.0))
	_draw_skin()
	for side: float in [-1.0, 1.0]:
		_draw_socket(Vector2(640.0 + side * 230.0, EYE_Y))
	for side: float in [-1.0, 1.0]:
		_draw_eye(Vector2(640.0 + side * 230.0, EYE_Y), side, look, glow)
		_draw_brow(side, look)
	# Le vert du portail éclaire le visage, d'en haut (là où il regarde).
	shade_poly([Vector2(-20, -20), Vector2(W + 20, -20), Vector2(W + 20, H + 20), Vector2(-20, H + 20)],
			Color(GLOW, 0.2 * glow), Color(GLOW, 0.02 * glow))
	draw_set_transform(Vector2.ZERO)


## La peau : un dégradé du front (éclairé) aux joues ; l'arête du nez au milieu,
## plus claire, avec ses deux flancs dans l'ombre.
func _draw_skin() -> void:
	shade_poly([Vector2(-20, -20), Vector2(W + 20, -20), Vector2(W + 20, H + 20), Vector2(-20, H + 20)], SKIN_LIGHT, SKIN.darkened(0.12))
	# Arête du nez : pas de contour net, deux ombres douces de part et d'autre,
	# qui s'effacent vers l'extérieur, et un reflet clair au milieu.
	shade_poly([Vector2(540, 340), Vector2(605, 300), Vector2(590, H + 20), Vector2(470, H + 20)],
			Color(SKIN_SHADOW, 0.0), Color(SKIN_SHADOW, 0.3), Vector2.RIGHT)
	shade_poly([Vector2(675, 300), Vector2(740, 340), Vector2(810, H + 20), Vector2(690, H + 20)],
			Color(SKIN_SHADOW, 0.3), Color(SKIN_SHADOW, 0.0), Vector2.RIGHT)
	shade_poly([Vector2(625, 310), Vector2(655, 310), Vector2(672, H + 20), Vector2(608, H + 20)],
			Color(SKIN_LIGHT.lightened(0.1), 0.0), Color(SKIN_LIGHT.lightened(0.1), 0.5))
	# Grain de peau : de minuscules taches, toujours aux mêmes endroits.
	for i in 220:
		var p := Vector2(fposmod(i * 211.7, W), fposmod(i * 97.3, H))
		draw_circle(p, 1.2, Color(SKIN_SHADOW, 0.12))


## L'orbite : une ombre douce autour de l'œil (sous l'arcade surtout).
func _draw_socket(center: Vector2) -> void:
	for i in 5:
		var k: float = 1.0 - i * 0.14
		var socket := PackedVector2Array()
		for j in 28:
			var a: float = j / 28.0 * TAU
			socket.append(center + Vector2(cos(a) * 205.0 * k, sin(a) * (120.0 if sin(a) < 0.0 else 95.0) * k - 12.0))
		draw_colored_polygon(socket, Color(SKIN_SHADOW, 0.09))


func _draw_eye(center: Vector2, side: float, look: float, glow: float) -> void:
	# Blanc de l'œil (amande), plus sombre en haut (l'ombre de la paupière).
	var almond := PackedVector2Array()
	for i in 32:
		var a: float = i / 32.0 * TAU
		almond.append(center + Vector2(cos(a) * 150.0, sin(a) * (62.0 if sin(a) < 0.0 else 50.0)))
	var whites := PackedColorArray()
	for point in almond:
		whites.append(Color("cfc5bb").lerp(Color("f0e9e2"), clampf((point.y - center.y + 62.0) / 112.0, 0.0, 1.0)))
	draw_polygon(almond, whites)
	# Coin de l'œil, côté nez : la caroncule rosée.
	draw_circle(center + Vector2(-side * 138.0, 4.0), 9.0, Color("c98a80"))
	# Iris : anneau sombre au bord, fibres qui rayonnent, pupille, reflet.
	var iris_c: Vector2 = center + Vector2(0.0, 10.0 - 34.0 * look)
	draw_circle(iris_c, 50.0, IRIS.darkened(0.5))
	draw_circle(iris_c, 46.0, IRIS)
	for k in 48:
		var a: float = k / 48.0 * TAU
		var inner: float = 22.0 + 4.0 * glow
		draw_line(iris_c + Vector2.from_angle(a) * inner, iris_c + Vector2.from_angle(a + 0.05) * (40.0 + 5.0 * fposmod(k * 0.618, 1.0)),
				IRIS.lightened(0.25 + 0.2 * fposmod(k * 0.37, 1.0)), 1.5)
	draw_circle(iris_c, 46.0, Color(GLOW, 0.5 * glow))
	draw_circle(iris_c, 20.0 + 4.0 * glow, Color("0b0908"))
	draw_circle(iris_c + Vector2(-14.0, -16.0), 6.0, Color(1, 1, 1, 0.85))  # reflet de la pièce
	draw_circle(iris_c + Vector2(12.0, -10.0), 4.0 + 6.0 * glow, Color(GLOW.lerp(Color.WHITE, 0.5), 0.3 + 0.6 * glow))  # le portail
	# Paupière supérieure : elle couvre le haut de l'œil (moins quand le regard
	# monte), avec son pli au-dessus et ses cils.
	var lid: float = lerpf(26.0, 8.0, look)
	var lid_edge := PackedVector2Array()
	for i in 17:
		var u: float = i / 16.0
		lid_edge.append(center + Vector2(lerpf(-152.0, 152.0, u), -60.0 + lid + 6.0 * sin(u * PI) * -1.0 + 2.0 * (u - 0.5) * side))
	# La paupière : son haut est un arc qui se fond dans la peau (pas de coins).
	var lid_shape := PackedVector2Array()
	for i in 17:
		var u: float = i / 16.0
		lid_shape.append(center + Vector2(lerpf(-158.0, 158.0, u), -66.0 - 44.0 * sin(u * PI)))
	for i in range(lid_edge.size() - 1, -1, -1):
		lid_shape.append(lid_edge[i])
	var lid_colors := PackedColorArray()
	for point in lid_shape:
		var t: float = clampf((point.y - (center.y - 110.0)) / (50.0 + lid), 0.0, 1.0)
		lid_colors.append(Color(SKIN.darkened(0.04), 1.0).lerp(SKIN_SHADOW.lightened(0.12), t * t))
	draw_polygon(lid_shape, lid_colors)
	draw_polyline(lid_edge, Color("2b1d18"), 4.0)
	for i in 30:  # cils, plus longs vers l'extérieur
		var u: float = (i + 0.5) / 30.0
		var base: Vector2 = lid_edge[0].lerp(lid_edge[16], u) + Vector2(0, -2)
		var out: float = u if side > 0.0 else 1.0 - u
		draw_line(base, base + Vector2(side * (4.0 + 8.0 * out), -(8.0 + 10.0 * out)), Color("1e1514"), 2.0)
	# Pli de la paupière et paupière inférieure.
	draw_polyline(PackedVector2Array([center + Vector2(-140, -86 + lid * 0.4), center + Vector2(0, -98 + lid * 0.3),
			center + Vector2(140, -84 + lid * 0.4)]), Color(SKIN_SHADOW, 0.8), 3.0)
	draw_polyline(PackedVector2Array([center + Vector2(-148, 12), center + Vector2(-60, 48), center + Vector2(60, 50), center + Vector2(148, 10)]),
			Color(SKIN_SHADOW, 0.6), 3.0)
	draw_polyline(PackedVector2Array([center + Vector2(-120, 64), center + Vector2(0, 80), center + Vector2(120, 62)]),
			Color(SKIN_SHADOW, 0.3), 2.0)  # cerne


## Sourcil : des dizaines de poils inclinés vers l'extérieur ; il se lève un peu
## avec le regard (davantage côté nez).
func _draw_brow(side: float, look: float) -> void:
	var cx: float = 640.0 + side * 230.0
	var inner := Vector2(cx - side * 150.0, 252.0 - 24.0 * look)
	var outer := Vector2(cx + side * 165.0, 236.0 - 12.0 * look)
	# D'abord une bande sombre, fondue sur ses bords, qui donne la masse…
	var band := PackedVector2Array()
	var steps: int = 12
	for i in steps + 1:
		var u: float = float(i) / steps
		band.append(inner.lerp(outer, u) + Vector2(0, -14.0 - 10.0 * sin(u * PI) + 8.0 * u))
	for i in range(steps, -1, -1):
		var u: float = float(i) / steps
		band.append(inner.lerp(outer, u) + Vector2(0, 24.0 - 8.0 * sin(u * PI) - 12.0 * u))
	draw_colored_polygon(band, Color(HAIR, 0.55))
	# … puis les poils, inclinés vers l'extérieur, plus couchés au bout.
	for i in 260:
		var u: float = fposmod(i * 0.6180339, 1.0)
		var base: Vector2 = inner.lerp(outer, u) + Vector2(0, 22.0 - 34.0 * fposmod(i * 0.3819, 1.0) - 8.0 * sin(u * PI))
		var lean: float = lerpf(0.5, 1.2, u)
		draw_line(base, base + Vector2(side * sin(lean), -cos(lean)) * 14.0, Color(HAIR, 0.8), 2.0)
