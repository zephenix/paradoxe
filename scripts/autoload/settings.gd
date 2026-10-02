extends Node
## Options du joueur (autoload « Settings »).
##
## Rôle : garder en mémoire les réglages (volumes, mode classique, plein écran…),
## les appliquer au moteur, et les sauvegarder dans un fichier texte
## user://settings.cfg (format INI, lisible comme un fichier .ini de Windows).
##
## « user:// » est un dossier propre au jeu, choisi par Godot selon la plateforme :
##   - Windows : %APPDATA%\Godot\app_userdata\PARADOXE\
##   - Linux   : ~/.local/share/godot/app_userdata/PARADOXE/
##   - Web     : stockage du navigateur (IndexedDB)

const DEFAULT_PATH: String = "user://settings.cfg"

## Volumes par défaut, de 0.0 (muet) à 1.0 (plein volume).
const DEFAULT_VOLUMES: Dictionary = {
	AudioBuses.MASTER: 0.8,
	AudioBuses.MUSIC: 0.8,
	AudioBuses.AMBIENCE: 0.8,
	AudioBuses.SFX: 0.8,
	AudioBuses.VOICE: 0.8,
	AudioBuses.UI: 0.7,
}

## Chemin du fichier de sauvegarde (modifiable par les tests).
var file_path: String = DEFAULT_PATH

## Volume de chaque bus réglable (clé : nom du bus, valeur : 0.0 à 1.0).
var volumes: Dictionary = DEFAULT_VOLUMES.duplicate()

## Mode classique : désactive parkour moderne, rembobinage et perception (J4/J6).
var classic_mode: bool = false

## Plein écran (sans effet dans le navigateur tant que le joueur ne l'a pas demandé).
var fullscreen: bool = false

## Accessibilité « Voir les sons » (J6) : un cercle montre jusqu'où porte chaque
## bruit d'Élias (le rayon exact que perçoivent les ennemis).
var show_sounds: bool = false

# --- Assistances et accessibilité (J9, PLAN §5.11) ---
## Jeu ralenti (vitesse : resources/settings/assists.tres).
var slow_game: bool = false
## Rembobinages illimités (en mode moderne).
var infinite_rewinds: bool = false
## Rebords plus faciles à attraper.
var ledge_assist: bool = false
## Accroupi et bouclier : un appui pour activer, un autre pour arrêter (au lieu
## de maintenir la touche).
var toggle_crouch: bool = false
var toggle_shield: bool = false
## Moins de flashs (éclairs, éclats) et moins de secousses de l'image.
var reduce_flashes: bool = false
var reduce_shake: bool = false

## Ce que les aides changent (vitesse, tolérance…).
var assists: AssistConfig = preload("res://resources/settings/assists.tres")

## Vrai quand le joueur utilise la manette (les textes affichent alors les
## boutons de manette). Détecté à chaque appui.
var using_gamepad: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # détecte la manette même en pause
	InputActions.install_defaults()
	load_settings()
	apply_all()


## Le dernier appareil utilisé décide des noms de touches affichés.
func _input(event: InputEvent) -> void:
	var pad: bool
	if event is InputEventJoypadButton:
		pad = true
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) < 0.5:
			return  # petits mouvements d'un stick au repos : on les ignore
		pad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		pad = false
	else:
		return
	if pad != using_gamepad:
		using_gamepad = pad
		Events.input_device_changed.emit(pad)


## Vitesse du jeu (1 = normale ; moins avec l'aide « jeu ralenti »).
func game_speed() -> float:
	return assists.slow_speed if slow_game else 1.0


## Facteur des rebords (1 = normal ; plus avec l'aide « rebords tolérants »).
func ledge_factor() -> float:
	return assists.ledge_factor if ledge_assist else 1.0


## Intensité des flashs et des secousses (1 = normale).
func flash_factor() -> float:
	return assists.flash_factor if reduce_flashes else 1.0


func shake_factor() -> float:
	return assists.shake_factor if reduce_shake else 1.0


