class_name CaptureCutscene
extends Cutscene
## Écran 4, la capture (J7, PLAN §4.3) : au milieu de la clairière, le silence
## tombe d'un coup. Des Sentinelles sortent de la jungle des deux côtés et
## encerclent Élias, qui se recroqueville. Fondu au noir.
## État final : Élias, désarmé, est couché dans sa cellule (écran 5) ; c'est
## le nouveau point de réapparition.

## Figurants (Puppet) qui encerclent Élias, et où chacun s'arrête (décalage en x
## par rapport à Élias : négatif = à sa gauche).
@export var puppets: Array[NodePath] = []
@export var stops: Array[float] = [-150.0, 130.0, 240.0]
## Où Élias se réveille (Marker2D dans la cellule).
@export var cell_spawn: NodePath


func run(ctx: CutscenePlayer) -> void:
	var elias: Player = get_tree().get_first_node_in_group(&"player") as Player
	# 1) Le silence : l'ambiance s'éteint d'un coup.
	AudioManager.set_zone(&"", 0.3)
	await ctx.wait(1.0)
	# 2) Élias regarde autour de lui.
	elias.facing = -elias.facing
	await ctx.wait(0.7)
	elias.facing = -elias.facing
	await ctx.wait(0.5)
	# 3) Les Sentinelles sortent de la jungle.
	var moving: Array[Puppet] = []
	for i in puppets.size():
		var puppet: Puppet = get_node_or_null(puppets[i]) as Puppet
		if puppet:
			puppet.visible = true
			moving.append(puppet)
	AudioManager.play_sfx(&"creature_menace", elias.global_position + Vector2(200, -80))
	for i in moving.size():
		var stop_x: float = elias.global_position.x + (stops[i] if i < stops.size() else 200.0)
		if i < moving.size() - 1:
			ctx.walk(moving[i], stop_x, 90.0)  # sans attendre : ils marchent ensemble
		else:
			await ctx.walk(moving[i], stop_x, 90.0)
	for puppet in moving:
		puppet.facing = 1 if elias.global_position.x > puppet.global_position.x else -1
	# 4) Encerclé : il se recroqueville ; une voix menaçante.
	elias.visual.play(&"cower")
	AudioManager.play_sfx(&"creature_alert", elias.global_position + Vector2(-150, -80))
	await ctx.wait(1.4)
	await ctx.fade_out(1.2)


func finish(ctx: CutscenePlayer) -> void:
	var elias: Player = get_tree().get_first_node_in_group(&"player") as Player
	SceneTransition.cut_to_black()
	for path in puppets:
		var puppet: Node2D = get_node_or_null(path) as Node2D
		if puppet:
			puppet.visible = false
	# Son arme lui est confisquée (GameState.remove_item le désarme).
	GameState.remove_item(&"pistol")
	# Il se réveillera dans sa cellule : c'est le nouveau point de réapparition.
	var spawn: Node2D = get_node_or_null(cell_spawn) as Node2D
	if spawn:
		elias.global_position = spawn.global_position
		elias.velocity = Vector2.ZERO
		elias.facing = 1
		elias.machine.transition_to(&"Idle")
		elias.visual.play(&"lie")
		GameState.reach_checkpoint(&"cellule", spawn.global_position, 1)
	var level: Level = ctx.get_parent() as Level
	if level:
		level.camera.snap_to_target()
	RewindManager.start_recording()  # on ne remonte pas le temps jusqu'à la clairière
	if ctx.skipping:
		SceneTransition.cut_to_black()
