class_name RewindConfig
extends Resource
## Réglages du rembobinage temporel (fichier resources/rewind.tres, PLAN §5.5).

@export_group("Enregistrement")
## Durée d'historique gardée en mémoire (secondes) : on ne peut pas remonter plus loin.
@export var history_seconds: float = 5.0
## Nombre de « photos » de l'état du monde par seconde.
@export var captures_per_second: float = 30.0

@export_group("Utilisation")
## Nombre de rembobinages possibles depuis le dernier checkpoint.
@export var uses_per_checkpoint: int = 3
## Vitesse du défilement arrière : secondes d'historique remontées par seconde réelle.
@export var rewind_speed: float = 1.5
## Il faut remonter au moins ce temps (secondes) pour que le rembobinage compte :
## relâcher trop tôt ne consomme rien.
@export var min_rewind: float = 0.3

@export_group("Mort")
## Ralenti à la mort : vitesse du jeu (0,25 = quatre fois plus lent) et durée
## (en secondes réelles), avant que le temps se fige et que le choix apparaisse.
@export var slowmo_scale: float = 0.25
@export var slowmo_duration: float = 0.6

@export_group("Effets")
## Étouffement du son pendant le défilement arrière (0 = aucun, 1 = maximal).
@export_range(0.0, 1.0) var muffle: float = 0.75
