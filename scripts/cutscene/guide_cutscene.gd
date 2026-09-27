class_name GuideCutscene
extends Cutscene
## Écran 6 (J8) : dans les ruines, Marek montre à Élias un chemin par les
## hauteurs (un geste vers la passerelle), lui fait signe de ne pas le suivre,
## puis se glisse à quatre pattes dans un conduit trop étroit pour Élias. Il
## reviendra à la toute fin (écran 8) pour ouvrir la dernière porte.

@export var companion: NodePath
## Où il s'arrête pour montrer le chemin (Marker2D), et l'entrée du conduit.
@export var lookout: NodePath
@export var duct: NodePath
## Où il attend, invisible, jusqu'à la fin (Marker2D de l'écran 8).
@export var hideout: NodePath

## Durée (s) et vitesse (px/s) de sa reptation dans le conduit.
const CRAWL_TIME: float = 1.8
const CRAWL_SPEED: float = 50.0

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
	# « Toi, par là-haut. Moi, par ici » : il fait signe à Élias de ne pas le suivre…
	marek.face_toward(elias.global_position)
	marek.say(&"wait")
	marek.gesture(&"halt")
	await ctx.wait(1.3)
	# … puis il se glisse dans le conduit, à quatre pattes, et disparaît dans le noir.
	var mouth_x: float = (get_node(duct) as Node2D).global_position.x
	await ctx.walk(marek, mouth_x + 40.0, 90.0)
	marek.facing = -1
	marek.visual.play(&"crouch_walk")
	_fade = create_tween()
	_fade.tween_property(marek, "modulate", Color(0.0, 0.0, 0.0, 1.0), CRAWL_TIME)
	var t: float = 0.0
	while t < CRAWL_TIME and not ctx.skipping and is_inside_tree():
		await get_tree().physics_frame
		var dt: float = get_physics_process_delta_time()
		t += dt
		marek.global_position.x -= CRAWL_SPEED * dt
	marek.visible = false
	await ctx.wait(0.6)


## État final : Marek est parti (invisible, sans ordres) et attend à l'écran 8.
func finish(_ctx: CutscenePlayer) -> void:
	var marek: Companion = get_node_or_null(companion) as Companion
	if marek == null:
		return
	if _fade:
		_fade.kill()
	marek.modulate = Color.WHITE
	marek.mode = &"Wait"
	marek.away = true
	var spot: Node2D = get_node_or_null(hideout) as Node2D
	if spot:
		marek.global_position = spot.global_position
		marek.velocity = Vector2.ZERO
		marek.facing = -1
