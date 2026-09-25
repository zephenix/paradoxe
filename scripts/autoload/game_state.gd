extends Node
## État de la partie en cours (autoload « GameState »).
##
## Ce qui doit survivre d'une salle à l'autre ou d'une mort à l'autre vit ici :
## checkpoint actif, inventaire, rembobinages restants, mode chrono…
## Les réglages permanents du joueur, eux, sont dans Settings.
##
## J1 : squelette. Les champs se remplissent au fil des jalons.

## Dernier checkpoint atteint (J3) : identifiant, position des pieds d'Élias à
## la réapparition, et sens du regard. Identifiant vide = aucun checkpoint.
var checkpoint_id: StringName = &""
var checkpoint_position: Vector2 = Vector2.ZERO
var checkpoint_facing: int = 1

## Nombre de rembobinages encore disponibles depuis le dernier checkpoint (J4).
var rewinds_left: int = 0

## Objets possédés, par identifiant (J7).
var inventory: Array[StringName] = []

## Partie en mode chrono (J9).
var time_trial: bool = false


func _ready() -> void:
	# Numéro de version dans la console (utile pour vérifier quelle version tourne,
	# notamment sur le Web où le navigateur peut garder une ancienne version en cache).
	print("PARADOXE v%s" % ProjectSettings.get_setting("application/config/version"))


## Le mode classique est un réglage du joueur ; on le relit ici pour que le
## code du gameplay n'ait qu'un seul endroit à interroger.
func is_classic_mode() -> bool:
	return Settings.classic_mode


## Vrai si un checkpoint a été atteint depuis le début de la partie.
func has_checkpoint() -> bool:
	return checkpoint_id != &""


## Enregistre un checkpoint. Renvoie vrai (et émet Events.checkpoint_reached)
## seulement s'il est nouveau : repasser sur le checkpoint actif ne fait rien.
## (J4 : c'est aussi ici que les rembobinages disponibles seront remis à 3.)
func reach_checkpoint(id: StringName, at: Vector2, facing: int) -> bool:
	if id == checkpoint_id:
		return false
	checkpoint_id = id
	checkpoint_position = at
	checkpoint_facing = 1 if facing >= 0 else -1
	Events.checkpoint_reached.emit(id)
	return true


## Remet l'état à zéro pour une nouvelle partie.
func new_game() -> void:
	checkpoint_id = &""
	checkpoint_position = Vector2.ZERO
	checkpoint_facing = 1
	rewinds_left = 0
	inventory.clear()
