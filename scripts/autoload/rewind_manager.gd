extends Node
## Rembobinage temporel (autoload « RewindManager »).
##
## J1 : squelette documenté. Le fonctionnement complet arrive en J4 :
##   - chaque objet « rembobinable » rejoint le groupe GROUP et fournit deux
##     fonctions : capture_state() -> Dictionary et apply_state(state: Dictionary) ;
##   - le gestionnaire photographie l'état de ces objets ~30 fois par seconde
##     et garde les 5 dernières secondes dans une mémoire circulaire ;
##   - à la mort du joueur, il rejoue ces photos à l'envers.
## Voir docs/PLAN.md §5.5.

## Groupe Godot des objets à enregistrer.
const GROUP: StringName = &"rewindable"

## Le rembobinage est-il disponible ? (faux en mode classique)
func is_available() -> bool:
	return not GameState.is_classic_mode()
