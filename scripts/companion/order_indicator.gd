class_name OrderIndicator
extends Node2D
## Retour visuel des ordres au compagnon (J7) : montre au joueur ce que fait la
## touche « Ordre » pendant qu'il la maintient.
##
## - Au-dessus d'Élias, un anneau se remplit : une fois plein (appui long),
##   l'ordre « Active ça » part. Relâché avant : c'est « suis-moi / attends ».
## - Pendant l'appui, la spirale du mécanisme que Marek irait actionner
##   s'entoure d'un cercle vert. S'il n'y en a aucun à portée, l'anneau est gris :
##   Marek refusera.
## - Quand l'ordre part, un cercle s'élargit autour de la spirale visée.
##
## Créé par le Player (enfant d'Élias : il le suit partout). Il ne décide rien :
## le Player lui dit quoi montrer (show_progress, confirm, hide_progress).

## Vert des spirales (le même que Interactable.draw_companion_mark).
const MARK_COLOR: Color = Color(0.43, 1.0, 0.69)
## Gris : aucun mécanisme à portée.
const NONE_COLOR: Color = Color(0.62, 0.62, 0.62)
## Rayon de l'anneau au-dessus d'Élias (pixels).
const RING_RADIUS: float = 11.0
## Rayon du cercle autour de la spirale visée (pixels).
const TARGET_RADIUS: float = 15.0
## Durée du cercle qui s'élargit quand l'ordre part (secondes).
const CONFIRM_TIME: float = 0.7

## Remplissage de l'anneau (0 à 1) ; négatif = rien à montrer.
var progress: float = -1.0
## Mécanisme visé pendant l'appui (null : aucun).
var target: Interactable = null

var _confirmed: Interactable = null
var _confirm_left: float = 0.0
var _time: float = 0.0


## Appui en cours : anneau rempli à « amount » (0 à 1), mécanisme visé « item ».
func show_progress(amount: float, item: Interactable) -> void:
	progress = clampf(amount, 0.0, 1.0)
	target = item
	queue_redraw()


## L'ordre long vient de partir vers « item » (null : refus).
func confirm(item: Interactable) -> void:
	_confirmed = item
	_confirm_left = CONFIRM_TIME if item else 0.0
	queue_redraw()


## Touche relâchée : l'anneau disparaît (le cercle de confirmation finit seul).
func hide_progress() -> void:
	if progress < 0.0 and target == null:
		return
	progress = -1.0
	target = null
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if _confirm_left > 0.0:
		_confirm_left = maxf(_confirm_left - delta, 0.0)
		queue_redraw()
	elif progress >= 0.0:
		queue_redraw()  # la spirale visée « respire »


func _draw() -> void:
	if progress >= 0.0:
		var color: Color = MARK_COLOR if target else NONE_COLOR
		# Fond sombre, puis l'arc qui se remplit dans le sens des aiguilles d'une montre.
		draw_circle(Vector2.ZERO, RING_RADIUS + 2.0, Color(0.0, 0.0, 0.0, 0.45))
		draw_arc(Vector2.ZERO, RING_RADIUS, 0.0, TAU, 24, Color(color, 0.25), 2.0)
		if progress > 0.0:
			draw_arc(Vector2.ZERO, RING_RADIUS, -PI / 2.0, -PI / 2.0 + TAU * progress, 24, color, 3.0)
		if is_instance_valid(target):
			var pulse: float = 0.5 + 0.5 * sin(_time * 8.0)
			draw_arc(to_local(target.mark_position()), TARGET_RADIUS + 2.0 * pulse, 0.0, TAU, 28,
					Color(MARK_COLOR, 0.6 + 0.4 * progress), 2.0)
	if _confirm_left > 0.0 and is_instance_valid(_confirmed):
		var k: float = 1.0 - _confirm_left / CONFIRM_TIME  # 0 → 1
		draw_arc(to_local(_confirmed.mark_position()), TARGET_RADIUS + 25.0 * k, 0.0, TAU, 32,
				Color(MARK_COLOR, 1.0 - k), 3.0)
