class_name MusicConfig
extends Resource
## Réglages de la musique adaptative (J8, PLAN §6.7). Fichier :
## resources/audio/music.tres (modifiable dans l'inspecteur de Godot).
##
## La musique de TENSION est faite de couches jouées ensemble, en boucle et
## parfaitement calées (même durée). Chaque couche a une plage de niveau d'alerte :
## sous le début de la plage, elle se tait ; au-dessus de la fin, elle joue à
## plein volume ; entre les deux, elle monte progressivement.
##
## Analogie Excel : pour chaque couche, une cellule « volume » = une formule
## qui transforme le niveau d'alerte (0 à 1) en un pourcentage, avec deux seuils.

@export_group("Couches de tension")
## Sons en boucle de la bibliothèque, de la plus douce à la plus intense.
@export var tension_layers: Array[StringName] = [&"mus_tension_pad", &"mus_tension_pulse", &"mus_tension_perc"]
## Plage de niveau d'alerte de chaque couche : x = elle commence à monter,
## y = elle est au maximum. Même ordre que tension_layers.
@export var layer_ranges: Array[Vector2] = [Vector2(0.1, 0.4), Vector2(0.45, 0.75), Vector2(0.9, 1.0)]
## Temps pour qu'une couche monte de 0 au maximum (secondes).
@export var rise_time: float = 1.5
## Temps pour qu'elle redescende du maximum à 0 : plus lent, la tension retombe
## doucement après une alerte (secondes).
@export var fall_time: float = 5.0
## Après ce délai de silence complet, les couches s'arrêtent (économie) ; elles
## repartent du début à la prochaine alerte (secondes).
@export var stop_after: float = 4.0

@export_group("Thèmes")
## Vrai : la tension se tait pendant un thème (arrivée, poursuite…) pour ne
## pas mélanger deux musiques.
@export var duck_tension_under_theme: bool = true
## Fondu d'entrée par défaut d'un thème (secondes).
@export var theme_fade_in: float = 0.0
