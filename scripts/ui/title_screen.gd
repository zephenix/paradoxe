extends Control
## Écran titre (provisoire) : accès à la salle de test, au banc d'écoute (J5)
## et à un petit banc de test des bus audio.
##
## 1. Attend un clic ou une touche (obligatoire sur le Web pour avoir du son).
## 2. Débloque l'audio, joue un son de validation, lance le bourdonnement du portail.
## 3. Affiche un petit banc de test pour vérifier les bus et leurs effets
##    (réverbération, étouffement, silence) sur chaque plateforme.
##
## Le vrai menu principal arrive en J9 ; cette scène restera l'écran titre.


const TEST_LEVEL: String = "res://scenes/levels/test_level.tscn"
const SOUND_BOARD: String = "res://scenes/ui/sound_board.tscn"
const HUM_LOOP_ID: StringName = &"title_portal_hum"
## Décalage vers la gauche du portail et du titre quand le banc de test s'ouvre.
const SHIFT_WHEN_PANEL_OPEN: float = -210.0

@onready var _portal: Node2D = %Portal
@onready var _title: Label = %Title
@onready var _prompt: Label = %Prompt
@onready var _panel: Control = %TestPanel
@onready var _diagnostics: Label = %Diagnostics
@onready var _level_button: Button = %LevelButton
@onready var _sound_board_button: Button = %SoundBoardButton
@onready var _classic_toggle: CheckButton = %ClassicToggle
@onready var _impact_button: Button = %ImpactButton
@onready var _hum_toggle: CheckButton = %HumToggle
@onready var _reverb_toggle: CheckButton = %ReverbToggle
@onready var _muffle_toggle: CheckButton = %MuffleToggle
@onready var _silence_button: Button = %SilenceButton
@onready var _volume_slider: HSlider = %VolumeSlider
@onready var _fullscreen_button: Button = %FullscreenButton
@onready var _quit_button: Button = %QuitButton

var _diagnostic_timer: float = 0.0


func _ready() -> void:
	_panel.hide()
	_quit_button.visible = not OS.has_feature("web")  # on ne « quitte » pas une page Web

	# Clignotement doux de l'invitation (boucle infinie).
	var blink: Tween = create_tween().set_loops()
	blink.tween_property(_prompt, "modulate:a", 0.25, 1.1).set_trans(Tween.TRANS_SINE)
	blink.tween_property(_prompt, "modulate:a", 1.0, 1.1).set_trans(Tween.TRANS_SINE)

	_level_button.pressed.connect(_on_level_pressed)
	_sound_board_button.pressed.connect(_on_sound_board_pressed)
	_classic_toggle.set_pressed_no_signal(Settings.classic_mode)
	_classic_toggle.toggled.connect(_on_classic_toggled)
	_impact_button.pressed.connect(_on_impact_pressed)
	_hum_toggle.toggled.connect(_on_hum_toggled)
	_reverb_toggle.toggled.connect(_on_reverb_toggled)
	_muffle_toggle.toggled.connect(_on_muffle_toggled)
	_silence_button.pressed.connect(_on_silence_pressed)
	_volume_slider.value = Settings.get_volume(AudioBuses.MASTER)
	_volume_slider.value_changed.connect(_on_volume_changed)
	_fullscreen_button.pressed.connect(_on_fullscreen_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)

	_update_diagnostics()
	if AudioManager.is_unlocked:
		_show_test_panel()


func _input(event: InputEvent) -> void:
	if AudioManager.is_unlocked:
		return
	if _is_activation(event):
		# L'évènement est « consommé » : il ne déclenche rien d'autre.
		get_viewport().set_input_as_handled()
		_unlock_audio()


func _process(delta: float) -> void:
	_diagnostic_timer -= delta
	if _diagnostic_timer <= 0.0:
		_diagnostic_timer = 0.5
		_update_diagnostics()


## Vrai pour tout appui (touche, clic, bouton de manette, toucher d'écran).
func _is_activation(event: InputEvent) -> bool:
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		return event.is_pressed() and not event.is_echo()
	if event is InputEventScreenTouch:
		return event.is_pressed()
	return false


