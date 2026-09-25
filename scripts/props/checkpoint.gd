@tool
class_name Checkpoint
extends Area2D
## Point de sauvegarde : quand Élias le touche, il devient le point de
## réapparition après une mort (PLAN §5.7 : un à l'entrée de chaque écran et
## avant chaque passage difficile).
##
## Posé au sol : l'origine du nœud est l'endroit où les pieds d'Élias
## réapparaîtront. La zone de détection monte de trigger_size au-dessus.
## Avec show_beacon, une petite balise s'allume en vert quand le checkpoint est
## actif (un seul l'est à la fois) ; sinon le checkpoint est invisible.

## Identifiant unique dans le niveau. Vide : le nom du nœud est utilisé.
@export var checkpoint_id: StringName = &""
## Sens du regard d'Élias quand il réapparaît ici.
@export_enum("Gauche:-1", "Droite:1") var facing: int = 1
## Taille de la zone de détection (pixels), posée sur le sol.
@export var trigger_size: Vector2 = Vector2(48, 144):
	set(value):
		trigger_size = value
		_update_shape()
		queue_redraw()
## Afficher la balise lumineuse (sinon, checkpoint invisible).
@export var show_beacon: bool = true:
	set(value):
		show_beacon = value
		queue_redraw()

const BEACON_OFF := Color("2c3b40")
const BEACON_ON := Color("6dffb0")

## Vrai si c'est le checkpoint actif.
var is_active: bool = false

var _shape := RectangleShape2D.new()
var _glow: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	var shape_node := CollisionShape2D.new()
	shape_node.shape = _shape
	add_child(shape_node)
	_update_shape()
	if Engine.is_editor_hint():
		return
	collision_layer = 0
	collision_mask = PhysicsLayers.PLAYER
	body_entered.connect(_on_body_entered)
	Events.checkpoint_reached.connect(_on_checkpoint_reached)
	is_active = GameState.checkpoint_id == id()


## Identifiant effectif (checkpoint_id, ou le nom du nœud).
func id() -> StringName:
	return checkpoint_id if checkpoint_id != &"" else StringName(name)


func _on_body_entered(body: Node2D) -> void:
	var player: Player = body as Player
	if player == null or player.is_dead:
		return
	if GameState.reach_checkpoint(id(), global_position, facing):
		AudioManager.play_sfx(&"checkpoint_on", global_position + Vector2(0, -60))
		_glow = 1.0


## Un seul checkpoint actif : les autres s'éteignent.
func _on_checkpoint_reached(reached_id: StringName) -> void:
	is_active = reached_id == id()
	queue_redraw()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not show_beacon:
		return
	_time += delta
	_glow = maxf(_glow - delta * 1.5, 0.0)
	if is_active or _glow > 0.0:
		queue_redraw()


func _update_shape() -> void:
	_shape.size = trigger_size
	if get_child_count() > 0 and get_child(0) is CollisionShape2D:
		(get_child(0) as CollisionShape2D).position = Vector2(0.0, -trigger_size.y * 0.5)


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(Rect2(Vector2(-trigger_size.x * 0.5, -trigger_size.y), trigger_size), Color(0.4, 1.0, 0.7, 0.25))
	if not show_beacon:
		return
	# Balise : un pied sombre et une tête qui s'allume.
	draw_rect(Rect2(Vector2(-3, -34), Vector2(6, 34)), Color("1f2a2e"))
	draw_rect(Rect2(Vector2(-7, -40), Vector2(14, 7)), Color("26343a"))
	var light: Color = BEACON_ON if is_active else BEACON_OFF
	if is_active:
		light = light.darkened(0.25 - 0.25 * sin(_time * 3.0))
	draw_rect(Rect2(Vector2(-5, -39), Vector2(10, 4)), light)
	if is_active or _glow > 0.0:
		draw_circle(Vector2(0, -37), 10.0 + 22.0 * _glow, Color(BEACON_ON, 0.15 + 0.4 * _glow))
