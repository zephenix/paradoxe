class_name CharacterVisual
extends Node2D
## Interface « visuel d'un personnage » : ce que les états ont le droit de demander.
##
##   play(nom, durée)     jouer une animation (durée imposée si > 0)
##   set_facing(sens)     regarder à gauche (-1) ou à droite (+1)
##   current              nom de l'animation en cours
##   anim_event(nom)      signal émis à des instants précis (pas, prise…)
##
## Les états ne savent pas comment le personnage est dessiné. Aujourd'hui,
## EliasVisual anime une silhouette en polygones ; demain, une version
## rotoscopée (AnimatedSprite2D) pourra la remplacer : il suffira qu'elle
## respecte ces mêmes fonctions, sans rien changer aux états.

## Émis par les animations à des instants précis (voir les pistes d'évènements).
signal anim_event(event_name: StringName)

## Nom de l'animation en cours.
var current: StringName = &""


## Joue une animation. Si « duration » > 0, sa vitesse est ajustée pour qu'elle
## dure exactement ce temps (les durées de jeu viennent des réglages, pas du dessin).
func play(_animation: StringName, _duration: float = -1.0) -> void:
	pass


func set_facing(_direction: int) -> void:
	pass


## Appelé par les pistes d'évènements des animations.
func emit_anim_event(event_name: StringName) -> void:
	anim_event.emit(event_name)
