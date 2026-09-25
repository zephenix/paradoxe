extends PlayerState
## Chute (on a quitté le sol sans sauter, ou on a lâché un rebord).
## Élias garde sa vitesse horizontale. Juste après avoir quitté un bord en
## marchant ou en courant, on peut encore sauter (« temps du coyote »).

var _coyote_allowed: bool = false


func enter(previous: StringName, _data: Dictionary) -> void:
	_coyote_allowed = previous in [&"Walk", &"Run", &"Idle"] and player.modern()
	player.visual.play(&"fall")


func physics_update(delta: float) -> void:
	var p: Player = player
	if _coyote_allowed and time_in_state <= p.config.coyote_time and p.wants(&"jump"):
		# Déjà en l'air : on décolle tout de suite, sans plier les genoux.
		p.start_jump(&"running" if p.has_momentum() else &"standing", true)
		return
	if p.is_crouched and p.can_stand():
		p.set_crouched(false)
	p.move_in_air(delta)
	if p.try_grab():
		return
	if p.is_on_floor():
		p.land()
