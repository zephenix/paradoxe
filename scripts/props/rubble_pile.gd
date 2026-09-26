@tool
class_name RubblePile
extends Area2D
## Un tas de gravats (J6) : en passant dessus, Élias ramasse des pierres
## (jusqu'au maximum qu'il peut porter, resources/player/throw.tres). Le tas
## ne s'épuise pas. L'origine du nœud est au sol, au centre du tas.

## Largeur du tas (pixels).
@export var width: float = 72.0:
	set(value):
		width = value
		queue_redraw()

## Délai minimal entre deux ramassages (secondes) : un seul bruit par passage.
const PICKUP_COOLDOWN: float = 1.0

var _cooldown: float = 0.0


func _ready() -> void:
	collision_layer = PhysicsLayers.TRIGGERS
	collision_mask = PhysicsLayers.PLAYER
	monitorable = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, 40.0)
	shape.shape = rect
	shape.position = Vector2(0.0, -20.0)
	add_child(shape)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _cooldown > 0.0:
		return
	for body in get_overlapping_bodies():
		var player: Player = body as Player
		if player and not player.is_dead and player.stones < player.throw_config.max_stones:
			player.stones = player.throw_config.max_stones
			AudioManager.play_sfx(&"stone_pickup", global_position, player)
			_cooldown = PICKUP_COOLDOWN


func _draw() -> void:
	var half: float = width * 0.5
	var color := Color(0.42, 0.42, 0.4)
	draw_colored_polygon(PackedVector2Array([Vector2(-half, 0), Vector2(-half * 0.6, -14), Vector2(-half * 0.1, -20),
			Vector2(half * 0.4, -16), Vector2(half, 0)]), color)
	for i in 5:
		var x: float = -half * 0.7 + i * half * 0.35
		draw_circle(Vector2(x, -4.0 - (i % 2) * 7.0), 5.0, color.lightened(0.1 + 0.05 * i))
