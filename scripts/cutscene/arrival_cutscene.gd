class_name ArrivalCutscene
extends Cutscene
## Écran 2 (J8) : l'arrivée. Élias tombe du ciel dans une ville en ruine envahie
## par une jungle luminescente, reste un instant au sol, se relève ; la caméra
## S'ÉCARTE et laisse deviner les restes du laboratoire (l'enseigne tordue au logo
## de l'intro). Le thème d'arrivée commence : la seule musique de cet écran.
##
## La chute est jouée par la cinématique (et non par la physique) : tombé de si
## haut, Élias se tuerait (plus de 5 blocs).

## Point d'atterrissage (un Marker2D) : Élias y est posé à la fin.
@export var landing: NodePath
## Zoom de la caméra quand elle s'écarte (plus petit = plus large).
@export var wide_zoom: float = 0.55
## Durée de la chute (secondes) et hauteur de départ (pixels au-dessus du sol).
@export var fall_time: float = 1.1
@export var fall_height: float = 700.0

var _zoom_tween: Tween


func run(ctx: CutscenePlayer) -> void:
	var elias: Player = get_tree().get_first_node_in_group(&"player") as Player
	var camera: CameraDirector = get_viewport().get_camera_2d() as CameraDirector
	var land: Vector2 = get_node(landing).global_position
	var sky: Vector2 = land + Vector2(-90.0, -fall_height)
	# 1) La chute : on déplace Élias nous-mêmes, image par image.
	elias.visual.play(&"fall")
	var t: float = 0.0
	while t < fall_time and not ctx.skipping and is_inside_tree():
		elias.global_position = sky.lerp(land, pow(t / fall_time, 2.0))
		elias.velocity = Vector2.ZERO
		elias.air_top_y = elias.global_position.y  # pas de « chute mortelle »
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	_land(elias, land)
	if not ctx.skipping:
		AudioManager.play_sfx(&"foley_land_heavy", land, elias)
		AudioManager.play_sfx(&"foley_body_fall", land, elias)
	await ctx.wait(1.4)
	# 2) Le thème d'arrivée ; la caméra s'écarte pendant qu'il reprend ses esprits.
	AudioManager.play_music(&"mus_theme_arrival", 1.5)
	if camera and not ctx.skipping:
		camera.zoom_override = camera.zoom.x
		_zoom_tween = create_tween()
		_zoom_tween.tween_property(camera, "zoom_override", wide_zoom, 3.5).set_trans(Tween.TRANS_SINE)
	await ctx.wait(3.8)
	elias.visual.play(&"get_up")
	await ctx.wait(1.4)
	elias.visual.play(&"idle")
	# 3) Retour au cadrage de la salle.
	if camera and not ctx.skipping and camera.current_room:
		_zoom_tween = create_tween()
		_zoom_tween.tween_property(camera, "zoom_override", camera.current_room.camera_zoom, 1.5).set_trans(Tween.TRANS_SINE)
	await ctx.wait(1.6)


## État final (même si on passe) : Élias debout au point d'atterrissage, caméra
## normale, le thème d'arrivée joue.
func finish(_ctx: CutscenePlayer) -> void:
	var elias: Player = get_tree().get_first_node_in_group(&"player") as Player
	var camera: CameraDirector = get_viewport().get_camera_2d() as CameraDirector
	if _zoom_tween:
		_zoom_tween.kill()
	if camera:
		camera.zoom_override = 0.0
	_land(elias, get_node(landing).global_position)
	elias.visual.play(&"idle")
	elias.machine.transition_to(&"Idle")
	if AudioManager.music.theme_id != &"mus_theme_arrival":
		AudioManager.play_music(&"mus_theme_arrival", 1.0)


func _land(elias: Player, at: Vector2) -> void:
	elias.global_position = at
	elias.velocity = Vector2.ZERO
	elias.air_top_y = at.y
	elias.visual.play(&"lie")
