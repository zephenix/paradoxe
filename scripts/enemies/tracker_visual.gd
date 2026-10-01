class_name TrackerVisual
extends Node2D
## Dessin du Traqueur (refait après la v0.8 : « dessin de maternelle »). Une bête
## de chasse basse et musclée, entre le grand félin et le reptile :
##   - un corps aux courbes lisses (poitrail profond, taille creusée, croupe) ;
##   - des pattes de coureur en trois segments, griffues ;
##   - une peau écailleuse, avec relief (les lampes l'accrochent) ;
##   - des épines courbes le long du dos, plus longues au garrot ;
##   - des rayures ambrées qui luisent (pas le vert du portail : il n'est pas « de
##     la famille ») et un œil rouge sous une arcade.
## Trois animations calculées à chaque image : idle (il respire), run (galop : le
## dos ondule, les pattes travaillent par paires), roar (il se cabre, gueule ouverte).
## L'origine est au sol, au milieu du corps. Tourné vers la droite par défaut.
##
## Comment sont faites les pattes : chaque segment a un angle (0 = vers le bas,
## positif = vers l'avant) ; on part de la hanche et on ajoute les segments bout à
## bout (« cinématique directe », comme un bras articulé qu'on déplie). Animer une
## patte, c'est faire varier ces angles avec des sinus décalés.

const HIDE: Color = Color("1e1a16")
const HIDE_LIGHT: Color = Color("3a322a")
const BELLY: Color = Color("15120f")
const SPINE: Color = Color("120f0d")
const CLAW: Color = Color("cfc6b0")
const MARK: Color = Color("ff9a3c")
const EYE: Color = Color("ff3b2f")
const OUTLINE: Color = Color(0.03, 0.025, 0.02, 0.85)
const SKIN: SurfaceStyle = preload("res://resources/art/surfaces/scales.tres")
## Vitesse du galop (radians par seconde) et amplitude du roulis du dos.
const GALLOP: float = 18.0

var current: StringName = &"idle"
var facing: int = 1
var _time: float = 0.0

# Valeurs de l'image en cours (calculées au début de _draw).
var _bob: float = 0.0
var _rear: float = 0.0
var _roar: float = 0.0
var _run: bool = false


func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED


func play(animation: StringName) -> void:
	if animation != current:
		current = animation
		_time = 0.0


func set_facing(direction: int) -> void:
	facing = 1 if direction >= 0 else -1
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(facing, 1.0))
	_run = current == &"run"
	_roar = clampf(_time / 0.35, 0.0, 1.0) if current == &"roar" else 0.0
	_bob = sin(_time * GALLOP * 2.0) * 4.0 if _run else sin(_time * 2.2) * 1.5
	_rear = -22.0 * _roar
	# De l'arrière-plan vers le premier plan : pattes du fond, queue, corps,
	# épines, rayures, pattes de devant, cou et tête.
	_draw_hind_leg(true)
	_draw_front_leg(true)
	_draw_tail()
	_draw_body()
	_draw_spines()
	_draw_stripes()
	_draw_hind_leg(false)
	_draw_front_leg(false)
	_draw_head()
	draw_set_transform(Vector2.ZERO)


# --------------------------------------------------------------------------
# Les parties du corps
# --------------------------------------------------------------------------

## Décalage vertical d'un point du corps : la respiration (ou le galop), et le
## cabrage, plus fort à l'avant.
func _lift(point: Vector2) -> Vector2:
	return point + Vector2(0.0, _bob + _rear * clampf((point.x + 40.0) / 120.0, 0.0, 1.0))


func _body_outline() -> PackedVector2Array:
	# Points de contrôle (vers la droite) : dos, garrot, cou ; poitrail ; ventre
	# creusé ; croupe. La courbe lisse passe par eux (spline de Catmull-Rom).
	var flex: float = sin(_time * GALLOP) * 4.0 if _run else 0.0  # le dos ondule au galop
	var keys: Array[Vector2] = [Vector2(-84, -60), Vector2(-60, -74 - flex), Vector2(-20, -70 + flex), Vector2(22, -76 - flex),
			Vector2(52, -86), Vector2(70, -74), Vector2(62, -52), Vector2(44, -36), Vector2(20, -34),
			Vector2(-8, -44 + flex), Vector2(-40, -46), Vector2(-66, -42), Vector2(-86, -50)]
	var points: Array[Vector2] = []
	for key in keys:
		points.append(_lift(key))
	return _closed_spline(points, 5)