## Règle le volume d'un bus (0.0 à 1.0) et l'applique immédiatement.
func set_volume(bus: StringName, linear: float) -> void:
	if not DEFAULT_VOLUMES.has(bus):
		push_warning("Settings : bus inconnu « %s »" % bus)
		return
	volumes[bus] = clampf(linear, 0.0, 1.0)
	_apply_volume(bus)
	Events.settings_changed.emit()


func get_volume(bus: StringName) -> float:
	return volumes.get(bus, 1.0)


## Applique tous les réglages au moteur (volumes, plein écran).
func apply_all() -> void:
	for bus: StringName in volumes:
		_apply_volume(bus)
	_apply_fullscreen()


func set_fullscreen(enabled: bool) -> void:
	fullscreen = enabled
	_apply_fullscreen()
	Events.settings_changed.emit()


## Lit le fichier de réglages. Un fichier absent n'est pas une erreur
## (premier lancement) : on garde alors les valeurs par défaut.
func load_settings() -> void:
	var config := ConfigFile.new()
	var err: Error = config.load(file_path)
	if err != OK:
		return
	for bus: StringName in DEFAULT_VOLUMES:
		volumes[bus] = clampf(float(config.get_value("audio", String(bus), DEFAULT_VOLUMES[bus])), 0.0, 1.0)
	classic_mode = bool(config.get_value("gameplay", "classic_mode", false))
	fullscreen = bool(config.get_value("display", "fullscreen", false))
	show_sounds = bool(config.get_value("accessibility", "show_sounds", false))
	slow_game = bool(config.get_value("assists", "slow_game", false))
	infinite_rewinds = bool(config.get_value("assists", "infinite_rewinds", false))
	ledge_assist = bool(config.get_value("assists", "ledge_assist", false))
	toggle_crouch = bool(config.get_value("accessibility", "toggle_crouch", false))
	toggle_shield = bool(config.get_value("accessibility", "toggle_shield", false))
	reduce_flashes = bool(config.get_value("accessibility", "reduce_flashes", false))
	reduce_shake = bool(config.get_value("accessibility", "reduce_shake", false))
	InputActions.load_from(config)


## Écrit les réglages sur le disque. Renvoie OK (0) si tout s'est bien passé.
func save_settings() -> Error:
	var config := ConfigFile.new()
	for bus: StringName in volumes:
		config.set_value("audio", String(bus), volumes[bus])
	config.set_value("gameplay", "classic_mode", classic_mode)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("accessibility", "show_sounds", show_sounds)
	config.set_value("assists", "slow_game", slow_game)
	config.set_value("assists", "infinite_rewinds", infinite_rewinds)
	config.set_value("assists", "ledge_assist", ledge_assist)
	config.set_value("accessibility", "toggle_crouch", toggle_crouch)
	config.set_value("accessibility", "toggle_shield", toggle_shield)
	config.set_value("accessibility", "reduce_flashes", reduce_flashes)
	config.set_value("accessibility", "reduce_shake", reduce_shake)
	InputActions.save_to(config)
	return config.save(file_path)


## Revient aux valeurs par défaut (sans sauvegarder).
func reset_to_defaults() -> void:
	volumes = DEFAULT_VOLUMES.duplicate()
	classic_mode = false
	fullscreen = false
	show_sounds = false
	slow_game = false
	infinite_rewinds = false
	ledge_assist = false
	toggle_crouch = false
	toggle_shield = false
	reduce_flashes = false
	reduce_shake = false
	InputActions.install_defaults()
	apply_all()
	Events.settings_changed.emit()


func _apply_volume(bus: StringName) -> void:
	var idx: int = AudioBuses.index(bus)
	if idx < 0:
		push_warning("Settings : le bus « %s » n'existe pas dans le mixeur" % bus)
		return
	var linear: float = volumes[bus]
	AudioServer.set_bus_volume_linear(idx, linear)
	# À 0, on coupe franchement le bus (le volume linéaire 0 vaut -∞ dB).
	AudioServer.set_bus_mute(idx, linear <= 0.001)


func _apply_fullscreen() -> void:
	# En mode headless (tests, CI), il n'y a pas de fenêtre à régler.
	if DisplayServer.get_name() == "headless":
		return
	var mode: DisplayServer.WindowMode = (
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	)
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
