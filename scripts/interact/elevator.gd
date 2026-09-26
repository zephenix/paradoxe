@tool
class_name Elevator
extends AnimatableBody2D
## Ascenseur (J7) : une plate-forme qui fait l'aller-retour entre deux arrêts,
## en bas (sa position de départ) et en haut (départ + travel). Ceux qui se
## tiennent dessus sont emportés (AnimatableBody2D : le moteur physique les
## déplace avec elle).
##
## Chaque impulsion l'envoie à l'autre arrêt : un levier à ressort qu'on
## actionne (signal « changed » à vrai), ou un terminal (trigger()).
## « Manœuvré par l'un pour l'autre » : celui qui actionne le levier n'est pas
## sur la plate-forme (écran 5).
## L'origine du nœud est le coin HAUT-GAUCHE de la plate-forme, en bas.

signal arrived(at_top: bool)

## Largeur de la plate-forme (blocs).
@export var width_blocks: float = 4.0:
	set(value):
		width_blocks = value
		queue_redraw()
## Déplacement jusqu'à l'arrêt du haut (pixels ; vers le haut : y négatif).
@export var travel: Vector2 = Vector2(0, -432):
	set(value):
		travel = value
		queue_redraw()
## Vitesse (pixels par seconde).
@export var speed: float = 140.0
## Leviers qui l'appellent (une impulsion à chaque fois qu'on les enclenche).
@export var switches: Array[NodePath] = []

## Position : 0 = en bas, 1 = en haut.
var progress: float = 0.0
## Où elle va : 0 ou 1.
var goal: float = 0.0
var _bottom: Vector2
var _moving: bool = false

const LOOP_ID: StringName = &"elevator"
const THICKNESS: float = 24.0


func _ready() -> void:
	var shape_node := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width_blocks * GameUnits.BLOCK, THICKNESS)
	shape_node.shape = rect
	shape_node.position = rect.size * 0.5
	add_child(shape_node)
	if Engine.is_editor_hint():
		return
	collision_layer = PhysicsLayers.WORLD
	collision_mask = 0
	sync_to_physics = true
	_bottom = global_position
	add_to_group(RewindManager.GROUP)
	add_to_group(&"elevators")
	connect_switches()


## Relie l'ascenseur à ses leviers (appelé au démarrage ; à rappeler si on
## change « switches » ensuite).
func connect_switches() -> void:
	for path in switches:
		var source: Node = get_node_or_null(path)
		if source and source.has_signal(&"changed") and not source.is_connected(&"changed", _on_switch_changed):
			source.connect(&"changed", _on_switch_changed)


func _on_switch_changed(on: bool) -> void:
	if on:
		trigger()


## Envoie l'ascenseur à l'autre arrêt.
func trigger() -> void:
	goal = 0.0 if goal > 0.5 else 1.0


func is_at_top() -> bool:
	return goal >= 1.0 and progress >= 0.999


func is_at_bottom() -> bool:
	return goal <= 0.0 and progress <= 0.001


## Hauteur (y du monde) du dessus de la plate-forme.
func top_y() -> float:
	return global_position.y


## Abscisse du milieu de la plate-forme.
func center_x() -> float:
	return global_position.x + width_blocks * GameUnits.BLOCK * 0.5


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if is_equal_approx(progress, goal):
		if _moving:
			_moving = false
			AudioManager.stop_loop(LOOP_ID, 0.15)
			AudioManager.play_sfx(&"elevator_stop", global_position)
			arrived.emit(goal >= 1.0)
		return
	if not _moving:
		_moving = true
		AudioManager.play_loop_sfx(LOOP_ID, &"elevator_loop", 0.1)
	progress = move_toward(progress, goal, speed * delta / maxf(travel.length(), 1.0))
	global_position = _bottom + travel * progress
	queue_redraw()


func capture_state() -> Dictionary:
	return {"progress": progress, "goal": goal}


func apply_state(state: Dictionary) -> void:
	progress = state["progress"]
	goal = state["goal"]
	global_position = _bottom + travel * progress


func resume_state(_state: Dictionary) -> void:
	pass


func _exit_tree() -> void:
	if not Engine.is_editor_hint() and _moving:
		AudioManager.stop_loop(LOOP_ID, 0.1)


func _draw() -> void:
	var width: float = width_blocks * GameUnits.BLOCK
	draw_rect(Rect2(0, 0, width, THICKNESS), Color(0.36, 0.38, 0.42))
	draw_rect(Rect2(0, 0, width, 4), Color(0.85, 0.7, 0.3))
	# Câbles jusqu'en haut de la course (relatifs à la plate-forme).
	var top: float = (travel.y * (1.0 - progress)) - 8.0 if not Engine.is_editor_hint() else travel.y
	draw_line(Vector2(8, 0), Vector2(8, top), Color(0.3, 0.3, 0.32), 2.0)
	draw_line(Vector2(width - 8, 0), Vector2(width - 8, top), Color(0.3, 0.3, 0.32), 2.0)
