class_name AmbiencePlayer
extends Node
## Joue l'ambiance de la zone acoustique courante (J5). Créé par l'AudioManager :
## on l'utilise par AudioManager.set_zone(&"lab").
##
## Changer de zone = fondu enchaîné : les couches de l'ancienne zone s'éteignent
## pendant que celles de la nouvelle montent ; une couche commune aux deux (le
## vent, par exemple) continue simplement, à son nouveau volume. Réverbération
## et filtre glissent eux aussi vers les réglages de la nouvelle zone.
##
## Analogie Excel : chaque couche a un volume « de base » (colonne B), un facteur
## de fondu entre 0 et 1 (colonne C) et une houle (colonne D) ; le volume réel est
## recalculé à chaque image : B + dB(C) + D.

const ZONES_DIR: String = "res://resources/audio/zones/"

## Zone courante (null = silence).
var zone: AcousticZone
## Identifiant de la zone courante (&"" = aucune).
var zone_id: StringName = &""

## Couches actives : identifiant du son -> {"player", "base_db", "fade", "phase", "target"}.
var _layers: Dictionary = {}
var _event_timer: float = 0.0
var _clock: float = 0.0
var _rng := RandomNumberGenerator.new()
var _acoustics_tween: Tween
var _cache: Dictionary = {}  # id -> AcousticZone


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Charge la zone « id » (null si le fichier n'existe pas).
func load_zone(id: StringName) -> AcousticZone:
	if _cache.has(id):
		return _cache[id]
	var path: String = ZONES_DIR + String(id) + ".tres"
	if not ResourceLoader.exists(path):
		return null
	var loaded: AcousticZone = load(path)
	_cache[id] = loaded
	return loaded


## Identifiants de toutes les zones (fichiers de resources/audio/zones/).
func zone_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for file_name: String in DirAccess.get_files_at(ZONES_DIR):
		# Dans un export, les fichiers .tres peuvent être listés avec « .remap ».
		file_name = file_name.trim_suffix(".remap")
		if file_name.ends_with(".tres"):
			ids.append(StringName(file_name.get_basename()))
	ids.sort()
	return ids


## Passe à la zone « id » en « fade » secondes. &"" = silence.
func set_zone(id: StringName, fade: float = 2.5) -> void:
	if id == zone_id:
		return
	var next: AcousticZone = load_zone(id) if id != &"" else null
	if id != &"" and next == null:
		push_warning("AmbiencePlayer : zone inconnue « %s »" % id)
		return
	zone = next
	zone_id = id
	# 1) Couches : on éteint celles qui ne servent plus, on (r)allume les autres.
	var wanted: Dictionary = {}  # son -> volume de base
	if zone:
		for i in zone.layers.size():
			var entry: SoundEntry = AudioManager.library.get_entry(zone.layers[i])
			if entry == null or entry.streams.is_empty():
				push_warning("AmbiencePlayer : couche inconnue « %s »" % zone.layers[i])
				continue
			wanted[zone.layers[i]] = entry.volume_db + zone.layer_volume_db(i)
	for sound_id: StringName in _layers.keys():
		if not wanted.has(sound_id):
			_fade_layer(sound_id, 0.0, fade, true)
	for sound_id: StringName in wanted:
		if not _layers.has(sound_id):
			_start_layer(sound_id)
		_layers[sound_id]["base_db"] = wanted[sound_id]
		_fade_layer(sound_id, 1.0, fade, false)
	# 2) Acoustique.
	_glide_acoustics(zone, fade)
	# 3) Premier évènement ponctuel.
	_event_timer = _next_interval()


## Nombre de couches en train de jouer (y compris celles qui s'éteignent).
func layer_count() -> int:
	return _layers.size()


## Vrai si la couche « sound_id » joue (et n'est pas en train de s'éteindre).
func has_layer(sound_id: StringName) -> bool:
	return _layers.has(sound_id) and not _layers[sound_id]["leaving"]


## Joue tout de suite un évènement ponctuel de la zone (banc d'écoute, tests).
## Renvoie son identifiant (&"" si la zone n'en a pas).
func play_random_event() -> StringName:
	if zone == null or zone.events.is_empty():
		return &""
	var sound_id: StringName = zone.events[_rng.randi() % zone.events.size()]
	var side: float = -1.0 if _rng.randf() < 0.5 else 1.0
	var offset := Vector2(side * _rng.randf_range(zone.event_distance_min, zone.event_distance_max),
			_rng.randf_range(-200.0, 120.0))
	# noise_scale = 0 : les bruits d'ambiance n'alertent pas les ennemis.
	AudioManager.play_sfx(sound_id, _listener_position() + offset, null, zone.event_volume_db, 0.0)
	return sound_id


func _process(delta: float) -> void:
	_clock += delta
	# Volume de chaque couche : base + fondu + houle.
	for sound_id: StringName in _layers:
		var layer: Dictionary = _layers[sound_id]
		var swell: float = 0.0
		if zone and zone.swell_period > 0.0:
			swell = zone.swell_depth_db * sin(TAU * _clock / zone.swell_period + layer["phase"])
		var player: AudioStreamPlayer = layer["player"]
		player.volume_db = layer["base_db"] + linear_to_db(maxf(layer["fade"], 0.0001)) + swell
	# Évènements ponctuels (pas pendant une pause : temps figé du rembobinage…).
	if zone == null or zone.events.is_empty() or get_tree().paused:
		return
	_event_timer -= delta
	if _event_timer <= 0.0:
		play_random_event()
		_event_timer = _next_interval()


func _start_layer(sound_id: StringName) -> void:
	var entry: SoundEntry = AudioManager.library.get_entry(sound_id)
	var player := AudioStreamPlayer.new()
	player.name = "Layer_%s" % sound_id
	player.stream = entry.streams[0]
	player.bus = entry.bus
	player.volume_db = AudioManager.SILENT_DB
	add_child(player)
	player.play(_rng.randf() * player.stream.get_length())  # départ au hasard dans la boucle
	_layers[sound_id] = {"player": player, "base_db": entry.volume_db, "fade": 0.0,
			"phase": _rng.randf() * TAU, "leaving": false, "tween": null}


## Mène le facteur de fondu d'une couche vers « target » ; « remove » : la
## supprimer une fois éteinte.
func _fade_layer(sound_id: StringName, target: float, duration: float, remove: bool) -> void:
	var layer: Dictionary = _layers[sound_id]
	layer["leaving"] = remove
	var old: Tween = layer["tween"]
	if old:
		old.kill()
	if duration <= 0.0:
		layer["fade"] = target
		if remove:
			_remove_layer(sound_id)
		return
	var tween: Tween = create_tween()
	tween.tween_method(func(v: float) -> void: layer["fade"] = v, layer["fade"], target, duration)
	if remove:
		tween.finished.connect(_remove_layer.bind(sound_id))
	layer["tween"] = tween


func _remove_layer(sound_id: StringName) -> void:
	if not _layers.has(sound_id) or not _layers[sound_id]["leaving"]:
		return
	(_layers[sound_id]["player"] as Node).queue_free()
	_layers.erase(sound_id)


func _glide_acoustics(target: AcousticZone, duration: float) -> void:
	if _acoustics_tween:
		_acoustics_tween.kill()
	var reverb: AudioEffectReverb = AudioManager.world_reverb()
	var start: Array[float] = [reverb.wet if reverb else 0.0, reverb.room_size if reverb else 0.5,
			reverb.damping if reverb else 0.5, AudioManager.world_lowpass_hz()]
	var goal: Array[float] = [0.0, 0.5, 0.5, AudioBuses.LOWPASS_OPEN_HZ]
	if target:
		goal = [target.reverb_wet, target.reverb_room_size, target.reverb_damping, target.lowpass_hz]
	var apply := func(t: float) -> void:
		AudioManager.set_reverb(lerpf(start[0], goal[0], t), lerpf(start[1], goal[1], t), lerpf(start[2], goal[2], t))
		# Le filtre glisse en « octaves » (exponentiel), comme l'entend l'oreille.
		AudioManager.set_world_lowpass(start[3] * pow(goal[3] / start[3], t))
	if duration <= 0.0:
		apply.call(1.0)
		return
	_acoustics_tween = create_tween()
	_acoustics_tween.tween_method(apply, 0.0, 1.0, duration)


func _next_interval() -> float:
	if zone == null:
		return 0.0
	return _rng.randf_range(zone.event_interval_min, zone.event_interval_max)


## Où est l'oreille : le centre de la caméra active (sinon le milieu de l'écran).
func _listener_position() -> Vector2:
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera:
		return camera.get_screen_center_position()
	return get_viewport().get_visible_rect().size * 0.5
