@tool
class_name Terminal
extends Interactable
## Terminal (J7) : une console. L'actionner envoie une impulsion (trigger()) à
## chacune de ses cibles (porte, ascenseur…). Son écran s'allume un instant.

## Mécanismes commandés (chacun doit avoir une fonction trigger()).
@export var targets: Array[NodePath] = []

var _flash: float = 0.0


func _init() -> void:
	mark_offset = Vector2(0.0, -84.0)


func _on_interact(by: Node) -> bool:
	for path in targets:
		var target: Node = get_node_or_null(path)
		if target and target.has_method(&"trigger"):
			target.call(&"trigger")
	AudioManager.play_sfx(&"terminal_beep", global_position + Vector2(0, -50), by)
	_flash = 0.6
	return true


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta, 0.0)
		queue_redraw()


func _draw() -> void:
	# Pied, boîtier incliné, écran (pictogrammes, aucun texte).
	draw_rect(Rect2(-4, -40, 8, 40), Color(0.22, 0.24, 0.27))
	draw_colored_polygon(PackedVector2Array([Vector2(-18, -44), Vector2(18, -44), Vector2(14, -70), Vector2(-14, -70)]),
			Color(0.3, 0.33, 0.37))
	var screen := Color(0.3, 0.9, 0.7).lerp(Color.WHITE, _flash)
	draw_rect(Rect2(-11, -66, 22, 16), Color(screen, 0.35 + _flash))
	draw_line(Vector2(-8, -56), Vector2(-2, -62), screen, 1.5)
	draw_line(Vector2(-2, -62), Vector2(8, -58), screen, 1.5)
	draw_companion_mark()
