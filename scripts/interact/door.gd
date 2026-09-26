@tool
class_name Door
extends StaticBody2D
## Porte (J7) : un bloc qui coulisse vers le haut. Fermée, elle bloque le
## passage comme un mur (couche WORLD).
##
## Elle s'ouvre selon ses « interrupteurs » (switches : leviers, plaques…) :
##   - require_all = vrai : il faut qu'ils soient TOUS enclenchés en même temps
##     (deux leviers à ressort actionnés ensemble) ; sinon, un seul suffit ;
##   - latch = vrai : une fois ouverte, elle le reste (porte de cellule) ;
##     sinon elle se referme quand la condition cesse (porte tenue par une plaque).
## Un terminal peut aussi l'ouvrir ou la fermer par une impulsion (trigger()).
## L'origine du nœud est le coin HAUT-GAUCHE de la porte fermée.

## Émis quand la porte finit de s'ouvrir (vrai) ou de se fermer (faux).
signal moved(open: bool)

## Taille en blocs.
@export var size_blocks: Vector2 = Vector2(0.5, 3):
	set(value):
		size_blocks = value
		queue_redraw()
## Style : &"slab" (porte pleine) ou &"bars" (barreaux de cellule).
@export var style: StringName = &"slab":
	set(value):
		style = value
		queue_redraw()
## Interrupteurs (leviers, plaques…) qui l'ouvrent.
@export var switches: Array[NodePath] = []
@export var require_all: bool = false
@export var latch: bool = false
## Durée d'ouverture ou de fermeture (secondes).
@export var move_time: float = 0.6

## Ouverture de 0 (fermée) à 1 (ouverte).
var openness: float = 0.0
## Position voulue : vrai = ouverte.
var wants_open: bool = false
var _latched: bool = false
var _sources: Array[Node] = []
var _shape := RectangleShape2D.new()
var _shape_node := CollisionShape2D.new()


func _ready() -> void:
	_shape_node.shape = _shape
	add_child(_shape_node)
	_update_shape()
	if Engine.is_editor_hint():
		return
	collision_mask = 0
	add_to_group(RewindManager.GROUP)
	connect_switches()


## Relie la porte à ses interrupteurs (appelé au démarrage ; à rappeler si on
## change « switches » ensuite).
func connect_switches() -> void:
	_sources.clear()
	for path in switches:
		var source: Node = get_node_or_null(path)
		if source and source.has_method(&"is_on"):
			_sources.append(source)


func size() -> Vector2:
	return size_blocks * GameUnits.BLOCK


func is_open() -> bool:
	return openness >= 1.0


## Impulsion d'un terminal : ouvre si fermée, ferme si ouverte.
func trigger() -> void:
	_latched = not wants_open
	wants_open = not wants_open


func _condition() -> bool:
	if _sources.is_empty():
		return false
	var count: int = 0
	for source in _sources:
		if source.call(&"is_on"):
			count += 1
	return count == _sources.size() if require_all else count > 0


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not _sources.is_empty():
		var condition: bool = _condition()
		if condition and latch:
			_latched = true
		var goal: bool = condition or _latched
		if goal != wants_open:
			wants_open = goal
	var target: float = 1.0 if wants_open else 0.0
	if is_equal_approx(openness, target):
		return
	if (openness == 0.0 and wants_open) or (openness == 1.0 and not wants_open):
		AudioManager.play_sfx(&"bars_clank" if style == &"bars" else &"door_slide", global_position + size() * 0.5)
	openness = move_toward(openness, target, delta / maxf(move_time, 0.01))
	_update_shape()
	if is_equal_approx(openness, target):
		moved.emit(wants_open)


## La forme de collision suit la partie encore visible de la porte ; ouverte
## aux trois quarts, elle ne bloque plus rien.
func _update_shape() -> void:
	var full: Vector2 = size()
	var height: float = full.y * (1.0 - openness)
	_shape.size = Vector2(full.x, maxf(height, 1.0))
	_shape_node.position = Vector2(full.x * 0.5, height * 0.5)
	collision_layer = PhysicsLayers.WORLD if openness < 0.75 else 0
	queue_redraw()


func capture_state() -> Dictionary:
	return {"openness": openness, "wants_open": wants_open, "latched": _latched}


func apply_state(state: Dictionary) -> void:
	openness = state["openness"]
	wants_open = state["wants_open"]
	_latched = state["latched"]
	_update_shape()


func resume_state(_state: Dictionary) -> void:
	pass


func _draw() -> void:
	var full: Vector2 = size()
	var height: float = full.y * (1.0 - openness)
	if height <= 1.0:
		return
	if style == &"bars":
		var count: int = maxi(2, int(full.x / 10.0))
		for i in count:
			var x: float = (i + 0.5) * full.x / count
			draw_line(Vector2(x, 0), Vector2(x, height), Color(0.5, 0.53, 0.56), 3.0)
		draw_line(Vector2(0, 4), Vector2(full.x, 4), Color(0.4, 0.43, 0.46), 4.0)
		draw_line(Vector2(0, height - 3), Vector2(full.x, height - 3), Color(0.4, 0.43, 0.46), 4.0)
	else:
		draw_rect(Rect2(0, 0, full.x, height), Color(0.33, 0.36, 0.4))
		draw_rect(Rect2(3, height - 10, full.x - 6, 4), Color(0.85, 0.7, 0.3))
