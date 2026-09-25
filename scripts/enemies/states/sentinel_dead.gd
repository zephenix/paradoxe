extends SentinelState
## Morte : elle s'effondre et reste au sol (le corps ne bloque plus rien).
## Elle ne revient que si Élias réapparaît à un checkpoint atteint avant sa
## mort (voir Sentinel.reset_to_start).


func enter(_previous: StringName, _data: Dictionary) -> void:
	sentinel.velocity.x = 0.0
	sentinel.visual.play(&"death")


func physics_update(delta: float) -> void:
	sentinel.apply_gravity(delta)
	sentinel.move_and_slide()


func on_noise(_at: Vector2) -> void:
	pass
