extends CompanionState
## Cinématique : il ne décide rien. La cinématique le place et l'anime ; ici,
## seulement la gravité.


func physics_update(delta: float) -> void:
	var c: Companion = companion
	c.velocity.x = 0.0
	c.apply_gravity(delta)
	c.move_and_slide()
