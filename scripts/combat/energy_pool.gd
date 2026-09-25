class_name EnergyPool
extends Node
## Jauge d'énergie d'un personnage (Élias ou une Sentinelle).
##
## Deux façons de consommer :
##   - try_spend(coût)            une fois (un tir) : refusé si la jauge n'a pas assez ;
##   - drain(débit, delta)        en continu (le bouclier), à chaque pas de physique.
## Toute consommation relance le délai avant recharge.
##
## Analogie Excel : une cellule « solde » qu'on débite ; si elle n'a pas été
## débitée depuis recharge_delay secondes, elle se recrédite petit à petit
## jusqu'au plafond (capacity).

## La valeur a changé (sert à l'affichage : lueur du bracelet, jauge).
signal changed(value: float, capacity: float)
## La jauge vient de tomber à zéro.
signal depleted

## Réglages (capacité, recharge, coûts).
@export var config: EnergyConfig = preload("res://resources/player/energy.tres")

## Énergie disponible (de 0 à config.capacity).
var value: float = 0.0
## Temps écoulé depuis la dernière consommation (secondes).
var idle_time: float = 0.0


func _ready() -> void:
	value = config.capacity
	idle_time = config.recharge_delay


func _physics_process(delta: float) -> void:
	tick(delta)


## Fait avancer le temps : recharge si rien n'a été consommé depuis assez longtemps.
func tick(delta: float) -> void:
	idle_time += delta
	if idle_time >= config.recharge_delay and value < config.capacity:
		_set_value(minf(value + config.recharge_rate * delta, config.capacity))


## Vrai si la jauge contient au moins « amount » unités.
func can_spend(amount: float) -> bool:
	# Petite marge : 0,1 + 0,2 ne fait pas exactement 0,3 pour un ordinateur.
	return value >= amount - 0.0001


## Consomme « amount » d'un coup (un tir). Renvoie faux, sans rien consommer,
## si la jauge n'a pas assez d'énergie.
func try_spend(amount: float) -> bool:
	if not can_spend(amount):
		return false
	idle_time = 0.0
	_set_value(maxf(value - amount, 0.0))
	return true


## Consommation continue (le bouclier) : « rate » unités par seconde pendant
## « delta » secondes. Renvoie faux quand la jauge est vide.
func drain(rate: float, delta: float) -> bool:
	idle_time = 0.0
	if value <= 0.0:
		return false
	_set_value(maxf(value - rate * delta, 0.0))
	return value > 0.0


## Remplit la jauge (réapparition au checkpoint).
func refill() -> void:
	idle_time = config.recharge_delay
	_set_value(config.capacity)


## Photo pour le rembobinage (J4).
func capture_state() -> Dictionary:
	return {"value": value, "idle_time": idle_time}


func apply_state(state: Dictionary) -> void:
	idle_time = state["idle_time"]
	_set_value(state["value"])


## Remplissage de 0 (vide) à 1 (pleine).
func ratio() -> float:
	return value / config.capacity if config.capacity > 0.0 else 0.0


func _set_value(new_value: float) -> void:
	if is_equal_approx(new_value, value):
		value = new_value
		return
	var was_empty: bool = value <= 0.0
	value = new_value
	changed.emit(value, config.capacity)
	if value <= 0.0 and not was_empty:
		depleted.emit()