func _draw_body() -> void:
	var outline: PackedVector2Array = _body_outline()
	_fill(outline, HIDE_LIGHT, BELLY)
	# Liseré clair sur le dos (le ciel s'y reflète) : la moitié haute du contour.
	var ridge := PackedVector2Array()
	for i in range(0, 30):
		ridge.append(outline[i] + Vector2(0, 1.5))
	draw_polyline(ridge, Color(0.55, 0.5, 0.45, 0.35), 1.5)
	# Muscle de l'épaule et de la cuisse : deux ombres douces.
	draw_circle(_lift(Vector2(42, -56)), 16.0, Color(0, 0, 0, 0.18))
	draw_circle(_lift(Vector2(-58, -56)), 18.0, Color(0, 0, 0, 0.18))


func _draw_tail() -> void:
	var centers := PackedVector2Array()
	var widths: Array[float] = []
	var swish: float = 1.0 if _run else 0.4
	for i in 9:
		var u: float = i / 8.0
		var wave: float = sin(_time * 5.0 - u * 3.0) * 12.0 * u * swish
		centers.append(_lift(Vector2(-80.0 - u * 105.0, -58.0 + u * 22.0 + wave)) - Vector2(0, _rear * clampf((-80.0 - u * 105.0 + 40.0) / 120.0, 0.0, 1.0)))
		widths.append(lerpf(20.0, 3.0, u))
	for i in centers.size() - 1:
		_segment(centers[i], centers[i + 1], widths[i], widths[i + 1], HIDE, BELLY)
	# Épines de la queue, de plus en plus petites.
	for i in range(1, 7):
		var base: Vector2 = centers[i] + Vector2(0, -widths[i] * 0.45)
		_spine(base, 9.0 - i * 1.1, -0.9)


func _draw_spines() -> void:
	# Le long de la ligne du dos, de la croupe au cou ; plus longues au garrot.
	for i in 11:
		var x: float = -70.0 + i * 12.0
		var top: Vector2 = _top_at(x)
		var length: float = 10.0 + 12.0 * exp(-pow((x - 20.0) / 35.0, 2.0))
		_spine(top + Vector2(0, 3), length, -0.55 - 0.2 * float(i % 2))


func _draw_stripes() -> void:
	# Rayures ambrées sur le flanc, en arc ; elles luisent et « respirent ».
	var glow: float = 0.65 + 0.35 * sin(_time * 3.0)
	for i in 5:
		var x: float = -58.0 + i * 22.0
		var top: Vector2 = _top_at(x) + Vector2(0, 10)
		var stripe := PackedVector2Array([top, top + Vector2(-4, 9), top + Vector2(-2, 18), top + Vector2(-6, 25)])
		draw_polyline(stripe, Color(MARK, 0.18 * glow), 7.0)
		draw_polyline(stripe, Color(MARK, 0.85 * glow), 2.0)


## Patte arrière (« digitigrade » : le talon est haut, l'animal marche sur ses
## doigts) : cuisse, jambe, métatarse, doigts griffus.
func _draw_hind_leg(far: bool) -> void:
	var phase: float = _time * GALLOP + (0.7 if far else 0.0)
	var swing: float = sin(phase) if _run else 0.0
	var hip: Vector2 = _lift(Vector2(-56.0 + (4.0 if far else 0.0), -60.0))
	var angles: Array[float] = [deg_to_rad(28.0 + 38.0 * swing), deg_to_rad(-48.0 - 24.0 * sin(phase + 1.3) * (1.0 if _run else 0.0)),
			deg_to_rad(12.0 + 30.0 * sin(phase + 2.2) * (1.0 if _run else 0.0))]
	var lengths: Array[float] = [28.0, 26.0, 19.0]
	var widths: Array[float] = [24.0, 12.0, 8.0, 6.0]
	_draw_limb(hip, angles, lengths, widths, far)


