class_name SentinelState
extends State
## Base commune des états d'une Sentinelle : accès typé à la Sentinelle et
## réactions partagées (voir Élias, entendre un bruit).

## La Sentinelle (même objet que « actor », mais typé pour l'autocomplétion).
var sentinel: Sentinel:
	get:
		return actor as Sentinel


## Un bruit a été entendu pendant cet état. Par défaut : elle s'alerte et se
## tourne vers lui (état Suspicious). Les états déjà en alerte redéfinissent ceci.
func on_noise(at: Vector2) -> void:
	machine.transition_to(&"Suspicious", {"clue": at})


## Si elle voit Élias, elle passe au combat. Renvoie vrai si c'est le cas.
func check_sight() -> bool:
	if sentinel.sees_target:
		machine.transition_to(&"Combat")
		return true
	return false
