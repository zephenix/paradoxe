class_name GuideCutscene
extends Cutscene
## Écran 6 (J8) : dans les ruines, Marek montre à Élias un chemin par les
## hauteurs (un geste vers la passerelle), puis s'en va par un conduit, là où
## Élias ne peut pas le suivre. Il reviendra à la toute fin (écran 8).

@export var companion: NodePath
## Où il s'arrête pour montrer le chemin (Marker2D), et l'entrée du conduit.
@export var lookout: NodePath
@export var duct: NodePath
## Où il attend, invisible, jusqu'à la fin (Marker2D de l'écran 8).
@export var hideout: NodePath

var _fade: Tween


func run(ctx: CutscenePlayer) -> void:
	var marek: Companion = get_node_or_null(companion) as Companion
	var elias: Player = get_tree().get_first_node_in_group(&"player") as Player
	if marek == null:
		return
	await ctx.wait(0.8)
	await ctx.walk(marek, (get_node(lookout) as Node2D).global_position.x, 90.0)
	# « Par là » : il se tourne vers Élias, lui fait signe, puis montre la passerelle.
	marek.face_toward(elias.global_position)
	marek.say(&"follow")
	marek.gesture(&"beckon")
	await ctx.wait(1.3)
	marek.facing = 1
	marek.gesture(&"interact")
	await ctx.wait(1.3)
	# Il part par le conduit (vers la gauche) et disparaît.
	await ctx.walk(marek, (get_node(duct) as Node2D).global_position.x, 90.0)
	marek.visual.play(&"crouch")
	marek.say(&"wait")
	_fade = create_tween()
	_fade.tween_property(marek, "modulate:a", 0.0, 0.6)
	await ctx.wait(0.8)


## État final : Marek est parti (invisible, sans ordres) et attend à l'écran 8.
func finish(_ctx: CutscenePlayer) -> void:
	var marek: Companion = get_node_or_null(companion) as Companion
	if marek == null:
		return
	if _fade:
		_fade.kill()
	marek.modulate.a = 1.0
	marek.mode = &"Wait"
	marek.away = true
	var spot: Node2D = get_node_or_null(hideout) as Node2D
	if spot:
		marek.global_position = spot.global_position
		marek.velocity = Vector2.ZERO
		marek.facing = -1
