extends IntroShot
## Plan 2 — plan d'ensemble : un complexe de recherche isolé sur une falaise,
## nuit d'orage. Un éclair révèle la silhouette du bâtiment. La caméra avance
## très lentement (léger zoom).

const SKY_TOP: Color = Color("070b12")
const SKY_LOW: Color = Color("18222f")
const SKY_FLASH: Color = Color("9fb3cc")


func _draw() -> void:
	# Lent travelling avant : on agrandit tout autour du bâtiment.
	var zoom: float = 1.0 + 0.07 * ease_in_out(progress)
	var pivot := Vector2(900.0, 420.0)
	draw_set_transform(pivot * (1.0 - zoom), 0.0, Vector2(zoom, zoom))
	vertical_gradient(-40.0, H + 40.0, SKY_TOP.lerp(SKY_FLASH, flash * 0.8), SKY_LOW.lerp(SKY_FLASH, flash))
	# Nuages bas, découpés en silhouette par l'éclair.
	var cloud: Color = Color("0b1018").lerp(Color("3b4a5e"), flash)
	for i in 14:  # des « bouffées » de tailles et de hauteurs variées, qui dérivent
		var cx: float = fposmod(-120.0 + i * 113.0 + time * (6.0 + i % 3), W + 240.0) - 120.0
		var cy: float = 90.0 + 55.0 * sin(i * 1.7) + 25.0 * (i % 3)
		var r: float = 70.0 + 45.0 * fposmod(i * 0.618, 1.0)
		draw_circle(Vector2(cx, cy), r, cloud)
		draw_circle(Vector2(cx + r * 0.7, cy + 12.0), r * 0.7, cloud.darkened(0.1))
	if flash > 0.35:
		draw_bolt(Vector2(520.0, 60.0), Vector2(430.0, 520.0), 7, Color(0.9, 0.95, 1.0, flash))
	# Mer au loin, puis la falaise.
	poly([Vector2(0, 560), Vector2(W, 540), Vector2(W, H + 40), Vector2(0, H + 40)], Color("05080d").lerp(Color("283444"), flash * 0.6))
	var rock: Color = Color("06090e").lerp(Color("3a4553"), flash * 0.7)
	tex_poly([Vector2(-40, H + 40), Vector2(-40, 600), Vector2(260, 585), Vector2(520, 500), Vector2(680, 440),
			Vector2(1010, 430), Vector2(1320, 455), Vector2(1320, H + 40)], rock.lightened(0.12), CONCRETE)
	draw_polyline(PackedVector2Array([Vector2(520, 500), Vector2(680, 440), Vector2(1010, 430), Vector2(1320, 455)]),
			Color("1a222c").lerp(Color("aebdd0"), flash), 2.0)
	draw_lab(Vector2(760.0, 433.0), 1.0, Color("e8d9a6").lerp(Color.WHITE, flash * 0.3), flash)
	draw_rain(170, Color(0.7, 0.8, 0.95, 0.22 + 0.25 * flash))
	draw_set_transform(Vector2.ZERO)
