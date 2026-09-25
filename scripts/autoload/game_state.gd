extends Node
## État de la partie en cours (autoload « GameState »).
##
## Ce qui doit survivre d'une salle à l'autre ou d'une mort à l'autre vit ici :
## checkpoint actif, inventaire, rembobinages restants, mode chrono…
## Les réglages permanents du joueur, eux, sont dans Settings.
##
## J1 : squelette. Les champs se remplissent au fil des jalons.

## Identifiant du dernier checkpoint atteint (J3).
var checkpoint_id: StringName = &""

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


## Remet l'état à zéro pour une nouvelle partie.
func new_game() -> void:
	checkpoint_id = &""
	rewinds_left = 0
	inventory.clear()
