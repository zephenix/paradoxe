class_name PlayerMovementConfig
extends Resource
## Réglages du déplacement d'Élias.
##
## Une « Resource » est un objet de données enregistré dans un fichier (.tres),
## que Godot affiche dans l'inspecteur comme une feuille Excel de paramètres.
##
## Comment régler le jeu : ouvrir resources/player/player_movement.tres dans
## l'éditeur Godot (double-clic) ; l'inspecteur montre tous les réglages ci-dessous,
## groupés et commentés. Les nombres écrits dans CE script sont les valeurs PAR
## DÉFAUT. Godot n'enregistre dans le .tres que les réglages qu'on a modifiés :
## un .tres presque vide veut simplement dire « tout est aux valeurs par défaut ».
##
## Unité de base : le BLOC (GameUnits.BLOCK = 48 pixels). Élias mesure 2 blocs.
## Les sauts et les chutes sont exprimés en blocs, et le code en déduit les
## vitesses (voir les fonctions en bas de fichier) : on règle ce qu'on veut
## obtenir (« un saut avec élan franchit 4 blocs »), pas une vitesse abstraite.

@export_group("Gravité")
## Gravité en pixels par seconde² (plus fort = sauts plus courts et plus secs).
@export var gravity: float = 2000.0
## Vitesse de chute maximale (pixels par seconde).
@export var max_fall_speed: float = 1200.0

@export_group("Marche et course")
## Vitesse de marche (pixels par seconde).
@export var walk_speed: float = 125.0
## Vitesse de course.
@export var run_speed: float = 285.0
## Vitesse de marche accroupie (silencieuse, J6).
@export var crouch_walk_speed: float = 60.0
## Accélération au sol (pixels par seconde²) : plus bas = démarrage plus lourd.
@export var ground_acceleration: float = 1400.0
## Freinage au sol quand on relâche la direction.
@export var ground_deceleration: float = 2000.0
## Élan : fraction de la vitesse de course à atteindre avant de pouvoir faire un
## saut avec élan, une glissade ou un dérapage (sinon : saut sans élan, accroupi, arrêt).
@export_range(0.0, 1.0) var momentum_threshold: float = 0.75
## Durée d'un demi-tour à l'arrêt ou en marchant (secondes).
@export var turn_duration: float = 0.16
## Durée d'un dérapage (arrêt ou demi-tour en pleine course).
@export var skid_duration: float = 0.3

@export_group("Sauts (en blocs)")
## Saut vertical sur place : hauteur gagnée par les pieds.
@export var vertical_jump_height_blocks: float = 1.0
## Saut sans élan (en marchant) : hauteur et longueur.
@export var standing_jump_height_blocks: float = 0.9
@export var standing_jump_distance_blocks: float = 2.0
## Saut avec élan (en courant) : hauteur et longueur.
@export var running_jump_height_blocks: float = 1.0
@export var running_jump_distance_blocks: float = 4.0
## Temps d'impulsion avant de quitter le sol (secondes) : le personnage plie
## les genoux, c'est ce qui rend le saut « engagé ».
@export var jump_windup: float = 0.1

@export_group("Chutes et réceptions")
## Jusqu'à cette hauteur (en blocs), atterrissage sans conséquence.
@export var safe_fall_blocks: float = 3.0
## Entre safe_fall_blocks et cette hauteur : roulade de réception obligatoire.
## Au-delà : chute mortelle. La hauteur se mesure depuis le point le plus haut
## atteint : la hauteur d'un saut s'ajoute donc à celle de la chute.
@export var deadly_fall_blocks: float = 5.0
## À partir de quelle hauteur (en blocs) un atterrissage est « lourd ».
@export var heavy_land_blocks: float = 2.0
## Temps de récupération d'un atterrissage léger (secondes).
@export var land_recovery: float = 0.12
## Temps de récupération d'un atterrissage lourd.
@export var heavy_land_recovery: float = 0.45
## Freinage à la réception (pixels par seconde²) : évite de glisser loin après un saut.
@export var land_friction: float = 3000.0
## Temps sans sol (secondes) au-delà duquel un personnage « au sol » passe en
## chute. Environ une image : absorbe le premier instant après l'apparition, où
## le moteur n'a pas encore détecté le sol.
@export var ground_tolerance: float = 0.02

@export_group("Rebords")
## Hauteur des mains au-dessus des pieds quand Élias est suspendu (pixels).
@export var hang_hand_height: float = 104.0
## Distance max (pixels) entre les mains et le haut du rebord pour l'attraper.
@export var grab_tolerance: float = 18.0
## Portée horizontale des mains au-delà du corps (pixels).
@export var grab_reach: float = 14.0
## Rebord le plus haut (en blocs au-dessus des pieds) qu'on franchit directement
## avec « Haut », sans sauter : les mains y arrivent depuis le sol. Au-dessus,
## « Haut » fait un saut sur place qui s'accroche au rebord.
@export var step_climb_max_blocks: float = 2.6
## Hauteur minimale (pixels) d'une marche : en dessous, c'est une simple bosse du sol.
@export var step_min_height: float = 8.0
## Durée pour se hisser sur un rebord à hauteur de mains (secondes). Une marche
## plus basse se franchit plus vite, sans descendre sous climb_min_duration_factor.
@export var climb_duration: float = 0.62
@export_range(0.1, 1.0) var climb_min_duration_factor: float = 0.45
## Durée pour descendre d'un rebord jusqu'à la suspension.
@export var descend_duration: float = 0.5
## Suspendu : temps pendant lequel « Haut » doit rester maintenu pour se hisser
## (un simple appui suffit aussi).
@export var hang_hold_to_climb: float = 0.25
## Après avoir lâché un rebord : délai pendant lequel on ne peut pas s'y raccrocher.
@export var regrab_cooldown: float = 0.35

