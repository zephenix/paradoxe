class_name EnergyGauge
extends Node2D
## Petite jauge d'énergie au-dessus d'Élias (PROVISOIRE, J3).
##
## Le plan ne veut pas d'interface permanente : en J9, c'est l'hologramme du
## bracelet qui montrera l'énergie. En attendant, cette jauge apparaît quand
## l'énergie change (tir, bouclier, recharge) puis s'efface d'elle-même.
## Une barre par unité d'énergie ; la dernière barre se remplit en partie.

## Temps d'affichage après le dernier changement (secondes), puis fondu.
const SHOW_TIME: float = 1.6
const FADE_TIME: float = 0.4
## Hauteur au-dessus des pieds (pixels) et taille d'une barre.
const HEIGHT: float = 116.0
const BAR_SIZE := Vector2(4, 7)
const BAR_GAP: float = 2.0
const COLOR_FULL := Color("7dffd8")
const COLOR_EMPTY := Color(0.1, 0.2, 0.2, 0.6)
const COLOR_LOW := Color("ff8a5c")

var _value: float = 0.0
var _capacity: float = 1.0
var _timer: float = 0.0


## Branche la jauge sur une réserve d'énergie.
func watch(pool: EnergyPool) -> void:
	pool.changed.connect(_on_changed)
	_value = pool.value
	_capacity = pool.config.capacity
	modulate.a = 0.0


func _on_changed(value: float, capacity: float) -> void:
	_value = value
	_capacity = capacity
	_timer = SHOW_TIME + FADE_TIME
	modulate.a = 1.0
	queue_redraw()


func _process(delta: float) -> void:
	if _timer <= 0.0:
		return
	_timer -= delta
	modulate.a = clampf(_timer / FADE_TIME, 0.0, 1.0)


func _draw() -> void:
	var bars: int = ceili(_capacity)
	var width: float = bars * (BAR_SIZE.x + BAR_GAP) - BAR_GAP
	var low: bool = _value < 2.0
	for i in bars:
		var x: float = -width * 0.5 + i * (BAR_SIZE.x + BAR_GAP)
		var rect := Rect2(Vector2(x, -HEIGHT), BAR_SIZE)
		draw_rect(rect, COLOR_EMPTY)
		var fill: float = clampf(_value - i, 0.0, 1.0)
		if fill > 0.0:
			var h: float = BAR_SIZE.y * fill
			draw_rect(Rect2(Vector2(x, -HEIGHT + BAR_SIZE.y - h), Vector2(BAR_SIZE.x, h)), COLOR_LOW if low else COLOR_FULL)
