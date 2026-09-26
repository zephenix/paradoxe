@tool
class_name Lever
extends Interactable
## Levier (J7). Deux sortes :
##   - à bascule (hold_time = 0) : chaque action l'enclenche ou le relâche ;
##   - à ressort (hold_time > 0) : il reste enclenché hold_time secondes puis
##     revient seul. Deux leviers à ressort éloignés s'actionnent « ensemble »
##     s'ils sont enclenchés en même temps (énigme à deux, écran 5).
## Une porte ou un ascenseur écoutent son signal « changed ».

## Émis quand le levier change de position.
signal changed(on: bool)

## Durée pendant laquelle un levier à ressort reste enclenché (0 = à bascule).
@export var hold_time: float = 0.0

## Vrai quand le levier est enclenché.
var on: bool = false
var _timer: float = 0.0


func _ready() -> void:
	super._ready()
	if not Engine.is_editor_hint():
		add_to_group(RewindManager.GROUP)


func is_on() -> bool:
	return on


func _on_interact(_by: Node) -> bool:
	if hold_time > 0.0:
		_timer = hold_time
		if on:
			return true  # déjà enclenché : le ressort repart pour un tour
		_set_on(true)
	else:
		_set_on(not on)
	AudioManager.play_sfx(&"lever_pull", global_position + Vector2(0, -40), _by)
	return true


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not on or hold_time <= 0.0:
		return
	_timer -= delta
	if _timer <= 0.0:
		_set_on(false)


func _set_on(value: bool) -> void:
	if on == value:
		return
	on = value
	queue_redraw()
	changed.emit(on)


func capture_state() -> Dictionary:
	return {"on": on, "timer": _timer}


func apply_state(state: Dictionary) -> void:
	_timer = state["timer"]
	_set_on(state["on"])


func resume_state(_state: Dictionary) -> void:
	pass


func _draw() -> void:
	# Socle au mur, manche incliné (vers la gauche : relâché ; vers la droite : enclenché).
	draw_rect(Rect2(-9, -52, 18, 16), Color(0.25, 0.27, 0.3))
	var tip := Vector2(14 if on else -14, -70)
	draw_line(Vector2(0, -44), tip, Color(0.62, 0.64, 0.66), 4.0)
	draw_circle(tip, 4.0, Color(0.85, 0.35, 0.25) if not on else Color(0.43, 1.0, 0.69))
	draw_companion_mark()
