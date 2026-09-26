class_name CompanionState
extends State
## Base des états du compagnon : accès typé au compagnon.

var companion: Companion:
	get:
		return actor as Companion
