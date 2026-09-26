class_name IntroCutscene
extends Cutscene
## La cinématique d'ouverture (J8, PLAN §5.12) : 11 plans, 75 secondes.
##
## LA TABLE DE MONTAGE est écrite ci-dessous, comme un tableau Excel : une ligne
## par plan (quand il commence, combien de temps il dure), une ligne par son.
## Au démarrage, build_animation() transforme ces tableaux en une animation
## Godot (un AnimationPlayer, la « table de montage » du PLAN) :
##   - une piste « visible » par plan (il apparaît, puis disparaît : coupe franche) ;
##   - une piste « progress » par plan (0 → 1 pendant sa durée) : le plan se
##     dessine selon son avancement ;
##   - des pistes « flash » (éclairs) ;
##   - une piste d'APPELS qui déclenche les sons au bon instant, à l'image près.
## Pour changer le rythme de l'intro : modifier les nombres des tableaux.

## Plans : [nœud dans « Shots », début (s), durée (s)].
const SHOTS: Array = [
	["Black", 0.0, 5.0],        # 1  noir, la pluie seule
	["Cliff", 5.0, 8.0],        # 2  le laboratoire sur la falaise, l'éclair
	["Glider", 13.0, 7.0],      # 3  le glisseur se pose
	["Scanner", 20.0, 5.0],     # 4  la main sur le lecteur
	["Corridor", 25.0, 8.0],    # 5  le couloir aux néons
	["Photo", 33.0, 6.0],       # 6  la photo (Marek, le pendentif)
	["Terminal", 39.0, 7.0],    # 7  le terminal, début du thème
	["Portal", 46.0, 8.0],      # 8  l'anneau s'allume
	["Strike", 54.0, 4.0],      # 9  la foudre
	["Eyes", 58.0, 3.0],        # 10 les yeux ; silence total
	["Aftermath", 61.0, 14.0],  # 11 flash, labo vide, titre
]
## Éclairs : [plan, début (s), durée (s)]. L'éclat monte d'un coup puis retombe.
const FLASHES: Array = [["Cliff", 7.0, 0.6], ["Cliff", 10.9, 0.4], ["Strike", 54.35, 1.4]]
## Sons : [instant (s), action, identifiant, réglage].
##   "sfx"   : un son de la bibliothèque (réglage = décalage de volume en dB) ;
##   "loop"  : démarre ou règle une boucle (réglage = volume en dB) ;
##   "stop"  : arrête une boucle ;
##   "music" : lance un thème ;
##   "cut"   : SILENCE TOTAL, tout est coupé (plan 10).
const CUES: Array = [
	[0.0, "loop", &"amb_rain_loop", -10.0],
	[3.5, "sfx", &"sfx_thunder", -8.0],
	[7.25, "sfx", &"sfx_thunder", 0.0],
	[11.2, "sfx", &"sfx_thunder", -4.0],
	[13.2, "sfx", &"sfx_glider_pass", 0.0],
	[20.0, "loop", &"amb_rain_loop", -24.0],   # à l'intérieur : la pluie s'éloigne
	[21.4, "sfx", &"sfx_bio_scan", 0.0],
	[23.6, "sfx", &"sfx_airlock", 0.0],
	[24.0, "loop", &"amb_lab_loop", -6.0],     # ventilation
	[26.0, "sfx", &"amb_buzz", 0.0],           # néon qui grésille
	[29.5, "sfx", &"amb_buzz", -3.0],
	[39.4, "sfx", &"sfx_key", 0.0], [39.7, "sfx", &"sfx_key", 0.0], [39.9, "sfx", &"sfx_key", -2.0],
	[40.0, "music", &"mus_theme_intro", 0.0],
	[40.3, "sfx", &"sfx_key", 0.0], [40.5, "sfx", &"sfx_key", -2.0], [41.0, "sfx", &"sfx_key", 0.0],
	[41.2, "sfx", &"sfx_key", 0.0], [41.6, "sfx", &"sfx_key", -2.0], [42.0, "sfx", &"sfx_key", 0.0],
	[42.9, "sfx", &"sfx_terminal_rise", 0.0],
	[46.0, "sfx", &"sfx_portal_charge", 0.0],
	[54.0, "loop", &"amb_rain_loop", -8.0],    # dehors
	[54.35, "sfx", &"sfx_lightning_strike", 0.0],
	[58.0, "cut", &"", 0.0],
	[61.0, "sfx", &"sfx_flash_breath", 0.0],
	[66.3, "sfx", &"sfx_paper_fall", 0.0],
]
## Durée totale (s).
const LENGTH: float = 75.0
## Préfixe des boucles lancées par l'intro (pour toutes les arrêter à la fin).
const LOOP_PREFIX: String = "intro_"