func _unlock_audio() -> void:
	AudioManager.unlock()
	AudioManager.play_sfx(&"ui_confirm")
	AudioManager.play_loop_sfx(HUM_LOOP_ID, &"portal_hum_loop", 2.5)
	# Le portail « s'allume » en même temps que le son.
	var tween: Tween = create_tween()
	tween.tween_property(_portal, "intensity", 1.6, 0.25)
	tween.tween_property(_portal, "intensity", 1.0, 1.2)
	_show_test_panel(true)


func _show_test_panel(animate: bool = false) -> void:
	_prompt.hide()
	_panel.show()
	# Portail et titre glissent vers la gauche pour laisser la place au panneau.
	var portal_x: float = _portal.position.x + SHIFT_WHEN_PANEL_OPEN
	var title_x: float = _title.position.x + SHIFT_WHEN_PANEL_OPEN
	if animate:
		var slide: Tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		slide.tween_property(_portal, "position:x", portal_x, 0.8)
		slide.tween_property(_title, "position:x", title_x, 0.8)
		_panel.modulate.a = 0.0
		slide.tween_property(_panel, "modulate:a", 1.0, 0.6).set_delay(0.2)
	else:
		_portal.position.x = portal_x
		_title.position.x = title_x
	_hum_toggle.set_pressed_no_signal(AudioManager.is_loop_playing(HUM_LOOP_ID))
	_level_button.grab_focus()  # navigation au clavier / à la manette


func _update_diagnostics() -> void:
	var platform: String = OS.get_name()
	if OS.has_feature("web"):
		platform += " (%s)" % ("multithread" if OS.has_feature("threads") else "monothread")
	if Settings.classic_mode:
		platform += "  ·  mode classique"
	_diagnostics.text = "PARADOXE v%s  ·  Godot %s  ·  %s  ·  rendu %s  ·  %d img/s\n%s" % [
		ProjectSettings.get_setting("application/config/version"),
		Engine.get_version_info().string,
		platform,
		RenderingServer.get_current_rendering_method(),
		Engine.get_frames_per_second(),
		AudioManager.describe(),
	]


# --- Banc de test ----------------------------------------------------------

func _on_level_pressed() -> void:
	_level_button.disabled = true  # un double clic ne lance pas deux transitions
	AudioManager.play_sfx(&"ui_confirm")
	AudioManager.stop_loop(HUM_LOOP_ID, 0.8)
	SceneTransition.change_scene(TEST_LEVEL)


func _on_sound_board_pressed() -> void:
	_sound_board_button.disabled = true
	AudioManager.play_sfx(&"ui_confirm")
	AudioManager.stop_loop(HUM_LOOP_ID, 0.8)
	SceneTransition.change_scene(SOUND_BOARD)


## Mode classique (PLAN §5.9) : réglage du joueur, sauvegardé. Le vrai menu
## d'options arrive en J9 ; en attendant, l'interrupteur est ici.
func _on_classic_toggled(enabled: bool) -> void:
	Settings.classic_mode = enabled
	Settings.save_settings()
	Events.settings_changed.emit()


func _on_impact_pressed() -> void:
	AudioManager.play_sfx(&"test_impact")


func _on_hum_toggled(enabled: bool) -> void:
	if enabled:
		AudioManager.play_loop_sfx(HUM_LOOP_ID, &"portal_hum_loop", 1.0)
	else:
		AudioManager.stop_loop(HUM_LOOP_ID, 1.0)


func _on_reverb_toggled(enabled: bool) -> void:
	# Préréglage « grand hall » (mêmes valeurs que resources/audio/zones/hall.tres).
	AudioManager.set_reverb(0.24 if enabled else 0.0, 0.8, 0.55)


func _on_muffle_toggled(enabled: bool) -> void:
	AudioManager.set_muffle(1.0 if enabled else 0.0, 0.8)


func _on_silence_pressed() -> void:
	AudioManager.cut_to_silence(1.2, 1.5)


func _on_volume_changed(value: float) -> void:
	Settings.set_volume(AudioBuses.MASTER, value)
	Settings.save_settings()


func _on_fullscreen_pressed() -> void:
	Settings.set_fullscreen(not Settings.fullscreen)
	Settings.save_settings()


func _on_quit_pressed() -> void:
	get_tree().quit()