## Patte avant : bras, avant-bras, main griffue.
func _draw_front_leg(far: bool) -> void:
	var phase: float = _time * GALLOP + PI * 0.85 + (0.7 if far else 0.0)
	var run: float = 1.0 if _run else 0.0
	var lift: float = _roar * 0.9  # en se cabrant, il replie les pattes avant
	var shoulder: Vector2 = _lift(Vector2(42.0 + (4.0 if far else 0.0), -58.0))
	var angles: Array[float] = [deg_to_rad(-18.0 + 34.0 * sin(phase) * run - 40.0 * lift),
			deg_to_rad(12.0 + 30.0 * sin(phase + 1.1) * run + 70.0 * lift), deg_to_rad(42.0 + 20.0 * sin(phase + 1.8) * run)]
	var lengths: Array[float] = [24.0, 25.0, 11.0]
	var widths: Array[float] = [18.0, 10.0, 7.0, 5.0]
	_draw_limb(shoulder, angles, lengths, widths, far)


## Une patte : des segments bout à bout, une rotule ronde à chaque articulation,
## trois griffes au bout. Les pattes du fond sont plus sombres.
func _draw_limb(root: Vector2, angles: Array[float], lengths: Array[float], widths: Array[float], far: bool) -> void:
	var top: Color = HIDE.darkened(0.35) if far else HIDE_LIGHT
	var bottom: Color = BELLY.darkened(0.3) if far else BELLY
	# Hanche (ou épaule) arrondie : la cuisse se fond dans le corps.
	draw_circle(root, widths[0] * 0.5, top.lerp(bottom, 0.3))
	var joint: Vector2 = root
	var direction: float = 0.0
	for i in angles.size():
		direction = angles[i]
		var next: Vector2 = joint + Vector2(sin(direction), cos(direction)) * lengths[i]
		_segment(joint, next, widths[i], widths[i + 1], top, bottom)
		if i > 0:
			draw_circle(joint, widths[i] * 0.5, top.lerp(bottom, 0.5))
		joint = next
	for k in 3:  # griffes
		var claw_dir: float = direction + deg_to_rad(70.0 + k * 18.0)
		var tip: Vector2 = joint + Vector2(sin(claw_dir), cos(claw_dir)) * 7.0
		draw_colored_polygon(PackedVector2Array([joint + Vector2(0, -1.5), tip, joint + Vector2(0, 1.5)]), CLAW.darkened(0.35 if far else 0.0))


func _draw_head() -> void:
	var neck_base: Vector2 = _lift(Vector2(58, -70))
	# En rugissant, le cou pivote vers le haut (sa longueur ne change pas).
	var head: Vector2 = neck_base + Vector2(36, -8).rotated(-0.75 * _roar)
	# Cou : épais et musclé.
	_segment(neck_base, head, 30.0, 20.0, HIDE_LIGHT, BELLY)
	# Mâchoire (dessous) : elle s'ouvre en rugissant, un peu en courant.
	var open: float = 26.0 * _roar + (5.0 * absf(sin(_time * 9.0)) if _run else 0.0)
	var jaw_angle: float = deg_to_rad(open)
	var jaw := PackedVector2Array()
	for point: Vector2 in [Vector2(-6, 2), Vector2(40, 4), Vector2(46, 8), Vector2(36, 12), Vector2(-2, 12)]:
		jaw.append(head + point.rotated(jaw_angle))
	# Intérieur de la gueule, puis les dents du bas.
	var mouth := PackedVector2Array([head + Vector2(-4, 3), head + Vector2(44, 0), jaw[1], jaw[0]])
	if open > 3.0 and not Geometry2D.triangulate_polygon(mouth).is_empty():
		draw_colored_polygon(mouth, Color("3a0f0c"))
	_fill(jaw, HIDE, BELLY)
	for k in 5:
		var base: Vector2 = head + Vector2(8 + k * 7, 4).rotated(jaw_angle)
		draw_colored_polygon(PackedVector2Array([base, base + Vector2(2, -5).rotated(jaw_angle), base + Vector2(4, 0).rotated(jaw_angle)]), CLAW)
	# Crâne : long museau, arcade au-dessus de l'œil, nuque en pointe.
	var skull := PackedVector2Array()
	for point: Vector2 in [Vector2(-10, -4), Vector2(-4, -15), Vector2(14, -18), Vector2(22, -14), Vector2(40, -9),
			Vector2(54, -4), Vector2(55, 1), Vector2(40, 4), Vector2(-6, 6)]:
		skull.append(head + point)
	_fill(skull, HIDE_LIGHT.lightened(0.08), HIDE)
	for k in 5:  # dents du haut
		var base: Vector2 = head + Vector2(12 + k * 8, 3)
		draw_colored_polygon(PackedVector2Array([base, base + Vector2(2, 6), base + Vector2(4, 0)]), CLAW)
	draw_line(head + Vector2(48, -4), head + Vector2(51, -3), Color(0, 0, 0, 0.8), 1.5)  # narine
	# Œil : une fente rouge sous l'arcade, avec un halo.
	var eye: Vector2 = head + Vector2(18, -9)
	draw_circle(eye, 9.0, Color(EYE, 0.18))
	draw_colored_polygon(PackedVector2Array([eye + Vector2(-4, 0), eye + Vector2(0, -2.2), eye + Vector2(4, 0), eye + Vector2(0, 2)]), EYE)
	draw_line(eye + Vector2(-6, -4), eye + Vector2(6, -6), Color(0, 0, 0, 0.7), 2.0)  # arcade
	# Collerette d'épines derrière le crâne.
	for k in 3:
		_spine(head + Vector2(-6 + k * 5, -13), 14.0 - k * 3.0, -1.1)


