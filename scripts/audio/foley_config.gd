class_name FoleyConfig
extends Resource
## Réglages des bruitages d'Élias (PlayerFoley) : resources/audio/foley.tres.
##
## Le son lui-même (fichiers, volume de base, rayon de bruit d'un pas de COURSE)
## est réglé dans la bibliothèque de sons. Ici, on règle ce qui dépend de
## l'ALLURE : un pas de marche est plus doux et s'entend moins loin qu'un pas de
## course, un pas accroupi ne s'entend pas du tout.

@export_group("Pas selon l'allure")
## Décalage de volume (dB) et part du rayon de bruit (0 = muet pour les ennemis,
## 1 = rayon de la bibliothèque) pour chaque allure.
@export var walk_volume_db: float = -6.0
@export_range(0.0, 2.0, 0.05) var walk_noise: float = 0.6
@export var run_volume_db: float = 0.0
@export_range(0.0, 2.0, 0.05) var run_noise: float = 1.0
@export var soft_volume_db: float = -18.0
@export_range(0.0, 2.0, 0.05) var soft_noise: float = 0.0
## Genou posé en se hissant sur un rebord.
@export var knee_volume_db: float = -8.0
@export_range(0.0, 2.0, 0.05) var knee_noise: float = 0.3
## Profondeur (pixels) sous les pieds où l'on cherche la nature du sol.
@export var surface_probe: float = 16.0
## Surface par défaut (sol qui ne précise rien).
@export var default_surface: StringName = &"stone"

@export_group("Effort et respiration")
## L'effort va de 0 (reposé) à 1 (épuisé). Il monte en courant et à chaque
## geste fatigant, et redescend au repos.
@export var effort_run_per_second: float = 0.07
@export var effort_jump: float = 0.05
@export var effort_climb: float = 0.1
@export var effort_roll: float = 0.05
@export var effort_land_heavy: float = 0.08
@export var effort_decay_per_second: float = 0.05
## Seuils : au-dessus de effort_tier, respiration d'effort ; au-dessus de
## exhausted_tier, essoufflement.
@export_range(0.0, 1.0, 0.05) var effort_tier: float = 0.35
@export_range(0.0, 1.0, 0.05) var exhausted_tier: float = 0.7
## Intervalle entre deux respirations (secondes) pour chaque palier.
@export var breath_interval_calm: float = 4.5
@export var breath_interval_effort: float = 1.9
@export var breath_interval_exhausted: float = 1.2
## Variation aléatoire de l'intervalle (± secondes).
@export var breath_interval_jitter: float = 0.3


## Décalage de volume (dB) d'une allure : &"walk", &"run", &"soft", &"knee".
func gait_volume_db(gait: StringName) -> float:
	match gait:
		&"walk": return walk_volume_db
		&"run": return run_volume_db
		&"soft": return soft_volume_db
		&"knee": return knee_volume_db
	return 0.0


## Part du rayon de bruit d'une allure.
func gait_noise(gait: StringName) -> float:
	match gait:
		&"walk": return walk_noise
		&"run": return run_noise
		&"soft": return soft_noise
		&"knee": return knee_noise
	return 1.0


## Gain d'effort d'un évènement (0 si l'évènement ne fatigue pas).
func effort_of(event_name: StringName) -> float:
	match event_name:
		&"jump": return effort_jump
		&"climb": return effort_climb
		&"roll": return effort_roll
		&"land_heavy": return effort_land_heavy
	return 0.0
