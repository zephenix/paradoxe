@tool
class_name ItemPickup
extends Interactable
## Objet à ramasser (J7) : l'actionner l'ajoute à l'inventaire (GameState) et
## le fait disparaître. L'objet « pistol » rend son arme à Élias.

## Identifiant de l'objet (inventaire).
@export var item: StringName = &"pistol"

## Vrai une fois ramassé.
var taken: bool = false


func _ready() -> void:
	super._ready()
	if not Engine.is_editor_hint():
		add_to_group(RewindManager.GROUP)


func _on_interact(by: Node) -> bool:
	if taken or not (by is Player):
		return false
	GameState.add_item(item)
	AudioManager.play_sfx(&"item_pickup", global_position + Vector2(0, -30), by)
	_set_taken(true)
	return true


func _set_taken(value: bool) -> void:
	taken = value
	enabled = not taken
	queue_redraw()


func capture_state() -> Dictionary:
	return {"taken": taken}


func apply_state(state: Dictionary) -> void:
	if taken and not state["taken"]:
		GameState.remove_item(item)  # le ramassage « n'a pas encore eu lieu »
	elif not taken and state["taken"]:
		GameState.add_item(item)
	_set_taken(state["taken"])


func resume_state(_state: Dictionary) -> void:
	pass


func _draw() -> void:
	# Un casier ouvert : dedans, l'objet (sa silhouette), tant qu'il n'est pas pris.
	draw_rect(Rect2(-16, -64, 32, 64), Color(0.24, 0.27, 0.3))
	draw_rect(Rect2(-12, -60, 24, 56), Color(0.12, 0.14, 0.16))
	if not taken:
		draw_rect(Rect2(-8, -40, 16, 6), Color(0.3, 0.33, 0.38))
		draw_rect(Rect2(-8, -40, 5, 12), Color(0.3, 0.33, 0.38))
		draw_rect(Rect2(2, -39, 4, 4), Color(0.62, 0.96, 0.82))
