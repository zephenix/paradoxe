class_name ImpactFlash
extends Node2D
## Petit éclair lumineux à l'endroit d'un impact : un cercle qui grandit et
## s'efface en quelques centièmes de seconde, puis le nœud se supprime.

## Durée de l'éclair (secondes).
const DURATION: float = 0.16
## Rayon final (pixels) pour un impact normal.
const RADIUS: float = 16.0

var color: Color = Color.WHITE
var size_factor: float = 1.0
var _age: float = 0.0


## Crée un éclair dans « parent » à la position « at » (coordonnées du monde).
static func spawn(parent: Node, at: Vector2, flash_color: Color, factor: float = 1.0) -> ImpactFlash:
	if parent == null:
		return null
	var flash := ImpactFlash.new()
	flash.color = flash_color
	flash.size_factor = factor
	parent.add_child(flash)
	flash.global_position = at
	return flash


func _process(delta: float) -> void:
	_age += delta
	if _age >= DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k: float = _age / DURATION
	var radius: float = RADIUS * size_factor * (0.4 + 0.6 * k)
	draw_circle(Vector2.ZERO, radius, Color(color, 0.5 * (1.0 - k)))
	draw_circle(Vector2.ZERO, radius * 0.45, Color(color.lightened(0.7), 1.0 - k))
