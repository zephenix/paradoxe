class_name Level
extends Node2D
## Script d'un niveau : relie Élias, la caméra et les salles, et gère la mort.
##
## Mort (J4) : la séquence (ralenti, temps figé, choix « remonter le temps » ou
## « checkpoint ») est confiée à un DeathController, enfant de ce nœud.
##   - Élias a remonté le temps : le jeu reprend, rien d'autre à faire ;
##   - retour au checkpoint : fondu au noir ; pendant le noir, les tirs en vol
##     sont effacés et Élias réapparaît au DERNIER CHECKPOINT atteint (ou à son
##     point de départ), jauge pleine et rembobinages rendus. Sa réapparition
##     prévient les ennemis (Events.player_respawned), qui reprennent leur poste.
## Sans rembobinage possible (mode classique…), le retour au checkpoint suit un
## court délai et prend moins de 2 secondes (PLAN §5.7 ; resources/world/respawn.tres).
##
## Son (J5) : en changeant de salle, l'ambiance passe à la zone acoustique de la
## salle (Room.acoustic_zone) ; en quittant le niveau, elle s'éteint.
##
## « Pause » ouvre le menu pause (J9). En mode chrono (GameState.time_trial),
## un TimeTrial chronomètre la course et fait courir le fantôme du record.

## Durée du fondu de la lumière ambiante en changeant de salle (secondes).
const AMBIENT_FADE: float = 0.8

## Réglages de la réapparition (délai, fondus, vide sans fond).
@export var respawn: RespawnConfig = preload("res://resources/world/respawn.tres")
## Commencer une nouvelle partie en chargeant ce niveau (oublie les checkpoints
## d'une partie précédente, gardés par l'autoload GameState).
@export var new_game_on_start: bool = true
## Cinématique jouée dès l'entrée dans le niveau (J8 : l'arrivée d'Élias).
@export var opening_cutscene: NodePath
## Faux dans les tests : pas de cinématique d'ouverture.
var play_opening: bool = true

@onready var player: Player = $Elias
@onready var camera: CameraDirector = $CameraDirector

## Séquence de mort et rembobinage.
var death: DeathController
## Lecteur de cinématiques (J7).
var cutscenes: CutscenePlayer
## Teinte de la lumière ambiante (J6) : une pour le monde, une pour le ciel.
var ambient_tint: CanvasModulate
## Lumière principale (lune…) et finition de l'image (essai graphique) : réglées
## par l'ambiance de la salle (Room.atmosphere).
var key_light: DirectionalLight2D
var screen_grade: ColorRect
var _look_tween: Tween
var _sky_tint: CanvasModulate
var _tint_tween: Tween
## « Voir les sons » (J6) : cercles des bruits d'Élias.
var noise_rings: NoiseRings
## Menu pause (J9).
var pause_menu: PauseMenu
## Mode chrono (J9) : chrono, enregistrement du passage, fantôme. Null hors chrono.
var time_trial: TimeTrial
## Textes des salles (aides, « SORTIE ») : leurs touches sont remplies au vol.
var _labels: Array[Label] = []
## Niveau d'alerte global (J6) : 0 = calme, 1 = combat. C'est le plus inquiet
## des ennemis qui compte ; la musique de tension (J8) le suivra.
var alert_level: float = 0.0

## Point de départ d'Élias (réapparition tant qu'aucun checkpoint n'est atteint).
var _start_position: Vector2
var _start_facing: int = 1


