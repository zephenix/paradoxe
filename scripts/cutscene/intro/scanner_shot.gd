extends IntroShot
## Plan 4 — gros plan : la main d'Élias se pose sur un lecteur biométrique ; une
## ligne de lecture balaie la paume, le voyant passe du rouge au vert, et le sas
## s'ouvre (la fente de lumière à gauche).

const READER := Rect2(600.0, 170.0, 300.0, 380.0)
const SKIN: Color = Color("d6a387")
const SLEEVE: Color = Color("b9c6cc")


func _draw() -> void:
	fill(Color("1e242c"))
	tex_poly([Vector2(0, 0), Vector2(W, 0), Vector2(W, H), Vector2(0, H)], Color("2a323c"), METAL)
	# Panneaux du mur, joints.
	for i in 6:
		draw_line(Vector2(i * 240.0, 0), Vector2(i * 240.0 - 40.0, H), Color("141920"), 3.0)
	draw_line(Vector2(0, 600), Vector2(W, 590), Color("141920"), 3.0)
	# Sas qui s'ouvre : une fente de lumière qui s'élargit à gauche.
	var gap: float = 160.0 * ease_in_out(phase(0.72, 1.0))
	if gap > 0.5:
		draw_rect(Rect2(260.0 - gap * 0.5, 0.0, gap, H), Color("cfe3da"))
	draw_line(Vector2(260, 0), Vector2(260, H), Color("0d1116"), 4.0)
	LabSign.draw_logo(self, Vector2(750.0, 118.0), 18.0, Color("8a99a1"), 4.0)  # le logo du labo
	# Le lecteur : cadre, grille, voyant.
	draw_rect(READER.grow(14.0), Color("2f3844"))
	draw_rect(READER, Color("0c1a1a"))
	var accepted: bool = progress >= 0.55
	var grid: Color = Color(GLOW, 0.5 if accepted else 0.18)
	for i in range(1, 8):
		draw_line(READER.position + Vector2(0, i * READER.size.y / 8.0), READER.position + Vector2(READER.size.x, i * READER.size.y / 8.0), grid, 1.0)
	for i in range(1, 6):
		draw_line(READER.position + Vector2(i * READER.size.x / 6.0, 0), READER.position + Vector2(i * READER.size.x / 6.0, READER.size.y), grid, 1.0)
	draw_circle(Vector2(750.0, 600.0), 10.0, GLOW if accepted else Color(1.0, 0.25, 0.2))
	draw_circle(Vector2(750.0, 600.0), 22.0, Color(GLOW if accepted else Color(1.0, 0.25, 0.2), 0.2))
	# La main : elle arrive d'en bas à gauche, se pose (0,25 à 0,7), repart.
	var arrive: float = ease_in_out(phase(0.0, 0.25))
	var leave: float = ease_in_out(phase(0.72, 0.95))
	var palm := Vector2(lerpf(260.0, 750.0, arrive) - 420.0 * leave, lerpf(820.0, 380.0, arrive) + 420.0 * leave)
	_draw_hand(palm)
	# Ligne de lecture qui balaie la paume.
	var scan: float = phase(0.28, 0.55)
	if scan > 0.0 and scan < 1.0:
		var y: float = READER.position.y + READER.size.y * scan
		draw_line(Vector2(READER.position.x, y), Vector2(READER.end.x, y), Color(GLOW, 0.9), 3.0)
		draw_rect(Rect2(READER.position.x, y - 14.0, READER.size.x, 14.0), Color(GLOW, 0.12))


## Main ouverte, paume contre le lecteur (vue de dos) : manche, dos de la main,
## quatre doigts, pouce. Chaque partie est modelée (côté gauche éclairé, droit
## dans l'ombre) ; ongles, phalanges et tendons donnent le détail.
func _draw_hand(center: Vector2) -> void:
	var lit: Color = SKIN.lightened(0.12)
	var shadow: Color = SKIN.darkened(0.25)
	# Manche de la blouse, avec ses plis.
	shade_poly([center + Vector2(-60, 60), center + Vector2(-70, 260), center + Vector2(70, 260), center + Vector2(64, 50)],
			SLEEVE.lightened(0.1), SLEEVE.darkened(0.25), Vector2.RIGHT)
	draw_line(center + Vector2(-66, 150), center + Vector2(68, 150), Color("8a99a1"), 3.0)
	for k in 3:
		draw_line(center + Vector2(-40 + k * 30, 70), center + Vector2(-48 + k * 34, 140), Color(SLEEVE.darkened(0.3), 0.5), 2.0)
	# Dos de la main.
	shade_poly([center + Vector2(-62, -60), center + Vector2(62, -60), center + Vector2(66, 60), center + Vector2(-58, 66)], lit, shadow, Vector2.RIGHT)
	for k in 4:  # tendons, vers chaque doigt
		var x: float = -38.0 + k * 34.0
		draw_line(center + Vector2(x * 0.6, 40), center + Vector2(x, -52), Color(shadow, 0.35), 3.0)
	# Doigts : modelés, un pli à chaque phalange, l'ongle au bout.
	for i in 4:
		var x: float = -52.0 + i * 34.0
		var length: float = [118.0, 136.0, 128.0, 100.0][i]
		var finger: Array = [center + Vector2(x, -54), center + Vector2(x + 2, -54 - length), center + Vector2(x + 26, -56 - length),
				center + Vector2(x + 28, -56)]
		shade_poly(finger, lit, shadow, Vector2.RIGHT)
		draw_circle(center + Vector2(x + 14, -55 - length), 13.0, lit.lerp(shadow, 0.4))  # bout arrondi
		draw_circle(center + Vector2(x + 14, -60), 12.0, Color(shadow, 0.35))  # jointure
		for joint: float in [0.38, 0.68]:
			var y: float = -56.0 - length * joint
			draw_arc(center + Vector2(x + 14, y), 9.0, PI * 0.15, PI * 0.85, 6, Color(shadow.darkened(0.2), 0.6), 1.5)
		draw_rect(Rect2(center + Vector2(x + 6, -54 - length), Vector2(16, 22)), Color("e9c3ae"))  # ongle
		draw_rect(Rect2(center + Vector2(x + 6, -54 - length), Vector2(16, 5)), Color("f3dccd"))
		if i < 3:  # creux entre deux doigts
			draw_line(center + Vector2(x + 28, -56), center + Vector2(x + 30, -56 - length * 0.6), Color(shadow.darkened(0.3), 0.7), 2.0)
	# Pouce.
	shade_poly([center + Vector2(-58, 20), center + Vector2(-120, -40), center + Vector2(-104, -60), center + Vector2(-50, -10)], lit, shadow, Vector2.DOWN)
	draw_circle(center + Vector2(-112, -50), 12.0, lit.lerp(shadow, 0.3))
