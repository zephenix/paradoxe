class_name TimeTrialConfig
extends Resource
## Réglages du mode chrono (J9, PLAN §5.8) : resources/time_trial.tres.

## Photos du passage par seconde (pour le fantôme).
@export var sample_rate: float = 20.0
## Couleur du fantôme (l'alpha règle sa transparence).
@export var ghost_color: Color = Color(0.55, 1.0, 0.9, 0.4)
## Fichier du meilleur passage.
@export var best_path: String = "user://ghost_best.res"
