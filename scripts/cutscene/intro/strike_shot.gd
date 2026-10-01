extends IntroShot
## Plan 9 — plan extérieur, rapide : la foudre frappe l'antenne du laboratoire ;
## l'énergie descend le long des câbles vers le sous-sol (des éclats verts qui
## filent), et les fenêtres flambent de vert.

## Chemin du câble : de l'antenne jusque sous le sol (coordonnées du plan).
## (Le bâtiment est dessiné à l'échelle 1,6 depuis (330, 520) : l'antenne est en (800, 101).)
const CABLE: Array[Vector2] = [Vector2(800, 101), Vector2(800, 200), Vector2(846, 212), Vector2(846, 512),
		Vector2(790, 560), Vector2(790, 720)]


func _draw() -> void:
	var strike: float = phase(0.08, 0.14)  # l'instant de l'impact
	var light: float = maxf(flash, 0.0)
	vertical_gradient(0.0, H, Color("070b12").lerp(Color("c9d6e6"), light * 0.8), Color("141c27").lerp(Color("e6eef7"), light))
	tex_poly([Vector2(0, 520), Vector2(W, 500), Vector2(W, H), Vector2(0, H)], Color("0c1118").lerp(Color("4a5666"), light * 0.7), CONCRETE)
	# Le bâtiment, plus grand (on est plus près) ; fenêtres vertes après l'impact.
	var windows: Color = Color("e8d9a6").lerp(GLOW, clampf(progress * 3.0 - 0.3, 0.0, 1.0))
	draw_lab(Vector2(330.0, 520.0), 1.6, windows, light)
	if strike > 0.0 and progress < 0.5:
		draw_bolt(Vector2(760.0, -20.0), CABLE[0], 3, Color(0.95, 1.0, 1.0, 1.0 - phase(0.14, 0.5)), 5.0)
	# Le câble, puis des éclats d'énergie qui le parcourent vers le bas.
	var path := PackedVector2Array(CABLE)
	draw_polyline(path, Color("1a2230").lerp(Color("aebdd0"), light), 4.0)
	if strike > 0.0:
		for k in 5:
			var u: float = fposmod(phase(0.12, 1.0) * 2.2 - k * 0.18, 1.0) if progress > 0.12 else 0.0
			var p: Vector2 = _along(u)
			draw_circle(p, 14.0, Color(GLOW, 0.25))
			draw_circle(p, 6.0, Color(0.9, 1.0, 0.95))
	draw_rain(150, Color(0.7, 0.8, 0.95, 0.22 + 0.3 * light))


## Point du câble à la fraction « u » de sa longueur (0 = antenne, 1 = sous-sol).
func _along(u: float) -> Vector2:
	var total: float = 0.0
	for i in range(1, CABLE.size()):
		total += CABLE[i - 1].distance_to(CABLE[i])
	var target: float = u * total
	for i in range(1, CABLE.size()):
		var seg: float = CABLE[i - 1].distance_to(CABLE[i])
		if target <= seg:
			return CABLE[i - 1].lerp(CABLE[i], target / maxf(seg, 0.001))
		target -= seg
	return CABLE[-1]
