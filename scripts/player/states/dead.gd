extends PlayerState
## Mort. Élias s'effondre ; le niveau décide ensuite de la réapparition.


func enter(_previous: StringName, data: Dictionary) -> void:
	player.velocity.x = 0.0
	player.set_crouched(true)
	player.visual.play(&"death")
	player.anim_event.emit(&"death_" + String(data.get("cause", &"fall")))


func is_committed() -> bool:
	return true


func physics_update(delta: float) -> void:
	player.move_in_air(delta)
