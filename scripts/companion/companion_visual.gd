class_name CompanionVisual
extends EliasVisual
## Silhouette du compagnon (J7) : un vieil homme, prisonnier des Sentinelles.
## Même squelette et mêmes gestes qu'Élias, autre peau : manteau usé, cheveux
## blancs, barbe, et un PENDENTIF EN SPIRALE (celui de la photo de l'intro :
## PLAN §4.3, indices du twist).

const PENDANT := Color("6dffb0")


func _init() -> void:
	coat_color = Color("7a6f62")
	coat_shade = Color("5f564c")
	trousers_color = Color("3b3a3f")
	shoes_color = Color("1d1b1c")
	skin_color = Color("c99a82")
	hair_color = Color("d9d6cf")


## Visage marqué, cheveux blancs en couronne, barbe.
func _build_head(head: Node2D) -> void:
	_poly(head, [Vector2(-3, 0), Vector2(3, 0), Vector2(3, -4)], skin_color)  # cou
	_poly(head, [Vector2(-6, -3), Vector2(5, -4), Vector2(8, -9), Vector2(7, -14), Vector2(1, -17), Vector2(-5, -15), Vector2(-7, -9)], skin_color)
	_poly(head, [Vector2(-7, -7), Vector2(-7, -14), Vector2(-3, -17), Vector2(0, -16), Vector2(-4, -13), Vector2(-4, -8)], hair_color)
	_poly(head, [Vector2(-2, -3), Vector2(6, -4), Vector2(7, -7), Vector2(3, -6), Vector2(-1, -6)], hair_color)  # barbe


## Le pendentif en spirale, sur la poitrine.
func _decorate(_back_fore: Node2D, torso: Node2D, _head: Node2D) -> void:
	var line := Line2D.new()
	line.width = 1.4
	line.default_color = PENDANT
	for i in 25:
		var k: float = float(i) / 24.0
		var angle: float = k * 2.0 * TAU
		line.add_point(Vector2(5, -20) + Vector2(cos(angle), sin(angle)) * 3.5 * k)
	torso.add_child(line)
	var cord := Line2D.new()
	cord.width = 1.0
	cord.default_color = Color(0.25, 0.22, 0.2)
	cord.points = PackedVector2Array([Vector2(2, -31), Vector2(5, -24)])
	torso.add_child(cord)
