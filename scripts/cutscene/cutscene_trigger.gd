@tool
class_name CutsceneTrigger
extends Node2D
## Déclencheur de cinématique (J7) : quand Élias arrive dans la bande
## [x, x + width] (à peu près à cette hauteur), la cinématique « cutscene » se
## joue (une seule fois si elle est marquée play_once).

@export var cutscene: NodePath
## Largeur de la zone (pixels, vers la droite).
@export var width: float = 96.0:
	set(value):
		width = value
		queue_redraw()


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var scene: Cutscene = get_node_or_null(cutscene) as Cutscene
	if scene == null or (scene.play_once and scene.played):
		return
	var player: Node2D = get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null:
		return
	var offset: Vector2 = player.global_position - global_position
	if offset.x >= 0.0 and offset.x <= width and absf(offset.y) <= 96.0:
		var level: Level = _level()
		if level and not level.cutscenes.playing:
			level.cutscenes.play(scene)


func _level() -> Level:
	var node: Node = get_parent()
	while node and not (node is Level):
		node = node.get_parent()
	return node as Level


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(Rect2(0, -96, width, 96), Color(1.0, 0.6, 0.2, 0.25))