func _ready() -> void:
	if new_game_on_start:
		GameState.new_game()
	_start_position = player.global_position
	_start_facing = player.facing
	camera.target = player
	# Chaque salle a sa zone acoustique (J5) : en y entrant, l'ambiance et
	# l'acoustique passent en fondu à celles de la zone.
	camera.room_changed.connect(_on_room_changed)
	Engine.time_scale = Settings.game_speed()  # aide « jeu ralenti » (J9)
	Events.settings_changed.connect(_on_settings_changed)
	_create_tints()
	_create_noise_rings()
	pause_menu = PauseMenu.new()
	pause_menu.name = "PauseMenu"
	pause_menu.restart_requested.connect(restart_from_checkpoint)
	add_child(pause_menu)
	_lift_labels()
	player.died.connect(_on_player_died)
	player.kill_y = _lowest_room_bottom() + respawn.kill_margin
	camera.snap_to_target()
	if camera.current_room:
		set_ambient(camera.current_room.ambient_light)  # tout de suite, sans fondu
		set_atmosphere(camera.current_room.atmosphere)
	death = DeathController.new()
	death.name = "DeathController"
	add_child(death)
	cutscenes = CutscenePlayer.new()
	cutscenes.name = "Cutscenes"
	add_child(cutscenes)
	if GameState.time_trial:
		time_trial = TimeTrial.new(self)
		time_trial.name = "TimeTrial"
		add_child(time_trial)
	if play_opening and not opening_cutscene.is_empty():
		_play_opening.call_deferred()
	# Pendant le défilement arrière, le jeu est en pause : la caméra ne suit plus
	# d'elle-même, on la recadre à chaque image.
	death.scrubbed.connect(camera.snap_to_target)
	RewindManager.start_recording()


func _exit_tree() -> void:
	Engine.time_scale = 1.0  # les menus tournent à vitesse normale
	RewindManager.recording = false
	RewindManager.clear()
	AudioManager.set_zone(&"", 1.0)
	# La musique ne survit pas au niveau (retour au menu) : tension et thème s'éteignent.
	Events.alert_level_changed.emit(0.0)
	AudioManager.stop_music(1.0)


func _on_room_changed(room: Room) -> void:
	AudioManager.set_zone(room.acoustic_zone)
	set_ambient(room.ambient_light, AMBIENT_FADE)
	set_atmosphere(room.atmosphere, AMBIENT_FADE)
	# En entrant dans un écran, le bracelet rappelle brièvement son objectif (J9).
	if room.objective != "" and not (cutscenes and cutscenes.playing) and not player.is_dead:
		player.bracelet.flash(&"objective")


## Applique l'ambiance visuelle d'une salle (null = aucune) en « duration »
## secondes : lumière principale et finition de l'image. La brume et les
## poussières, elles, appartiennent à la salle (Room).
func set_atmosphere(look: RoomAtmosphere, duration: float = 0.0) -> void:
	var energy: float = look.key_energy if look else 0.0
	var vignette: float = look.vignette if look else 0.0
	var grain: float = look.grain if look else 0.0
	if look:
		key_light.color = look.key_color
		key_light.rotation_degrees = -look.key_angle  # 0 : la lumière tombe d'en haut
		key_light.height = look.key_height
	var grade: ShaderMaterial = screen_grade.material as ShaderMaterial
	if _look_tween:
		_look_tween.kill()
	if duration <= 0.0:
		key_light.energy = energy
		grade.set_shader_parameter(&"vignette", vignette)
		grade.set_shader_parameter(&"grain", grain)
		return
	_look_tween = create_tween().set_parallel()
	_look_tween.tween_property(key_light, "energy", energy, duration)
	_look_tween.tween_property(grade, "shader_parameter/vignette", vignette, duration)
	_look_tween.tween_property(grade, "shader_parameter/grain", grain, duration)


## Teinte l'écran selon la lumière ambiante (0 = pénombre, 1 = plein jour), en
## « duration » secondes. Le calcul de ce que voient les Sentinelles lit la même
## valeur dans la salle (Lighting.ambient_at).
func set_ambient(ambient: float, duration: float = 0.0) -> void:
	var tint: Color = Lighting.ambient_color(ambient)
	if _tint_tween:
		_tint_tween.kill()
	if duration <= 0.0:
		ambient_tint.color = tint
		if _sky_tint:
			_sky_tint.color = tint
		return
	_tint_tween = create_tween().set_parallel()
	_tint_tween.tween_property(ambient_tint, "color", tint, duration)
	if _sky_tint:
		_tint_tween.tween_property(_sky_tint, "color", tint, duration)