## Le lecteur d'animation qui joue la table de montage.
@export var montage: NodePath = ^"../Montage"
## Le conteneur des plans.
@export var shots: NodePath = ^"../Shots"

var _loops: Array[StringName] = []
var _cut_active: bool = false


## Construit l'animation « intro » à partir des tableaux ci-dessus.
func build_animation() -> Animation:
	var anim := Animation.new()
	anim.length = LENGTH
	var shots_path: String = str(get_node(montage).get_node(^"..").get_path_to(get_node(shots)))
	var self_path: NodePath = get_node(montage).get_node(^"..").get_path_to(self)
	for row: Array in SHOTS:
		var shot_name: String = row[0]
		var start: float = row[1]
		var end: float = start + float(row[2])
		var vis: int = anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(vis, NodePath("%s/%s:visible" % [shots_path, shot_name]))
		anim.value_track_set_update_mode(vis, Animation.UPDATE_DISCRETE)
		if start > 0.0:
			anim.track_insert_key(vis, 0.0, false)
		anim.track_insert_key(vis, start, true)
		if end < LENGTH:
			anim.track_insert_key(vis, end, false)
		var prog: int = anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(prog, NodePath("%s/%s:progress" % [shots_path, shot_name]))
		anim.track_insert_key(prog, start, 0.0)
		anim.track_insert_key(prog, end, 1.0)
	var flash_tracks: Dictionary = {}
	for row: Array in FLASHES:
		var shot_name: String = row[0]
		if not flash_tracks.has(shot_name):
			var track: int = anim.add_track(Animation.TYPE_VALUE)
			anim.track_set_path(track, NodePath("%s/%s:flash" % [shots_path, shot_name]))
			anim.track_insert_key(track, 0.0, 0.0)
			flash_tracks[shot_name] = track
		var t: float = row[1]
		anim.track_insert_key(flash_tracks[shot_name], t, 0.0)
		anim.track_insert_key(flash_tracks[shot_name], t + 0.04, 1.0)
		anim.track_insert_key(flash_tracks[shot_name], t + float(row[2]), 0.0)
	var calls: int = anim.add_track(Animation.TYPE_METHOD)
	anim.track_set_path(calls, self_path)
	for row: Array in CUES:
		anim.track_insert_key(calls, row[0], {"method": &"cue", "args": [row[1], row[2], row[3]]})
	return anim


func run(_ctx: CutscenePlayer) -> void:
	var player: AnimationPlayer = get_node(montage)
	var library := AnimationLibrary.new()
	library.add_animation(&"intro", build_animation())
	if player.has_animation_library(&""):
		player.remove_animation_library(&"")
	player.add_animation_library(&"", library)
	AudioManager.set_zone(&"", 0.5)
	player.play(&"intro")
	while player.is_playing() and not _ctx.skipping and is_inside_tree():
		await get_tree().process_frame


## État final, même si le joueur a passé l'intro : tout le son de l'intro s'arrête,
## le son revient (si on a passé pendant le silence du plan 10).
func finish(_ctx: CutscenePlayer) -> void:
	var player: AnimationPlayer = get_node_or_null(montage)
	if player:
		player.stop()
	for id in _loops:
		AudioManager.stop_loop(id, 0.5)
	_loops.clear()
	AudioManager.stop_music(0.5)
	if _cut_active:
		AudioManager.restore_from_silence(0.3)
		_cut_active = false


## Appelé par la piste d'appels de l'animation, au bon instant.
func cue(action: String, id: StringName, value: float) -> void:
	match action:
		"sfx":
			AudioManager.play_sfx(id, null, null, value)
		"loop":
			var loop_id := StringName(LOOP_PREFIX + String(id))
			AudioManager.play_loop_sfx(loop_id, id, 1.5, value)
			if loop_id not in _loops:
				_loops.append(loop_id)
		"stop":
			var loop_id := StringName(LOOP_PREFIX + String(id))
			AudioManager.stop_loop(loop_id, 0.5)
			_loops.erase(loop_id)
		"music":
			AudioManager.play_music(id, value)
		"cut":
			# Coupure brutale : tout se tait (musique, pluie, foudre qui roule…).
			for loop_id in _loops:
				AudioManager.stop_loop(loop_id, 0.0)
			_loops.clear()
			AudioManager.music.silence()
			AudioManager.cut_to_silence(2.9, 0.1)  # le son revient juste avant le souffle du plan 11
			_cut_active = true
		_:
			push_warning("IntroCutscene : action inconnue « %s »" % action)
