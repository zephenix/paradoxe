class_name PassageCutscene
extends Cutscene
## Passage vers un écran qui n'est pas voisin (J8) : de l'écran 5 (les cellules)
## aux ruines de l'écran 6, par un conduit. Fondu au noir ; pendant le noir,
## Élias (et le compagnon) sont déplacés, un checkpoint est posé ; l'image revient.

## Où Élias arrive (un Marker2D).
@export var destination: NodePath
## Où le compagnon arrive (vide : il reste où il est).
@export var companion_destination: NodePath
## Identifiant du checkpoint posé à l'arrivée.
@export var checkpoint_id: StringName = &""


func run(ctx: CutscenePlayer) -> void:
	await ctx.fade_out(0.8)


func finish(ctx: CutscenePlayer) -> void:
	var elias: Player = get_tree().get_first_node_in_group(&"player") as Player
	var spot: Node2D = get_node_or_null(destination) as Node2D
	if elias and spot:
		elias.global_position = spot.global_position
		elias.velocity = Vector2.ZERO
		elias.air_top_y = spot.global_position.y
		elias.facing = 1
		elias.machine.transition_to(&"Idle")
		if checkpoint_id != &"":
			GameState.reach_checkpoint(checkpoint_id, spot.global_position, 1)
	var buddy: Companion = get_tree().get_first_node_in_group(&"companion") as Companion
	var buddy_spot: Node2D = get_node_or_null(companion_destination) as Node2D
	if buddy and buddy_spot:
		buddy.global_position = buddy_spot.global_position
		buddy.velocity = Vector2.ZERO
	var level: Level = ctx.get_parent() as Level
	if level:
		level.camera.snap_to_target()
	RewindManager.start_recording()  # on ne remonte pas le temps à travers le conduit
	SceneTransition.fade_in(0.0 if ctx.skipping else 0.8)
