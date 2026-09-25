extends Node
## Gestionnaire audio central (autoload « AudioManager »).
##
## C'est le chef d'orchestre sonore du jeu. Tout son passe par lui, ce qui
## permet trois choses :
##   1. piloter les effets globaux (étouffement, réverbération de salle, silences) ;
##   2. gérer ambiances et musique en fondus (J5, J8) ;
##   3. INFORMER LES ENNEMIS de ce qu'ils peuvent entendre : un son qui a un
##      « rayon de bruit » émet le signal noise_emitted (J6). Un seul système
##      pour ce qu'on entend et ce que les ennemis entendent.
##
## J1 : lecture simple de sons, boucles, effets de bus et déblocage Web.
## Les fonctions à venir sont listées dans docs/PLAN.md §6.3.

## Un bruit vient d'être produit dans le monde du jeu (écouté par les ennemis en J6).
## position : où ; radius : jusqu'où il porte (pixels) ; source : qui l'a produit.
signal noise_emitted(position: Vector2, radius: float, source: Node)

## Nombre de lecteurs audio préparés à l'avance pour les sons courts.
const POOL_SIZE: int = 16
## Volume considéré comme « silence » (en décibels).
const SILENT_DB: float = -80.0
## Coupure du filtre passe-bas quand l'étouffement est maximal.
const MUFFLE_MIN_HZ: float = 350.0

## Vrai une fois que le joueur a cliqué ou appuyé sur une touche.
## Sur le Web, aucun son ne peut sortir avant ce moment.
var is_unlocked: bool = false

## Étouffement global, de 0.0 (son normal) à 1.0 (très étouffé). Voir set_muffle().
var muffle: float = 0.0:
	set(value):
		muffle = clampf(value, 0.0, 1.0)
		_apply_muffle()

## Gain « dramatique » du Master en dB, indépendant du volume choisi par le
## joueur (sert aux coupures au silence et aux fondus de mise en scène).
var drama_gain_db: float = 0.0:
	set(value):
		drama_gain_db = clampf(value, SILENT_DB, 12.0)
		_apply_drama_gain()

var _pool: Array[AudioStreamPlayer] = []
var _loops: Dictionary = {}  # identifiant -> AudioStreamPlayer
var _muffle_tween: Tween
var _gain_tween: Tween


func _ready() -> void:
	# Le gestionnaire continue de fonctionner quand le jeu est en pause
	# (fondus du menu pause, effet de rembobinage…).
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		_pool.append(_make_player())
	_apply_muffle()
	_apply_drama_gain()


# --------------------------------------------------------------------------
# Déblocage (navigateurs Web)
# --------------------------------------------------------------------------

## À appeler au premier clic / à la première touche (l'écran titre s'en charge).
## Les navigateurs interdisent le son avant une interaction ; Godot réveille le
## contexte audio du navigateur lors de cette interaction, et nous ne démarrons
## ambiances et musique qu'à partir de ce moment-là.
func unlock() -> void:
	if is_unlocked:
		return
	is_unlocked = true
	Events.audio_unlocked.emit()


# --------------------------------------------------------------------------
# Lecture de sons
# --------------------------------------------------------------------------

## Joue un son court, non positionné, sur un bus donné.
## (J5 ajoutera play_sfx(id, position) : sons positionnés, variations
## aléatoires et rayon de bruit tirés de la bibliothèque de sons.)
func play_stream(stream: AudioStream, bus: StringName = AudioBuses.SFX, volume_db: float = 0.0,
		pitch: float = 1.0) -> AudioStreamPlayer:
	if stream == null:
		push_warning("AudioManager.play_stream : aucun son fourni")
		return null
	var player: AudioStreamPlayer = _free_player()
	player.stream = stream
	player.bus = bus
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()
	return player


## Signale un bruit aux ennemis sans jouer de son (réservé aux cas où le son
## est joué autrement, par exemple par un AudioStreamPlayer2D de la scène).
func emit_noise(noise_position: Vector2, radius: float, source: Node = null) -> void:
	if radius > 0.0:
		noise_emitted.emit(noise_position, radius, source)


## Démarre (en fondu) un son en boucle identifié par un nom, par exemple une
## couche d'ambiance. Rejouer le même identifiant ne relance pas le son.
func play_loop(id: StringName, stream: AudioStream, bus: StringName = AudioBuses.AMBIENCE,
		volume_db: float = 0.0, fade_in: float = 1.0) -> void:
	if _loops.has(id):
		var existing: AudioStreamPlayer = _loops[id]
		if existing.stream == stream:
			_fade(existing, volume_db, fade_in)
			return
		stop_loop(id, fade_in)
	var player := AudioStreamPlayer.new()
	player.name = "Loop_%s" % id
	player.stream = stream
	player.bus = bus
	player.volume_db = SILENT_DB if fade_in > 0.0 else volume_db
	add_child(player)
	player.play()
	_loops[id] = player
	_fade(player, volume_db, fade_in)


## Arrête (en fondu) une boucle démarrée par play_loop().
func stop_loop(id: StringName, fade_out: float = 1.0) -> void:
	if not _loops.has(id):
		return
	var player: AudioStreamPlayer = _loops[id]
	_loops.erase(id)
	if fade_out <= 0.0:
		player.queue_free()
		return
	var tween: Tween = _fade(player, SILENT_DB, fade_out)
	tween.finished.connect(player.queue_free)


