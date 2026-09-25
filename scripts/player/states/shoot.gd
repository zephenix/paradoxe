extends PlayerState
## Un tir : le projectile part à l'entrée dans l'état, puis le bras encaisse le
## recul pendant fire_cooldown secondes (état engagé : c'est la cadence de tir).
##
## Sans énergie, rien ne part : l'arme fait un « clic » à vide (Weapon.fire).
## Si la détente est encore enfoncée à la fin du recul, Élias commence à
## charger un tir puissant (état Charge).
## data["fired"] : le tir est déjà parti (tir chargé lâché depuis Charge) ;
## on ne joue alors que le recul.


func enter(_previous: StringName, data: Dictionary) -> void:
	var p: Player = player
	p.visual.play(&"shoot", p.weapon.config.fire_cooldown)
	if not data.get("fired", false):
		p.weapon.fire()


func is_committed() -> bool:
	return true


func physics_update(delta: float) -> void:
	var p: Player = player
	p.move_on_ground(0.0, delta)
	if p.lost_ground():
		machine.transition_to(&"Fall")
		return
	if time_in_state < p.weapon.config.fire_cooldown:
		return
	if p.input.fire and previous_was_not_charge():
		machine.transition_to(&"Charge")
	else:
		machine.transition_to(&"Aim")


## Après un tir chargé, on ne recommence pas une charge dans la foulée : il faut
## relâcher la détente.
func previous_was_not_charge() -> bool:
	return machine.previous_name != &"Charge"