# --------------------------------------------------------------------------
# Outils de dessin
# --------------------------------------------------------------------------

## Point haut du corps à l'abscisse x (sur la ligne du dos).
func _top_at(x: float) -> Vector2:
	var outline: PackedVector2Array = _body_outline()
	var best := Vector2(x, 0.0)
	var best_y: float = INF
	for point in outline:
		if absf(point.x - x) < 4.0 and point.y < best_y:
			best_y = point.y
			best = point
	return best


## Épine courbe : une griffe recourbée vers l'arrière (lean < 0), foncée à la
## base, plus claire à la pointe.
func _spine(base: Vector2, length: float, lean: float) -> void:
	var tip: Vector2 = base + Vector2(sin(lean), -cos(lean)) * length
	var bend: Vector2 = base.lerp(tip, 0.5) + Vector2(cos(lean), sin(lean)) * length * 0.18
	# Ordre des points : base, pointe, courbure, base (dans cet ordre, la forme
	# ne se croise jamais elle-même).
	draw_polygon(PackedVector2Array([base + Vector2(-3, 0), tip, bend, base + Vector2(3, 0)]),
			PackedColorArray([SPINE, HIDE_LIGHT.lightened(0.15), SPINE, SPINE]))


## Segment de membre : un quadrilatère d'épaisseur « wa » en a et « wb » en b
## (toujours convexe : pas de risque de forme impossible à remplir).
func _segment(a: Vector2, b: Vector2, wa: float, wb: float, top: Color, bottom: Color) -> void:
	var normal: Vector2 = (b - a).orthogonal().normalized()
	if normal == Vector2.ZERO:
		return
	# Sans contour : les segments d'une même patte (ou de la queue) se fondent.
	_fill(PackedVector2Array([a + normal * wa * 0.5, b + normal * wb * 0.5, b - normal * wb * 0.5, a - normal * wa * 0.5]), top, bottom, false)


## Remplit une forme : peau écailleuse (texture et relief), plus claire en haut
## et plus sombre en bas, avec un contour fin.
func _fill(points: PackedVector2Array, top: Color, bottom: Color, outlined: bool = true) -> void:
	var y_min: float = INF
	var y_max: float = -INF
	for point in points:
		y_min = minf(y_min, point.y)
		y_max = maxf(y_max, point.y)
	if Geometry2D.triangulate_polygon(points).is_empty():
		return  # forme dégénérée (pattes repliées à l'extrême…) : on ne la dessine pas
	var colors := PackedColorArray()
	for point in points:
		colors.append(top.lerp(bottom, (point.y - y_min) / maxf(y_max - y_min, 1.0)) * 1.25)
	draw_polygon(points, colors, SKIN.draw_uvs_for(points), SKIN.canvas_texture())
	if not outlined:
		return
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, OUTLINE, 1.2)


## Courbe fermée et lisse passant par des points (spline de Catmull-Rom) : entre
## deux points, « steps » points intermédiaires, guidés par les voisins.
static func _closed_spline(points: Array[Vector2], steps: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n: int = points.size()
	for i in n:
		var p0: Vector2 = points[(i - 1 + n) % n]
		var p1: Vector2 = points[i]
		var p2: Vector2 = points[(i + 1) % n]
		var p3: Vector2 = points[(i + 2) % n]
		for s in steps:
			var t: float = float(s) / steps
			var t2: float = t * t
			var t3: float = t2 * t
			out.append(0.5 * ((2.0 * p1) + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (3.0 * p1 - p0 - 3.0 * p2 + p3) * t3))
	return out
