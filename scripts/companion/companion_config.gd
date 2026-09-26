class_name CompanionConfig
extends Resource
## Réglages du compagnon (J7) : resources/characters/companion.tres.

@export_group("Déplacement")
@export var walk_speed: float = 110.0
@export var run_speed: float = 250.0
@export var acceleration: float = 1200.0
@export var gravity: float = 2000.0
@export var max_fall_speed: float = 1200.0
## Il ne descend pas une marche plus haute que ceci (blocs) : il s'arrête au bord.
@export var max_step_down_blocks: float = 1.0
@export var walk_cycle_duration: float = 1.1
@export var run_cycle_duration: float = 0.6

@export_group("Suivre")
## Distance à laquelle il se tient d'Élias (pixels).
@export var follow_distance: float = 72.0
## Au-delà, il court pour le rattraper.
@export var run_distance: float = 260.0
## Écart de hauteur au-delà duquel Élias est « à un autre étage » : le
## compagnon cherche alors un ascenseur à son niveau et monte dessus.
@export var other_floor_height: float = 64.0

@export_group("Ordres")
## Appui plus long que ceci sur « Ordre » : « Active ça » (sinon : suivre / attendre).
@export var long_press_time: float = 0.45
## Distance maximale entre Élias et le mécanisme désigné (pixels).
@export var order_range: float = 340.0
## Distance à laquelle il s'arrête devant le mécanisme à actionner.
@export var activate_reach: float = 14.0
## Durée du geste pour actionner, et instant où la main touche l'objet.
@export var activate_duration: float = 0.35
@export var activate_time: float = 0.15
## Durée d'un geste de réponse (d'accord, j'attends, je te suis).
@export var gesture_time: float = 0.8

@export_group("Silhouette (collisions)")
@export var body_width: float = 24.0
@export var body_height: float = 94.0
