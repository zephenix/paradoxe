extends PlayerState
## Roulade : esquive au sol, ou réception obligatoire d'une chute moyenne
## (data["landing"]). Engagée. Silhouette basse pendant la roulade.
## L'esquive rend brièvement invulnérable (sauf en mode classique).

var _landing: bool = false


func enter(_previous: StringName, data: Dictionary) -> void:
	_landing = data.get("landing", false)
	player.set_crouched(true)
	if player.input.move != 0 and not _landing:
		player.facing = player.input.move
	player.visual.play(&"roll", player.config.roll_duration)
	player.anim_event.emit(&"roll")


func exit() -> void:
	player.is_invulnerable = false


func is_committed() -> bool:
	return true


func physics_update(delta: float) -> void:
	var p: Player = player
	var k: float = time_in_state / p.config.roll_duration
	var window: Vector2 = p.config.roll_invulnerable_window
	p.is_invulnerable = p.modern() and not _landing and k >= window.x and k <= window.y
	p.velocity.x = p.facing * p.config.roll_speed() * (1.0 - 0.4 * k)
	p.move_in_air(delta)
	if not p.is_on_floor() and p.time_since_grounded > 0.08:
		machine.transition_to(&"Fall")
		return
	if time_in_state >= p.config.roll_duration:
		machine.transition_to(&"Idle" if p.can_stand() else &"Crouch")
