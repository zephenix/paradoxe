class_name FinaleCutscene
extends Cutscene
## Écran 8, la fin (J8) : Élias a franchi la porte ; Marek la referme derrière lui
## (les poursuivants restent de l'autre côté). La musique de poursuite s'arrête
## net : silence. Puis le PLAN FINAL (EndingShot) : la caméra recule et révèle le
## cratère, l'anneau du portail vert, et une créature qui pose un pendentif en
## spirale. Le thème de fin, très court. Retour à l'écran titre.

@export var companion: NodePath
@export var lever: NodePath
## Le plan final (dans un CanvasLayer, caché jusqu'ici).
@export var ending_shot: NodePath
## Durée du plan final (secondes).
@export var shot_length: float = 16.0
## Faux dans les tests : on reste dans le niveau à la fin.
@export var return_to_title: bool = true

const TITLE_SCENE: String = "res://scenes/ui/title_screen.tscn"

var _tween: Tween


func run(ctx: CutscenePlayer) -> void:
	var marek: Companion = get_node_or_null(companion) as Companion
	var switch: Lever = get_node_or_null(lever) as Lever
	var elias: Player = get_tree().get_first_node_in_group(&"player") as Player
	# 1) Marek referme la porte ; ils se regardent.
	if marek:
		marek.face_toward(elias.global_position)
	await ctx.wait(0.6)
	if switch and switch.on:
		if marek:
			marek.gesture(&"interact")
		switch.interact(marek)
	await ctx.wait(1.0)
	AudioManager.stop_music(0.0)  # la poursuite s'arrête net
	if marek:
		marek.gesture(&"touch_pendant")
	await ctx.wait(2.0)
	# 2) Le plan final.
	await ctx.fade_out(1.2)
	var shot: IntroShot = get_node_or_null(ending_shot) as IntroShot
	if shot and not ctx.skipping:
		shot.visible = true
		shot.progress = 0.0
		SceneTransition.fade_in(1.5)
		AudioManager.play_music(&"mus_theme_end", 2.0)
		_tween = create_tween()
		_tween.tween_property(shot, "progress", 1.0, shot_length)
		await ctx.wait(shot_length + 1.5)
		await ctx.fade_out(1.5)


## État final : la porte est fermée, la musique s'est tue ; retour au titre.
func finish(ctx: CutscenePlayer) -> void:
	if _tween:
		_tween.kill()
	var switch: Lever = get_node_or_null(lever) as Lever
	if switch and switch.on:
		switch.interact(get_node_or_null(companion))
	AudioManager.stop_music(1.0)
	var shot: IntroShot = get_node_or_null(ending_shot) as IntroShot
	if shot:
		shot.progress = 1.0
	if return_to_title and is_inside_tree():
		SceneTransition.change_scene(TITLE_SCENE, 0.0 if ctx.skipping else 1.0)
