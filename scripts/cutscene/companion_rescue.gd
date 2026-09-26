@tool
class_name CompanionRescue
extends Node2D
## Écran 8 (J8) : « le compagnon ouvre la dernière porte ». Quand Élias, poursuivi,
## passe cette abscisse, Marek (parti depuis l'écran 6) réapparaît derrière la
## porte et tire le levier qui l'ouvre.
##
## Ce n'est PAS une cinématique : pendant la poursuite, Élias doit garder la main.
## Marek reçoit simplement l'ordre « Active ça » sur le levier.

@export var companion: NodePath
@export var lever: NodePath
## Largeur de la zone de déclenchement (pixels, vers la droite).
@export var width: float = 96.0:
	set(value):
		width = value
		queue_redraw()

var done: bool = false


func _ready() -> void:
	if not Engine.is_editor_hint():
		Events.player_respawned.connect(func() -> void: done = false)


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or done:
		return
	var player: Node2D = get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null:
		return
	var offset: Vector2 = player.global_position - global_position
	if offset.x < 0.0 or offset.x > width or absf(offset.y) > 96.0:
		return
	var marek: Companion = get_node_or_null(companion) as Companion
	var switch: Lever = get_node_or_null(lever) as Lever
	if marek == null or switch == null:
		return
	done = true
	marek.away = false
	if not switch.on:
		marek.order_activate(switch)


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(Rect2(0, -96, width, 96), Color(0.43, 1.0, 0.69, 0.2))
