@tool
class_name Puppet
extends Node2D
## Figurant de cinématique (J7) : un personnage qui ne fait que ce que la
## cinématique lui dit (marcher, se tourner, un geste). Pas d'IA, pas de
## collisions. Il a le même squelette et les mêmes animations que les autres.

## Peau : &"sentinel" (créature) ou &"companion" (vieil homme).
@export var skin: StringName = &"sentinel"
@export_enum("Gauche:-1", "Droite:1") var facing: int = -1:
	set(value):
		facing = 1 if value >= 0 else -1
		if visual:
			visual.set_facing(facing)

var visual: CharacterVisual


func _ready() -> void:
	visual = (CompanionVisual.new() if skin == &"companion" else SentinelVisual.new()) as CharacterVisual
	visual.name = "Visual"
	add_child(visual)
	visual.set_facing(facing)
	visual.play(&"idle")
