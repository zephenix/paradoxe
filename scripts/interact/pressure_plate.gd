@tool
class_name PressurePlate
extends Interactable
## Plaque de pression (J7) : enclenchée tant que quelqu'un (Élias ou le
## compagnon) se tient dessus. Une porte peut rester ouverte tant qu'elle est
## enfoncée : le compagnon qui y attend la tient pour Élias (écran 5).
## C'est un objet interactif pour le compagnon seulement : l'ordre « Active
## ça » l'envoie s'y placer (et il y attend).
## L'origine du nœud est le milieu de la plaque, au ras du sol.

## Émis quand la plaque s'enfonce ou remonte.
signal changed(on: bool)

## Largeur de la plaque (pixels).
@export var width: float = 64.0:
	set(value):
		width = value
		queue_redraw()

var on: bool = false


func _init() -> void:
	companion_can_use = true
	player_can_use = false


func _ready() -> void:
	super._ready()
	if not Engine.is_editor_hint():
		add_to_group(RewindManager.GROUP)


## Le compagnon « l'actionne » en se plaçant dessus : rien d'autre à faire.
func _on_interact(by: Node) -> bool:
	return by is Companion


func is_on() -> bool:
	return on


## Quelqu'un est-il dessus ? (pieds dans la largeur de la plaque, au niveau du sol)
func _is_pressed() -> bool:
	for group: StringName in [&"player", &"companion"]:
		for node in get_tree().get_nodes_in_group(group):
			var body: CharacterBody2D = node as CharacterBody2D
			if body == null or not body.is_on_floor():
				continue
			var offset: Vector2 = body.global_position - global_position
			if absf(offset.x) <= width * 0.5 and absf(offset.y) <= 6.0:
				return true
	return false


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var pressed: bool = _is_pressed()
	if pressed != on:
		on = pressed
		AudioManager.play_sfx(&"plate_click", global_position)
		queue_redraw()
		changed.emit(on)


func capture_state() -> Dictionary:
	return {"on": on}


func apply_state(state: Dictionary) -> void:
	on = state["on"]
	queue_redraw()


func resume_state(_state: Dictionary) -> void:
	pass


func _draw() -> void:
	var half: float = width * 0.5
	var depth: float = 1.0 if on else 4.0
	draw_rect(Rect2(-half, -depth, width, depth), Color(0.43, 1.0, 0.69) if on else Color(0.55, 0.5, 0.35))
	draw_rect(Rect2(-half - 3, -1, width + 6, 2), Color(0.2, 0.22, 0.25))
	draw_companion_mark(Vector2(0, -20))
