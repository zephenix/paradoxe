class_name TrackerVisual
extends Node2D
## Dessin du Traqueur, tout en polygones : une bête basse et longue, dos hérissé
## d'épines, marques ambrées sur les flancs (pas le vert du portail : lui n'est pas
## « de la famille »), œil rouge. Trois animations calculées à chaque image :
##   idle : il respire ; run : galop (le corps ondule, les pattes balaient) ;
##   roar : il se cabre, tête levée, gueule ouverte.
## L'origine est au sol, au milieu du corps. Tourné vers la droite par défaut.

const HIDE: Color = Color("1a1714")
const HIDE_LIGHT: Color = Color("2c2620")
const MARK: Color = Color("ff9a3c")
const EYE: Color = Color("ff3b2f")

var current: StringName = &"idle"
var facing: int = 1
var _time: float = 0.0


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
	var run: bool = current == &"run"
	var roar: float = 0.0
	if current == &"roar":
		roar = clampf(_time / 0.35, 0.0, 1.0)
	var bob: float = sin(_time * 18.0) * 6.0 if run else sin(_time * 2.2) * 1.5
	var rear: float = -18.0 * roar  # se cabre
	# Pattes (celles du fond d'abord, plus sombres).
	for pair in 2:
		var hip_x: float = -55.0 if pair == 0 else 45.0
		for side in 2:
			var phase: float = _time * 18.0 + pair * PI + side * 0.9
			var swing: float = sin(phase) * 26.0 if run else 0.0
			var lift: float = maxf(0.0, cos(phase)) * 14.0 if run else 0.0
			var hip := Vector2(hip_x, -48.0 + bob * 0.5 + (rear if pair == 1 else 0.0))
			var knee := hip + Vector2(swing * 0.5 + (8.0 if pair == 1 else -6.0), 24.0)
			var foot := Vector2(hip_x + swing, -lift)
			var shade: Color = HIDE if side == 0 else HIDE_LIGHT
			draw_polyline(PackedVector2Array([hip, knee, foot]), shade.darkened(0.3 if side == 0 else 0.0), 11.0)
	# Queue qui ondule.
	var tail := PackedVector2Array()
	for i in 7:
		var u: float = i / 6.0
		tail.append(Vector2(-70.0 - u * 90.0, -58.0 + bob + u * 20.0 + sin(_time * 4.0 + u * 3.0) * 10.0 * u))
	draw_polyline(tail, HIDE, 12.0)
	# Corps.
	var body := PackedVector2Array([
		Vector2(-80, -60 + bob), Vector2(-40, -78 + bob), Vector2(20, -80 + bob + rear * 0.5),
		Vector2(70, -70 + bob + rear), Vector2(78, -46 + bob + rear), Vector2(40, -32 + bob),
		Vector2(-30, -30 + bob), Vector2(-78, -40 + bob)])
	draw_colored_polygon(body, HIDE_LIGHT)
	# Épines sur le dos.
	for i in 6:
		var x: float = -60.0 + i * 22.0
		var base_y: float = -76.0 + bob + (rear * 0.6 if x > 20.0 else 0.0)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 7, base_y + 4), Vector2(x + 4, base_y - 16 - (i % 2) * 6), Vector2(x + 9, base_y + 4)]), HIDE)
	# Marques ambrées sur le flanc (elles pulsent un peu).
	var glow: float = 0.6 + 0.4 * sin(_time * 3.0)
	for i in 5:
		var p := Vector2(-55.0 + i * 24.0, -52.0 + bob + sin(i * 1.3) * 5.0)
		draw_circle(p, 4.0, Color(MARK, glow))
		draw_circle(p, 9.0, Color(MARK, 0.15 * glow))
	# Tête et mâchoire (elle s'ouvre en rugissant).
	var neck := Vector2(70.0, -66.0 + bob + rear)
	var head_up: float = -26.0 * roar
	var skull := PackedVector2Array([neck + Vector2(-6, -8), neck + Vector2(34, -14 + head_up), neck + Vector2(66, -6 + head_up),
			neck + Vector2(62, 6 + head_up), neck + Vector2(10, 12)])
	draw_colored_polygon(skull, HIDE_LIGHT)
	var jaw_open: float = 22.0 * roar + (4.0 * absf(sin(_time * 9.0)) if run else 0.0)
	var jaw := PackedVector2Array([neck + Vector2(10, 12), neck + Vector2(60, 8 + head_up + jaw_open), neck + Vector2(56, 16 + head_up + jaw_open),
			neck + Vector2(8, 20)])
	draw_colored_polygon(jaw, HIDE)
	if jaw_open > 4.0:
		for k in 4:
			var tooth: Vector2 = neck + Vector2(24 + k * 9, 7 + head_up + jaw_open * 0.2)
			draw_colored_polygon(PackedVector2Array([tooth, tooth + Vector2(3, 7), tooth + Vector2(6, 0)]), Color("d8d0bc"))
	draw_circle(neck + Vector2(40, -6 + head_up), 3.5, EYE)
	draw_circle(neck + Vector2(40, -6 + head_up), 8.0, Color(EYE, 0.25))
	draw_set_transform(Vector2.ZERO)
