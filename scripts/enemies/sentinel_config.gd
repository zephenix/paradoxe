class_name SentinelConfig
extends Resource
## Réglages d'une Sentinelle (fichier resources/enemies/sentinel.tres).
##
## Ouvrir le .tres dans l'éditeur Godot : l'inspecteur montre tous les réglages
## ci-dessous, groupés. Les nombres de CE script sont les valeurs par défaut.
## Les distances sont en pixels (1 bloc = 48 px), les durées en secondes.
## L'arme et la jauge d'énergie ont leurs propres fichiers
## (resources/weapons/sentinel_gun.tres, resources/enemies/sentinel_energy.tres).

@export_group("Déplacement")
## Vitesse de marche (patrouille, recherche) et de course (poursuite).
@export var walk_speed: float = 70.0
@export var run_speed: float = 180.0
## Accélération et freinage au sol (pixels par seconde²).
@export var acceleration: float = 900.0
## Gravité et vitesse de chute maximale (comme Élias).
@export var gravity: float = 2000.0
@export var max_fall_speed: float = 1200.0
## Une Sentinelle ne descend pas une marche plus haute que ceci (en blocs) :
## elle s'arrête au bord des plates-formes au lieu de tomber.
@export var max_step_down_blocks: float = 1.0
## Durée d'un cycle de l'animation de marche / de course : à régler avec la
## vitesse pour que les pieds ne glissent pas sur le sol.
@export var walk_cycle_duration: float = 1.7
@export var run_cycle_duration: float = 0.7

@export_group("Patrouille")
## Pause à chaque bout du trajet de patrouille.
@export var patrol_pause: float = 1.2

@export_group("Vue")
## Distance maximale à laquelle elle voit Élias, devant elle.
@export var view_distance: float = 620.0
## Écart de hauteur maximal (pixels) : elle ne voit pas un étage plus haut ou plus bas.
@export var view_height: float = 120.0
## Demi-angle du cône de vision (degrés), de part et d'autre de son regard.
@export_range(5.0, 90.0, 1.0) var view_half_angle: float = 35.0
## Hauteur de ses yeux au-dessus de ses pieds.
@export var eye_height: float = 80.0
## Temps de réaction entre le moment où elle voit Élias et son premier geste.
@export var reaction_time: float = 0.4

@export_group("Lumière et suspicion (J6)")
## Ce qu'elle perçoit d'Élias (« visibilité », de 0 à 1) =
##     lumière sur Élias × (crouch_visibility s'il est accroupi) × facteur de distance,
## où le facteur de distance vaut 1 tout près et 0 à view_distance (courbe en
## 1 - (d / view_distance)²). Voir Sentinel.visibility_of().
## Accroupi, Élias est moins visible (0,6 = 60 % de sa visibilité debout).
@export_range(0.0, 1.0, 0.05) var crouch_visibility: float = 0.6
## Tout près (pixels), elle le remarque même dans le noir.
@export var close_distance: float = 90.0
## Visibilité à partir de laquelle elle le reconnaît immédiatement (combat).
@export_range(0.0, 1.0, 0.05) var clear_sight: float = 0.35
## En dessous de clear_sight, la suspicion monte de visibilité × sight_gain par seconde.
@export var sight_gain: float = 3.0
## Visibilité minimale pour garder Élias « en vue » pendant un combat.
@export_range(0.0, 1.0, 0.01) var track_visibility: float = 0.04
## Seuils de la jauge de suspicion (0 à 1) : alerte (elle s'arrête et regarde),
## puis recherche (elle va voir) à la fin de l'alerte. À 1 : combat, si elle le voit.
@export_range(0.0, 1.0, 0.05) var suspicious_threshold: float = 0.25
@export_range(0.0, 1.0, 0.05) var search_threshold: float = 0.5
## La suspicion retombe de tant par seconde quand rien ne l'alimente.
@export var suspicion_decay: float = 0.08

@export_group("Ouïe")
## Multiplie le rayon des bruits entendus (1 = normal, 0 = sourde).
@export var hearing_factor: float = 1.0
## Chaque mur entre le bruit et elle multiplie le rayon par ce facteur (J6).
@export_range(0.0, 1.0, 0.05) var wall_attenuation: float = 0.5
## Suspicion apportée par un bruit : noise_suspicion_far au bord du rayon,
## noise_suspicion_near tout près de la source.
@export_range(0.0, 1.0, 0.05) var noise_suspicion_far: float = 0.3
@export_range(0.0, 1.0, 0.05) var noise_suspicion_near: float = 0.8

@export_group("Alerte et recherche")
## Durée de l'alerte (elle s'arrête, se tourne vers le bruit) avant d'aller voir.
@export var suspicious_duration: float = 1.4
## Durée de la recherche avant de reprendre la patrouille.
@export var search_duration: float = 4.0
## Pendant la recherche, elle se retourne à cet intervalle pour regarder autour.
@export var search_look_interval: float = 1.2
## Durée de la poursuite (vers le dernier endroit où elle a vu Élias).
@export var chase_duration: float = 5.0

@export_group("Combat")
## Temps de visée avant chaque tir : c'est l'avertissement pour le joueur.
@export var aim_time: float = 0.55
## Pause entre la fin d'un tir et la visée suivante.
@export var fire_pause: float = 0.7
## Distance qu'elle cherche à garder avec Élias (elle s'approche si plus loin).
@export var preferred_distance: float = 380.0
## Temps sans voir Élias avant de passer à la poursuite.
@export var lose_sight_time: float = 1.0

@export_group("Bouclier")
## Probabilité de lever le bouclier face à un tir (0 = jamais, 1 = toujours).
@export_range(0.0, 1.0) var shield_chance: float = 0.7
## Temps de réaction pour lever le bouclier quand un tir arrive.
@export var shield_reaction_time: float = 0.15
## Durée pendant laquelle elle garde le bouclier levé.
@export var shield_hold_time: float = 0.8
## Distance à laquelle elle remarque un tir qui arrive sur elle.
@export var threat_distance: float = 420.0
## Temps pendant lequel elle reste sonnée quand son bouclier tombe (brisé, jauge vide).
@export var stagger_time: float = 0.6

@export_group("Silhouette (collisions)")
@export var body_width: float = 24.0
@export var body_height: float = 92.0
