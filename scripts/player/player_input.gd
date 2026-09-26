class_name PlayerInput
extends RefCounted
## Les intentions du joueur, lues une fois par pas de physique.
##
## Les états du personnage ne lisent jamais le clavier directement : ils
## interrogent cet objet (« veut-il aller à droite ? a-t-il appuyé sur saut
## récemment ? »). Trois avantages :
##   1. un seul endroit connaît les touches (remappage, manette) ;
##   2. les tests automatiques pilotent Élias en remplissant cet objet ;
##   3. le fantôme du mode chrono (J9) pourra rejouer des intentions enregistrées.
##
## Le « tampon d'entrée » : chaque appui est daté. Un état qui démarre peut
## demander « saut a-t-il été pressé dans les 0,2 dernières secondes ? » et
## ainsi exécuter une commande donnée pendant l'animation précédente.

## Si faux, l'objet n'est pas mis à jour par les périphériques (tests, fantôme).
var from_devices: bool = true

## Direction horizontale voulue : -1 (gauche), 0, +1 (droite).
var move: int = 0
var up: bool = false
var down: bool = false
var run: bool = false
## Détente maintenue (tir chargé) et bouclier maintenu (J3).
var fire: bool = false
var shield: bool = false
## Touche « Ordre » maintenue (compagnon, J7) : court = suivre/attendre, long = activer.
var order: bool = false

## Horloge interne (secondes) et date du dernier appui de chaque commande.
var _clock: float = 0.0
var _pressed_at: Dictionary = {}   # action -> date
var _consumed: Dictionary = {}     # action -> date de l'appui déjà utilisé

## Commandes « à impulsion » suivies par le tampon.
const BUFFERED: Array[StringName] = [&"jump", &"roll", &"move_up", &"move_down", &"interact", &"fire", &"shield", &"throw"]


## Lit clavier et manette (appelé par le joueur à chaque pas de physique).
func update(delta: float) -> void:
	_clock += delta
	if not from_devices:
		return
	var axis: float = Input.get_axis(&"move_left", &"move_right")
	move = 0 if absf(axis) < 0.3 else int(signf(axis))
	up = Input.is_action_pressed(&"move_up")
	down = Input.is_action_pressed(&"move_down")
	run = Input.is_action_pressed(&"run")
	fire = Input.is_action_pressed(&"fire")
	shield = Input.is_action_pressed(&"shield")
	order = Input.is_action_pressed(&"order")
	for action in BUFFERED:
		if Input.is_action_just_pressed(action):
			_pressed_at[action] = _clock


## Simule un appui (tests, fantôme, compagnon…).
func press(action: StringName) -> void:
	_pressed_at[action] = _clock


## Vrai si « action » a été pressée il y a moins de « window » secondes et que
## cet appui n'a pas encore été utilisé. L'appui est alors « consommé ».
func consume(action: StringName, window: float) -> bool:
	if not _pressed_at.has(action):
		return false
	var pressed: float = _pressed_at[action]
	if _consumed.get(action, -1.0) == pressed:
		return false
	# Petite marge : un appui fait pendant le pas de physique courant compte toujours.
	if _clock - pressed > window + 0.0001:
		return false
	_consumed[action] = pressed
	return true


## Oublie tous les appuis en attente (après une mort, un changement de scène…).
func clear() -> void:
	_pressed_at.clear()
	_consumed.clear()
	move = 0
	up = false
	down = false
	run = false
	fire = false
	shield = false
	order = false
