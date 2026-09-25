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


## Si elle voit Élias, ou si un tir arrive sur elle DE FACE (elle le voit
## venir), elle passe au combat ; l'état Combat décide alors de lever le
## bouclier. Un tir dans le dos la surprend : elle ne réagit pas.
## Renvoie vrai s'il y a eu transition.
func check_sight() -> bool:
	var s: Sentinel = sentinel
	var incoming: Projectile = s.incoming_projectile()
	var seen_coming: bool = incoming != null and signf(incoming.global_position.x - s.global_position.x) == s.facing
	if seen_coming and not s.sees_target:
		# Elle ne voit pas le tireur, mais sait d'où vient le tir : c'est là
		# qu'elle le cherchera si elle ne le voit toujours pas.
		var shooter: Node2D = incoming.shooter as Node2D
		s.last_seen_position = shooter.global_position if is_instance_valid(shooter) else incoming.global_position
		s.time_since_seen = 0.0
	if s.sees_target or seen_coming:
		machine.transition_to(&"Combat")
		return true
	return false