## Niveau d'alerte : le plus inquiet des ennemis (combat, poursuite = 1 ;
## sinon sa jauge de suspicion). Events.alert_level_changed prévient la musique
## (J8) quand il change nettement.
func _physics_process(_delta: float) -> void:
	var level: float = 0.0
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var sentinel: Sentinel = node as Sentinel
		if sentinel == null or sentinel.is_dead:
			continue
		var state: StringName = sentinel.machine.current_name
		level = maxf(level, 1.0 if state in [&"Combat", &"Chase"] else sentinel.suspicion)
	if absf(level - alert_level) >= 0.05 or (level != alert_level and (level == 0.0 or level == 1.0)):
		alert_level = level
		Events.alert_level_changed.emit(alert_level)


## Les cercles de « Voir les sons » sont dans un calque qui suit la caméra
## (follow_viewport_enabled) : ils se placent dans le monde, mais la teinte de
## la lumière ambiante (qui ne touche que le calque du monde) ne les assombrit pas.
func _create_noise_rings() -> void:
	var layer := CanvasLayer.new()
	layer.name = "NoiseRingsLayer"
	layer.layer = 5
	layer.follow_viewport_enabled = true
	add_child(layer)
	noise_rings = NoiseRings.new()
	layer.add_child(noise_rings)


## Les textes posés dans les salles (aides, « SORTIE ») sont déplacés dans un
## calque qui suit la caméra : la pénombre d'une salle ne doit pas les rendre
## illisibles. Ils gardent exactement leur place dans le monde.
func _lift_labels() -> void:
	var layer := CanvasLayer.new()
	layer.name = "LabelsLayer"
	layer.layer = 4
	layer.follow_viewport_enabled = true
	add_child(layer)
	for room_node in get_tree().get_nodes_in_group(&"rooms"):
		var room: Room = room_node as Room
		if room == null or not is_ancestor_of(room):
			continue
		for child in room.get_children():
			var label: Label = child as Label
			if label:
				var world_position: Vector2 = label.global_position
				room.remove_child(label)
				layer.add_child(label)
				label.position = world_position
				# Le texte d'origine garde ses jetons ({jump}…) : on le remplit avec
				# les touches du joueur, et on le refait s'il change d'appareil (J9).
				# (Seulement les textes qui contiennent des jetons : d'autres, comme
				# l'aide de la sortie, sont écrits par leur propre script.)
				if label.text.contains("{"):
					label.set_meta(&"template", label.text)
					_labels.append(label)
	_refresh_labels()
	if not Events.input_device_changed.is_connected(_on_input_device_changed):
		Events.input_device_changed.connect(_on_input_device_changed)


func _on_input_device_changed(_gamepad: bool) -> void:
	_refresh_labels()


## Remplit les textes des salles avec les noms des touches (clavier ou manette).
func _refresh_labels() -> void:
	for label in _labels:
		if is_instance_valid(label):
			label.text = InputPrompt.fill(String(label.get_meta(&"template")), Settings.using_gamepad)


## Un CanvasModulate multiplie la couleur de tout ce qui est dessiné dans son
## calque : c'est un « variateur » de la lumière ambiante. Le ciel est dans un
## autre calque (CanvasLayer « Sky ») : il a le sien.
func _create_tints() -> void:
	ambient_tint = CanvasModulate.new()
	ambient_tint.name = "AmbientTint"
	add_child(ambient_tint)
	key_light = DirectionalLight2D.new()
	key_light.name = "KeyLight"
	key_light.energy = 0.0
	key_light.add_to_group(&"key_light")  # les personnages y lisent d'où vient la lumière
	add_child(key_light)
	var layer := CanvasLayer.new()
	layer.name = "ScreenGradeLayer"
	layer.layer = 3  # au-dessus du jeu, sous les textes des salles (4)
	add_child(layer)
	screen_grade = ColorRect.new()
	screen_grade.name = "ScreenGrade"
	screen_grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_grade.set_anchors_preset(Control.PRESET_FULL_RECT)
	var grade := ShaderMaterial.new()
	grade.shader = preload("res://assets/shaders/screen_grade.gdshader")
	grade.set_shader_parameter(&"vignette", 0.0)
	grade.set_shader_parameter(&"grain", 0.0)
	screen_grade.material = grade
	layer.add_child(screen_grade)
	var sky: CanvasLayer = get_node_or_null(^"Sky") as CanvasLayer
	if sky:
		_sky_tint = CanvasModulate.new()
		_sky_tint.name = "SkyTint"
		sky.add_child(_sky_tint)