func is_loop_playing(id: StringName) -> bool:
	return _loops.has(id)


# --------------------------------------------------------------------------
# Effets globaux
# --------------------------------------------------------------------------

## Étouffe progressivement tout le son (filtre passe-bas sur le Master).
## amount : 0 = normal, 1 = très étouffé. Utilisé par le rembobinage (J4),
## les chocs, les coupures dramatiques.
func set_muffle(amount: float, duration: float = 0.3) -> void:
	if _muffle_tween:
		_muffle_tween.kill()
	if duration <= 0.0:
		muffle = amount
		return
	_muffle_tween = create_tween()
	_muffle_tween.tween_property(self, "muffle", amount, duration)


## Coupe tout le son d'un coup (silence dramatique), puis le fait revenir
## en fondu après « hold » secondes. hold < 0 : le silence dure jusqu'à
## un appel à restore_from_silence().
func cut_to_silence(hold: float = 1.0, fade_back: float = 1.5) -> void:
	if _gain_tween:
		_gain_tween.kill()
	drama_gain_db = SILENT_DB
	if hold >= 0.0:
		_gain_tween = create_tween()
		_gain_tween.tween_interval(hold)
		_gain_tween.tween_property(self, "drama_gain_db", 0.0, fade_back)


## Fait revenir le son après cut_to_silence(hold = -1).
func restore_from_silence(fade_back: float = 1.5) -> void:
	if _gain_tween:
		_gain_tween.kill()
	_gain_tween = create_tween()
	_gain_tween.tween_property(self, "drama_gain_db", 0.0, fade_back)


## Règle la réverbération de la salle (bus Monde).
## wet : quantité d'écho (0 = sec) ; room_size : taille perçue (0 à 1) ;
## damping : amortissement des aigus (0 = métal brillant, 1 = pièce feutrée).
## J5 remplacera cet appel par des préréglages par zone (set_zone).
func set_reverb(wet: float, room_size: float = 0.6, damping: float = 0.5) -> void:
	var reverb: AudioEffectReverb = _effect(AudioBuses.WORLD, AudioBuses.WORLD_FX_REVERB) as AudioEffectReverb
	if reverb == null:
		return
	reverb.wet = clampf(wet, 0.0, 1.0)
	reverb.room_size = clampf(room_size, 0.0, 1.0)
	reverb.damping = clampf(damping, 0.0, 1.0)
	AudioServer.set_bus_effect_enabled(AudioBuses.index(AudioBuses.WORLD), AudioBuses.WORLD_FX_REVERB, wet > 0.0)


# --------------------------------------------------------------------------
# Diagnostic
# --------------------------------------------------------------------------

## Mode de lecture audio réellement utilisé sur cette plateforme :
## « Stream » (tous les effets) ou « Sample » (Web par défaut, sans effets).
func get_playback_mode_name() -> String:
	var mode: int = ProjectSettings.get_setting_with_override("audio/general/default_playback_type")
	return "Sample" if mode == 1 else "Stream"


## Résumé lisible de l'état audio (affiché par la scène de test).
func describe() -> String:
	return "Audio : %s, %d Hz, latence %.0f ms, %s" % [
		get_playback_mode_name(),
		AudioServer.get_mix_rate(),
		AudioServer.get_output_latency() * 1000.0,
		"débloqué" if is_unlocked else "en attente d'une interaction",
	]


# --------------------------------------------------------------------------
# Interne
# --------------------------------------------------------------------------

func _make_player() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	add_child(player)
	return player


## Renvoie un lecteur libre ; s'ils sont tous occupés, en crée un de plus.
func _free_player() -> AudioStreamPlayer:
	for player in _pool:
		if not player.playing:
			return player
	var extra: AudioStreamPlayer = _make_player()
	_pool.append(extra)
	return extra


func _fade(player: AudioStreamPlayer, target_db: float, duration: float) -> Tween:
	var tween: Tween = create_tween()
	tween.tween_property(player, "volume_db", target_db, maxf(duration, 0.01))
	return tween


func _effect(bus: StringName, effect_index: int) -> AudioEffect:
	var idx: int = AudioBuses.index(bus)
	if idx < 0 or effect_index >= AudioServer.get_bus_effect_count(idx):
		push_warning("AudioManager : effet %d introuvable sur le bus %s" % [effect_index, bus])
		return null
	return AudioServer.get_bus_effect(idx, effect_index)


func _apply_muffle() -> void:
	var lowpass: AudioEffectLowPassFilter = _effect(AudioBuses.MASTER, AudioBuses.MASTER_FX_LOWPASS) as AudioEffectLowPassFilter
	if lowpass == null:
		return
	# Interpolation exponentielle : l'oreille perçoit les fréquences en octaves,
	# donc on descend de 20 kHz à 350 Hz « régulièrement » à l'oreille.
	lowpass.cutoff_hz = AudioBuses.LOWPASS_OPEN_HZ * pow(MUFFLE_MIN_HZ / AudioBuses.LOWPASS_OPEN_HZ, muffle)
	AudioServer.set_bus_effect_enabled(AudioBuses.index(AudioBuses.MASTER), AudioBuses.MASTER_FX_LOWPASS, muffle > 0.001)


func _apply_drama_gain() -> void:
	var gain: AudioEffectAmplify = _effect(AudioBuses.MASTER, AudioBuses.MASTER_FX_GAIN) as AudioEffectAmplify
	if gain == null:
		return
	gain.volume_db = drama_gain_db
