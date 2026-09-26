class_name MeetingCutscene
extends Cutscene
## Écran 5, la rencontre (J7, PLAN §4.3) : Élias se réveille dans sa cellule.
## Derrière les barreaux, le prisonnier voisin, un vieil homme, se tourne vers
## lui, le regarde avec stupeur et porte la main à son pendentif en spirale
## (celui de la photo de l'intro). Élias le regarde. Puis la main revient au
## joueur : l'évasion commence.

@export var companion: NodePath


func run(ctx: CutscenePlayer) -> void:
	var elias: Player = get_tree().get_first_node_in_group(&"player") as Player
	var marek: Companion = get_node_or_null(companion) as Companion
	elias.visual.play(&"lie")
	await ctx.wait(0.6)
	await ctx.fade_in(1.4)
	await ctx.wait(0.8)
	# Élias se relève, regarde autour de lui.
	elias.visual.play(&"get_up")
	await ctx.wait(1.4)
	elias.visual.play(&"idle")
	elias.facing = -1
	await ctx.wait(0.8)
	elias.facing = 1
	# Le vieil homme se retourne, stupéfait, et touche son pendentif.
	if marek:
		marek.face_toward(elias.global_position)
		await ctx.wait(0.5)
		marek.visual.play(&"touch_pendant")
		marek.say(&"surprise")
	await ctx.wait(2.2)
	await ctx.wait(0.6)


func finish(_ctx: CutscenePlayer) -> void:
	var elias: Player = get_tree().get_first_node_in_group(&"player") as Player
	var marek: Companion = get_node_or_null(companion) as Companion
	SceneTransition.fade_in(0.0)
	elias.machine.transition_to(&"Idle")
	elias.visual.play(&"idle")
	if marek:
		marek.face_toward(elias.global_position)
		marek.visual.play(&"idle")
		marek.mode = &"Wait"