func _unhandled_input(event: InputEvent) -> void:
	# Échap : le menu pause (J9). Pas pendant une cinématique (Échap sert alors à
	# la passer), ni pendant la séquence de mort (elle a son propre choix).
	if event.is_action_pressed(&"pause") and can_pause():
		get_viewport().set_input_as_handled()
		pause_menu.open()


## Vrai si le menu pause peut s'ouvrir maintenant.
func can_pause() -> bool:
	return not (cutscenes and cutscenes.playing) and not get_tree().paused and not player.is_dead \
			and not SceneTransition.is_changing_scene and not (time_trial and time_trial.is_finished)


## « Recommencer au checkpoint » (menu pause) : comme après une mort, sans la mort.
func restart_from_checkpoint() -> void:
	clear_projectiles()
	var point: Array = respawn_point()
	player.respawn(point[0], point[1])
	camera.snap_to_target()
	RewindManager.start_recording()


func _play_opening() -> void:
	var opening: Cutscene = get_node_or_null(opening_cutscene) as Cutscene
	if opening:
		cutscenes.play(opening)


## Où Élias réapparaîtra s'il meurt maintenant : [position des pieds, sens du regard].
func respawn_point() -> Array:
	if GameState.has_checkpoint():
		return [GameState.checkpoint_position, GameState.checkpoint_facing]
	return [_start_position, _start_facing]


func _on_player_died(_cause: StringName) -> void:
	RewindManager.stop_recording()
	# Courte phrase musicale de la mort (J8) : elle fait aussi taire la tension.
	AudioManager.play_music(&"mus_sting_death", 0.0)
	if RewindManager.can_rewind():
		var result: StringName = await death.play()
		if not is_inside_tree():
			return
		if result == &"rewound":
			camera.snap_to_target()
			return
	else:
		await get_tree().create_timer(respawn.delay).timeout
	# Si le joueur a quitté le niveau entre-temps (Échap), on n'insiste pas.
	if SceneTransition.is_changing_scene or not is_inside_tree():
		return
	await SceneTransition.fade_out(respawn.fade_out)
	if SceneTransition.is_changing_scene or not is_inside_tree():
		return
	clear_projectiles()
	var point: Array = respawn_point()
	player.respawn(point[0], point[1])
	GameState.reset_rewinds()
	camera.snap_to_target()
	RewindManager.start_recording()
	await SceneTransition.fade_in(respawn.fade_in)


## Efface tous les tirs en vol (réapparition ; le rembobinage de J4 aussi).
func clear_projectiles() -> void:
	for node in get_tree().get_nodes_in_group(&"projectiles"):
		node.queue_free()


func _lowest_room_bottom() -> float:
	var bottom: float = -INF
	for node in get_tree().get_nodes_in_group(&"rooms"):
		bottom = maxf(bottom, (node as Room).world_rect().end.y)
	return bottom if bottom > -INF else 1000.0


## Un réglage a changé (menu pause > options) : la vitesse du jeu suit, sauf
## pendant le ralenti de la mort (le DeathController la remettra lui-même).
func _on_settings_changed() -> void:
	if death == null or death.phase == &"":
		Engine.time_scale = Settings.game_speed()
	_refresh_labels()