@export_group("Interactions (J7)")
## Portée de la main : un objet interactif à moins de tant de pixels devant les
## pieds d'Élias réagit à « Interagir ».
@export var interact_reach: float = 44.0
## Durée du geste (engagé) et instant où la main touche l'objet.
@export var interact_duration: float = 0.35
@export var interact_time: float = 0.15

@export_group("Roulade et glissade")
## Distance parcourue par une roulade (en blocs) et sa durée (secondes).
@export var roll_distance_blocks: float = 2.5
@export var roll_duration: float = 0.5
## Ralentissement de la roulade : 0 = vitesse constante, 0.4 = finit à 60 % de sa vitesse.
@export_range(0.0, 0.9) var roll_slowdown: float = 0.4
## Fenêtre d'invulnérabilité de la roulade d'esquive (début, fin), en fraction de sa durée.
@export var roll_invulnerable_window: Vector2 = Vector2(0.1, 0.7)
## Vitesse de départ de la glissade (en fraction de la vitesse de course) et son freinage.
@export var slide_speed_factor: float = 1.15
@export var slide_friction: float = 300.0
## Durée minimale d'une glissade (secondes).
@export var slide_min_duration: float = 0.35

@export_group("Confort de jeu (désactivé en mode classique)")
## Tampon d'entrée : une commande pressée pendant une animation engagée est
## mémorisée ce temps-là (secondes) et exécutée dès que possible.
@export var input_buffer_time: float = 0.2
## En mode classique, fenêtre d'un appui (secondes) : juste de quoi ne pas perdre
## une commande pressée entre deux pas de physique.
@export var classic_input_window: float = 0.02
## « Temps du coyote » : on peut encore sauter un court instant après avoir
## quitté un bord. Fenêtre réelle : ce temps + ground_tolerance.
@export var coyote_time: float = 0.08
## En marchant, Élias s'arrête au bord d'un vide dangereux au lieu de tomber.
@export var edge_guard: bool = true
## Distance (pixels) devant les pieds à laquelle le garde-bord regarde le vide.
@export var edge_guard_lookahead: float = 6.0

@export_group("Silhouette (collisions)")
## Largeur et hauteur de la boîte de collision debout / accroupi (pixels).
@export var body_width: float = 24.0
@export var stand_height: float = 90.0
@export var crouch_height: float = 58.0


# --------------------------------------------------------------------------
# Valeurs calculées (on ne les règle pas, on les déduit des réglages ci-dessus)
# --------------------------------------------------------------------------

## Convertit des blocs en pixels.
func blocks(count: float) -> float:
	return count * GameUnits.BLOCK


## Vitesse verticale de départ pour monter de « height » pixels :
## v = √(2·g·h)  (formule de la chute libre, à l'envers).
func takeoff_speed_for_height(height: float) -> float:
	return sqrt(2.0 * gravity * height)


## Durée en l'air d'un saut qui part et retombe au même niveau : t = 2·v / g.
func airtime_for_height(height: float) -> float:
	return 2.0 * takeoff_speed_for_height(height) / gravity


## Vitesse (x, y) d'un saut de hauteur et de longueur données (en blocs).
## x est positif : on le multiplie ensuite par le sens du regard.
## y est négatif : en 2D dans Godot, l'axe vertical pointe vers le BAS.
func jump_velocity(height_blocks: float, distance_blocks: float) -> Vector2:
	var height: float = blocks(height_blocks)
	var vy: float = takeoff_speed_for_height(height)
	var vx: float = blocks(distance_blocks) / airtime_for_height(height)
	return Vector2(vx, -vy)


func vertical_jump_velocity() -> Vector2:
	return Vector2(0.0, -takeoff_speed_for_height(blocks(vertical_jump_height_blocks)))


func standing_jump_velocity() -> Vector2:
	return jump_velocity(standing_jump_height_blocks, standing_jump_distance_blocks)


func running_jump_velocity() -> Vector2:
	return jump_velocity(running_jump_height_blocks, running_jump_distance_blocks)


## Vitesse de départ d'une roulade. Elle ralentit linéairement de roll_slowdown
## au cours de la roulade ; sa vitesse moyenne vaut donc v × (1 − roll_slowdown / 2),
## d'où la division ci-dessous pour parcourir exactement roll_distance_blocks.
func roll_speed() -> float:
	return blocks(roll_distance_blocks) / (roll_duration * (1.0 - roll_slowdown * 0.5))


## Vitesse au-delà de laquelle on considère qu'Élias a de l'élan.
func momentum_speed() -> float:
	return run_speed * momentum_threshold
