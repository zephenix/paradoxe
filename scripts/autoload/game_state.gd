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
## Remis au maximum (rewind.tres) à chaque nouveau checkpoint, à chaque
## réapparition et en début de partie.
var rewinds_left: int = 0

## Objets possédés, par identifiant (J7).
var inventory: Array[StringName] = []
## Élias a-t-il perdu son arme (J7 : confisquée à la capture, écran 4) ? Il la
## retrouve en ramassant l'objet « pistol ». Par défaut, il est armé.
var unarmed: bool = false

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
	reset_rewinds()
	Events.checkpoint_reached.emit(id)
	return true


## Rend toutes les utilisations du rembobinage (voir resources/rewind.tres).
func reset_rewinds() -> void:
	rewinds_left = RewindManager.config.uses_per_checkpoint


## Remet l'état à zéro pour une nouvelle partie.
func new_game() -> void:
	checkpoint_id = &""
	checkpoint_position = Vector2.ZERO
	checkpoint_facing = 1
	reset_rewinds()
	inventory.clear()
	unarmed = false


# --------------------------------------------------------------------------
# Inventaire (J7)
# --------------------------------------------------------------------------

## Vrai si Élias possède l'objet « item ».
func has_item(item: StringName) -> bool:
	return inventory.has(item)


## Ajoute un objet. Ramasser son arme (« pistol ») la lui rend.
func add_item(item: StringName) -> void:
	if not inventory.has(item):
		inventory.append(item)
	if item == &"pistol":
		unarmed = false


## Retire un objet (rembobinage d'un ramassage, confiscation…).
func remove_item(item: StringName) -> void:
	inventory.erase(item)
	if item == &"pistol":
		unarmed = true
