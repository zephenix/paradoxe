@tool
class_name ExitZone
extends Node2D
## Sortie d'un écran (J7) : quand Élias arrive dans la bande [x, x + width]
## (à peu près à cette hauteur), et que le compagnon est avec lui si
## « needs_companion », la sortie est atteinte : le texte « message » (un Label)
## s'affiche, et la cinématique « cutscene » se joue (J8 : le passage vers
## l'écran suivant).
##
## La sortie peut aussi exiger un objet (« needs_item », par exemple l'arme
## retrouvée dans le casier) : sans lui, on ne passe pas, sinon on arriverait
## désarmé au combat de l'écran 7, sans pouvoir revenir. Tant qu'il manque
## quelque chose, le texte « hint » (un Label) dit quoi.

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
## Cinématique jouée à la sortie (vide : aucune).
@export var cutscene: NodePath
## Objet exigé pour sortir (&"" : aucun), et textes affichés dans « hint » quand il
## manque quelque chose.
@export var needs_item: StringName = &""
@export var hint: NodePath
@export_multiline var item_missing_text: String = "Votre arme est restée dans le casier."
@export_multiline var companion_missing_text: String = "Pas sans Marek : attendez-le (Q, ou A en AZERTY)."

var reached: bool = false
## Ce qui empêche de sortir en ce moment : &"" (rien), &"item" ou &"companion".
var blocked_reason: StringName = &""
## Les textes (gardés ici : le niveau les déplace dans un autre calque).
var _label: CanvasItem
var _hint: Label


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_label = get_node_or_null(message) as CanvasItem
	if _label:
		_label.visible = false
	_hint = get_node_or_null(hint) as Label
	if _hint:
		_hint.visible = false


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or reached:
		return
	var player: Node2D = get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null or not _inside(player.global_position):
		_show_hint(&"")
		return
	if needs_item != &"" and not GameState.has_item(needs_item):
		_show_hint(&"item")
		return
	if needs_companion:
		var buddy: Node2D = get_tree().get_first_node_in_group(&"companion") as Node2D
		if buddy == null or buddy.global_position.distance_to(player.global_position) > companion_distance:
			_show_hint(&"companion")
			return
	_show_hint(&"")
	reached = true
	if _label:
		_label.visible = true
	exit_reached.emit()
	var scene: Cutscene = get_node_or_null(cutscene) as Cutscene
	var level: Level = _level()
	if scene and level:
		level.cutscenes.play(scene)


## Montre (ou cache) le texte qui dit ce qui manque.
func _show_hint(reason: StringName) -> void:
	blocked_reason = reason
	if _hint == null:
		return
	_hint.visible = reason != &""
	if reason == &"item":
		_hint.text = item_missing_text
	elif reason == &"companion":
		_hint.text = companion_missing_text


func _level() -> Level:
	var node: Node = get_parent()
	while node and not (node is Level):
		node = node.get_parent()
	return node as Level


func _inside(point: Vector2) -> bool:
	var offset: Vector2 = point - global_position
	return offset.x >= 0.0 and offset.x <= width and absf(offset.y) <= 96.0


func _draw() -> void:
	# Un encadrement de porte, et une flèche verte.
	draw_rect(Rect2(0, -120, width, 120), Color(0.12, 0.14, 0.16))
	draw_rect(Rect2(0, -120, width, 120), Color(0.43, 1.0, 0.69, 0.5), false, 2.0)
