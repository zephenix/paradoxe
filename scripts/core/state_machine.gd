class_name StateMachine
extends Node
## Machine à états générique (joueur, ennemis, compagnon).
##
## Principe : un personnage est toujours dans UN état (à l'arrêt, en course,
## en saut…). Chaque état est un nœud enfant avec son script, qui contient
## uniquement la logique de cet état et les règles pour en sortir.
##
## Analogie VBA : au lieu d'un énorme « Select Case etat » dans une seule
## procédure, chaque « Case » devient un module séparé, avec ses propres
## procédures d'entrée et de sortie. On ajoute un état sans toucher aux autres.
##
## Utilisation :
##     machine.setup(joueur)              # une fois, au démarrage
##     machine.physics_update(delta)      # à chaque pas de physique
##
## Les états ne reçoivent pas les évènements clavier : ils lisent les intentions
## du personnage (PlayerInput pour Élias), mises à jour une fois par pas de physique.
##     machine.transition_to(&"Jump", {"kind": &"running"})

## Émis à chaque changement d'état (utile pour le débogage et les tests).
signal state_changed(from: StringName, to: StringName)

## État de départ (nom d'un nœud enfant).
@export var initial_state: StringName = &"Idle"

## État actif.
var current: State
## Nom de l'état actif (&"" avant setup).
var current_name: StringName = &""
## Nom de l'état précédent.
var previous_name: StringName = &""

var _states: Dictionary = {}  # nom -> State
## Vrai pendant un changement d'état (exit / enter en cours).
var _in_transition: bool = false
## Changements demandés PENDANT un autre changement (par exemple depuis enter()) :
## ils sont exécutés juste après, dans l'ordre, pour que les signaux restent justes.
var _pending: Array[Array] = []


## Relie les états à l'objet contrôlé et entre dans l'état initial.
func setup(controlled: Node) -> void:
	_states.clear()
	for child in get_children():
		if child is State:
			var state: State = child
			state.machine = self
			state.actor = controlled
			_states[StringName(child.name)] = state
	assert(_states.has(initial_state), "État initial introuvable : %s" % initial_state)
	current_name = &""
	transition_to(initial_state)


## Passe dans l'état « target » (nom d'un nœud enfant). « data » permet de
## transmettre des précisions, par exemple le type de saut.
func transition_to(target: StringName, data: Dictionary = {}) -> void:
	if not _states.has(target):
		push_error("StateMachine : état inconnu « %s »" % target)
		return
	if _in_transition:
		_pending.append([target, data])
		return
	_switch(target, data)
	while not _pending.is_empty():
		var next: Array = _pending.pop_front()
		_switch(next[0], next[1])


func physics_update(delta: float) -> void:
	if current:
		current.time_in_state += delta
		current.physics_update(delta)


func has_state(state_name: StringName) -> bool:
	return _states.has(state_name)


func is_in(state_name: StringName) -> bool:
	return current_name == state_name


## Vrai si l'état actif est engagé (voir State.is_committed). Servira aux
## systèmes qui voudraient interrompre le personnage (dégâts, cinématiques…).
func is_committed() -> bool:
	return current != null and current.is_committed()


## Effectue un changement d'état : sortie de l'ancien, entrée dans le nouveau,
## puis signal. Un changement demandé pendant ce temps est mis en file.
func _switch(target: StringName, data: Dictionary) -> void:
	_in_transition = true
	var from: StringName = current_name
	if current:
		current.exit()
	previous_name = from
	current = _states[target]
	current_name = target
	current.time_in_state = 0.0
	current.enter(from, data)
	state_changed.emit(from, target)
	_in_transition = false
