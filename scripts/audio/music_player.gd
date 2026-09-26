class_name MusicPlayer
extends Node
## La musique du jeu (J8, PLAN §6.7). Créé par l'AudioManager : on l'utilise par
## AudioManager.play_music(&"mus_theme_arrival"), AudioManager.stop_music() et
## AudioManager.set_tension(niveau). Les pistes viennent de la bibliothèque de
## sons (catégorie « music », bus Musique) : jamais de chemin de fichier.
##
## Deux sortes de musique, qui peuvent coexister :
##   - un THÈME : un morceau (intro, arrivée, poursuite…), un seul à la fois ;
##     en lancer un autre fond l'ancien ;
##   - la TENSION : trois couches en boucle, parfaitement calées, dont les volumes
##     suivent le niveau d'alerte des ennemis (Events.alert_level_changed, émis
##     par le Level). Au calme : silence (le jeu est surtout silencieux).
##
## Pourquoi un lecteur par couche plutôt qu'un seul flux « synchronisé » ?
## Les trois lecteurs démarrent sur la même image et leurs boucles ont
## exactement la même longueur : ils restent calés. Chacun garde son propre
## volume, qu'on modifie librement image par image.

## Émis quand un thème commence (les tests l'écoutent).
signal theme_started(id: StringName)

const SILENT_DB: float = -80.0

var config: MusicConfig = preload("res://resources/audio/music.tres")

## Niveau d'alerte demandé (0 = calme, 1 = combat).
var tension: float = 0.0
## Thème en cours (&"" = aucun).
var theme_id: StringName = &""

var _theme_player: AudioStreamPlayer
var _layer_players: Array[AudioStreamPlayer] = []
## Volume actuel de chaque couche, de 0 à 1 (il glisse vers sa cible).
var _layer_gains: Array[float] = []
var _silent_for: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # la musique continue pendant une pause
	for i in config.tension_layers.size():
		_layer_gains.append(0.0)
	Events.alert_level_changed.connect(set_tension)


# --------------------------------------------------------------------------
# Thèmes
# --------------------------------------------------------------------------

## Joue le thème « id » (fondu d'entrée « fade_in » secondes ; -1 = réglage par
## défaut). Le thème précédent s'éteint en fondu. Rejouer le thème en cours ne
## le relance pas.
func play_theme(id: StringName, fade_in: float = -1.0) -> void:
	if id == theme_id and _theme_player and _theme_player.playing:
		return
	var entry: SoundEntry = AudioManager.library.get_entry(id)
	if entry == null or entry.streams.is_empty():
		push_warning("MusicPlayer : musique inconnue « %s »" % id)
		return
	var fade: float = config.theme_fade_in if fade_in < 0.0 else fade_in
	stop_theme(maxf(fade, 0.5))  # l'ancien thème s'efface pendant que le nouveau entre
	var player := AudioStreamPlayer.new()
	player.name = "Theme_%s" % id
	player.stream = entry.streams[0]
	player.bus = entry.bus
	player.volume_db = entry.volume_db if fade <= 0.0 else SILENT_DB
	add_child(player)
	player.play()
	if fade > 0.0:
		create_tween().tween_property(player, "volume_db", entry.volume_db, fade)
	player.finished.connect(_on_theme_finished.bind(player))
	_theme_player = player
	theme_id = id
	theme_started.emit(id)


## Arrête le thème en cours (fondu de sortie ; 0 = coupure nette).
func stop_theme(fade_out: float = 1.0) -> void:
	if _theme_player == null:
		return
	var player: AudioStreamPlayer = _theme_player
	_theme_player = null
	theme_id = &""
	if fade_out <= 0.0 or not player.playing:
		player.queue_free()
		return
	var tween: Tween = create_tween()
	tween.tween_property(player, "volume_db", SILENT_DB, fade_out)
	tween.finished.connect(player.queue_free)


func is_theme_playing() -> bool:
	return _theme_player != null and _theme_player.playing


func _on_theme_finished(player: AudioStreamPlayer) -> void:
	if player == _theme_player:
		_theme_player = null
		theme_id = &""
	player.queue_free()


# --------------------------------------------------------------------------
# Tension
# --------------------------------------------------------------------------

## Niveau d'alerte (0 à 1). Relié à Events.alert_level_changed.
func set_tension(level: float) -> void:
	tension = clampf(level, 0.0, 1.0)


## Volume actuel (0 à 1) de la couche « index » (tests, banc d'écoute).
func layer_gain(index: int) -> float:
	return _layer_gains[index] if index < _layer_gains.size() else 0.0


## Vrai si les couches de tension tournent (même silencieuses).
func is_tension_running() -> bool:
	return not _layer_players.is_empty()


## Coupe toute la musique d'un coup (plan 10 de l'intro, retour au menu…).
func silence() -> void:
	stop_theme(0.0)
	tension = 0.0
	_stop_layers()


## Volume visé par la couche « index » pour le niveau de tension courant.
func target_gain(index: int) -> float:
	if config.duck_tension_under_theme and is_theme_playing():
		return 0.0
	var span: Vector2 = config.layer_ranges[index] if index < config.layer_ranges.size() else Vector2(0.0, 1.0)
	if tension <= span.x:
		return 0.0
	return smoothstep(span.x, maxf(span.y, span.x + 0.001), tension)


func _process(delta: float) -> void:
	var any_sound: bool = false
	for i in _layer_gains.size():
		var target: float = target_gain(i)
		var rate: float = 1.0 / maxf(config.rise_time if target > _layer_gains[i] else config.fall_time, 0.01)
		_layer_gains[i] = move_toward(_layer_gains[i], target, rate * delta)
		any_sound = any_sound or _layer_gains[i] > 0.0 or target > 0.0
	if any_sound and _layer_players.is_empty():
		_start_layers()
	_silent_for = 0.0 if any_sound else _silent_for + delta
	if not any_sound and _silent_for >= config.stop_after:
		_stop_layers()
	for i in _layer_players.size():
		var entry: SoundEntry = AudioManager.library.get_entry(config.tension_layers[i])
		var base_db: float = entry.volume_db if entry else 0.0
		_layer_players[i].volume_db = base_db + linear_to_db(_layer_gains[i]) if _layer_gains[i] > 0.001 else SILENT_DB


## Démarre toutes les couches sur la même image (elles restent ainsi calées).
func _start_layers() -> void:
	for id in config.tension_layers:
		var entry: SoundEntry = AudioManager.library.get_entry(id)
		var player := AudioStreamPlayer.new()
		player.name = "Tension_%s" % id
		if entry and not entry.streams.is_empty():
			player.stream = entry.streams[0]
			player.bus = entry.bus
		else:
			push_warning("MusicPlayer : couche de tension inconnue « %s »" % id)
		player.volume_db = SILENT_DB
		add_child(player)
		_layer_players.append(player)
	for player in _layer_players:
		if player.stream:
			player.play()


func _stop_layers() -> void:
	for player in _layer_players:
		player.queue_free()
	_layer_players.clear()
	for i in _layer_gains.size():
		_layer_gains[i] = 0.0
	_silent_for = 0.0
