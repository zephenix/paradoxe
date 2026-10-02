class_name BraceletConfig
extends Resource
## Réglages de l'hologramme du bracelet (J9, PLAN §5.10) :
## resources/player/bracelet.tres.

## Durée d'affichage complet après un appui sur « Bracelet » (secondes).
@export var show_time: float = 4.0
## Durée d'un affichage bref, une seule ligne (pierre ramassée, tir…).
@export var brief_time: float = 1.6
## Fondu de disparition (secondes).
@export var fade_time: float = 0.35
## Temps pour que l'hologramme se déplie au-dessus du poignet (secondes).
@export var unfold_time: float = 0.15
## Hauteur du bas de l'hologramme au-dessus des pieds d'Élias (pixels).
@export var height: float = 132.0
## En deçà de cette distance (pixels), l'objectif est « ici » : un cercle
## remplace la flèche.
@export var objective_near: float = 90.0
