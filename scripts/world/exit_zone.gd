@tool
class_name ExitZone
extends Node2D
## Sortie d'un écran (J7) : quand Élias arrive dans la bande [x, x + width]
## (à peu près à cette hauteur), et que le compagnon est avec lui si
## « needs_companion », la sortie est atteinte : le texte « message » (un Label)
## s'affiche. Le niveau suivant arrivera en J8.

signal exit_reached

@export var width: float = 96.0:
	set(value):
		width = value
		queue_redraw()
## Faut-il que le compagnon soit là aussi (à moins de companion_distance pixels) ?
@export var needs_companion: bool = true
@export var companion_distance: float = 220.0
## Texte à montrer une fois la sortie atteinte.
@export var message: NodePath

var reached: bool = false
## Le texte (gardé ici : le niveau déplace les textes dans un autre calque).
var _label: CanvasItem


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_label = get_node_or_null(message) as CanvasItem
	if _label:
		_label.visible = false


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or reached:
		return
	var player: Node2D = get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null or not _inside(player.global_position):
		return
	if needs_companion:
		var buddy: Node2D = get_tree().get_first_node_in_group(&"companion") as Node2D
		if buddy == null or buddy.global_position.distance_to(player.global_position) > companion_distance:
			return
	reached = true
	if _label:
		_label.visible = true
	exit_reached.emit()


func _inside(point: Vector2) -> bool:
	var offset: Vector2 = point - global_position
	return offset.x >= 0.0 and offset.x <= width and absf(offset.y) <= 96.0


func _draw() -> void:
	# Un encadrement de porte, et une flèche verte.
	draw_rect(Rect2(0, -120, width, 120), Color(0.12, 0.14, 0.16))
	draw_rect(Rect2(0, -120, width, 120), Color(0.43, 1.0, 0.69, 0.5), false, 2.0)
