extends PlayerState
## Suspendu à un rebord. Haut (ou saut) : se hisser. Bas ou direction
## opposée : lâcher prise.

var _ledge: Dictionary = {}


func enter(_previous: StringName, data: Dictionary) -> void:
	_ledge = data.get("ledge", {})
	player.set_crouched(false)
	player.velocity = Vector2.ZERO
	player.visual.play(&"hang")
	player.anim_event.emit(&"grab")


func physics_update(_delta: float) -> void:
	var p: Player = player
	p.air_top_y = p.global_position.y
	var climb: bool = p.wants(&"move_up") or p.wants(&"jump") or (p.input.up and time_in_state > 0.25)
	if climb and _ledge.get("can_stand", false):
		machine.transition_to(&"LedgeClimb", {"ledge": _ledge})
		return
	if p.input.down or p.input.move == -p.facing:
		p.grab_cooldown = 0.35
		machine.transition_to(&"Fall")
