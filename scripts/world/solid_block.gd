@tool
class_name SolidBlock
extends StaticBody2D
## Bloc de décor solide (sol, mur, plafond, plate-forme), mesuré en blocs de 48 px.
##
## « @tool » : ce script s'exécute aussi dans l'éditeur, si bien que changer la
## taille dans l'inspecteur redessine le bloc immédiatement. La forme de
## collision et le dessin (aplats façon « polygones ») sont générés ici.
## L'origine du nœud est le coin HAUT-GAUCHE du bloc.

const BLOCK: float = 48.0

## Taille en blocs (on peut utiliser des demi-blocs : 2.5, 0.5…).
@export var size_blocks: Vector2 = Vector2(4, 1):
	set(value):
		size_blocks = value
		_rebuild()
## Couleur principale de la face.
@export var color: Color = Color("3e4a57"):
	set(value):
		color = value
		_rebuild()
## Nature de la surface (sons de pas en J5) : &"stone", &"metal", &"plant", &"water".
@export var surface: StringName = &"stone"


func _ready() -> void:
	collision_layer = PhysicsLayers.WORLD
	collision_mask = 0
	_rebuild()


## Taille en pixels.
func pixel_size() -> Vector2:
	return size_blocks * BLOCK


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		if child.has_meta(&"generated"):
			remove_child(child)
			child.queue_free()
	var size: Vector2 = pixel_size()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = size * 0.5
	_add_generated(shape)
	# Face principale, arête supérieure éclairée, bas plus sombre.
	_add_generated(_polygon([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)], color))
	var lip: float = minf(6.0, size.y)
	_add_generated(_polygon([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, lip), Vector2(0, lip)], color.lightened(0.25)))
	var shade: float = minf(size.y * 0.35, 40.0)
	_add_generated(_polygon([Vector2(0, size.y - shade), Vector2(size.x, size.y - shade), size, Vector2(0, size.y)], color.darkened(0.25)))


func _polygon(points: Array[Vector2], fill: Color) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array(points)
	p.color = fill
	return p


func _add_generated(node: Node) -> void:
	node.set_meta(&"generated", true)
	add_child(node)
