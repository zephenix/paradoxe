class_name State
extends Node
## Un état d'une machine à états (voir StateMachine).
##
## Chaque état est un nœud enfant de la StateMachine, avec son propre script :
## « Idle », « Run », « Jump »… Un seul état est actif à la fois. La machine
## appelle ses fonctions ; l'état décide lui-même quand passer à un autre
## (machine.transition_to(&"Run")).
##
## Les fonctions à redéfinir (toutes facultatives) :
##   enter(previous, data)     à l'entrée dans l'état
##   exit()                    à la sortie
##   physics_update(delta)     à chaque pas de physique (60 fois par seconde)
##   handle_input(event)       à chaque évènement d'entrée (touche, bouton…)
##   is_committed()            vrai si l'état est « engagé » (non interruptible)

## Machine qui possède cet état (renseignée par la machine au démarrage).
var machine: StateMachine
## Objet contrôlé (le joueur, un ennemi…), renseigné par la machine.
var actor: Node
## Temps passé dans l'état depuis la dernière entrée (secondes).
var time_in_state: float = 0.0


func enter(_previous: StringName, _data: Dictionary) -> void:
	pass


func exit() -> void:
	pass


func physics_update(_delta: float) -> void:
	pass


func handle_input(_event: InputEvent) -> void:
	pass


## Un état engagé (saut, roulade, hissage…) va à son terme : les autres
## systèmes (dégâts mis à part) ne doivent pas l'interrompre.
func is_committed() -> bool:
	return false
