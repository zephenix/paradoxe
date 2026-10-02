class_name OptionsMenu
extends Control
## Menu d'options (J9, PLAN §5.11), ouvert depuis l'écran titre ou le menu pause.
## Quatre onglets :
##   - Son : un curseur par bus (général, musique, ambiance, effets, voix, interface) ;
##   - Commandes : chaque commande, sa touche clavier et son bouton de manette ;
##     cliquer, puis appuyer sur la nouvelle touche (Échap : annuler) ;
##   - Aides : mode classique, jeu ralenti, rembobinages illimités, rebords
##     tolérants, accroupi et bouclier en bascule ;
##   - Image : plein écran, voir les sons, moins de flashs, moins de secousses.
## Tout est sauvegardé dès qu'on change quelque chose (Settings.save_settings).
##
## Le menu est construit par le code (et non dessiné dans l'éditeur) : la liste des
## commandes vient du tableau InputActions.DEFAULTS, qui reste la seule référence.

signal closed

## Noms affichés des commandes, dans l'ordre du menu.
const ACTION_NAMES: Array = [
	[&"move_left", "Aller à gauche"], [&"move_right", "Aller à droite"], [&"move_up", "Haut (grimper)"],
	[&"move_down", "Bas (s'accroupir)"], [&"jump", "Sauter"], [&"run", "Courir (maintenir)"], [&"roll", "Roulade"],
	[&"fire", "Tirer"], [&"shield", "Bouclier"], [&"interact", "Interagir"], [&"throw", "Lancer une pierre"],
	[&"order", "Ordre au compagnon"], [&"bracelet", "Bracelet"], [&"rewind", "Remonter le temps"],
	[&"pause", "Pause"], [&"skip", "Passer une cinématique (maintenir)"],
]
const VOLUME_NAMES: Array = [
	[AudioBuses.MASTER, "Volume général"], [AudioBuses.MUSIC, "Musique"], [AudioBuses.AMBIENCE, "Ambiance"],
	[AudioBuses.SFX, "Effets"], [AudioBuses.VOICE, "Voix"], [AudioBuses.UI, "Interface"],
]

var _tabs: TabContainer
## Commande en attente d'une nouvelle touche (&"" = aucune), et pour quel appareil.
var _waiting_action: StringName = &""
var _waiting_pad: bool = false
var _binding_buttons: Dictionary = {}  # "action|pad" -> Button
var _back_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # il s'ouvre aussi depuis le menu pause
	# « anchors AND offsets » : le menu (et son voile) couvre tout l'écran, quelle
	# que soit la taille de son parent.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.02, 0.03, 0.88)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.08, 0.08, 0.95)
	style.border_color = Color(0.43, 1.0, 0.75, 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(18.0)
	panel.add_theme_stylebox_override(&"panel", style)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -450.0
	panel.offset_right = 450.0
	panel.offset_top = -310.0
	panel.offset_bottom = 310.0
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 10)
	panel.add_child(column)
	var heading := Label.new()
	heading.text = "OPTIONS"
	heading.add_theme_font_size_override(&"font_size", 26)
	column.add_child(heading)
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_tabs)
	_build_sound_tab()
	_build_controls_tab()
	_build_assists_tab()
	_build_display_tab()
	_back_button = Button.new()
	_back_button.text = "Retour"
	_back_button.pressed.connect(close)
	column.add_child(_back_button)
	Events.input_device_changed.connect(func(_pad: bool) -> void: _refresh_bindings())
	_tabs.get_tab_bar().grab_focus()


func close() -> void:
	Settings.save_settings()
	AudioManager.play_sfx(&"ui_confirm")
	closed.emit()
	queue_free()


## Échap ferme le menu (ou annule une touche en attente).
func _unhandled_input(event: InputEvent) -> void:
	if _waiting_action != &"":
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		close()


# --------------------------------------------------------------------------
# Onglets
# --------------------------------------------------------------------------

func _page(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(scroll)
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override(&"separation", 8)
	scroll.add_child(page)
	return page


func _build_sound_tab() -> void:
	var page: VBoxContainer = _page("Son")
	for entry: Array in VOLUME_NAMES:
		var bus: StringName = entry[0]
		var row := HBoxContainer.new()
		page.add_child(row)
		var label := Label.new()
		label.text = entry[1]
		label.custom_minimum_size.x = 220
		row.add_child(label)
		var slider := HSlider.new()
		slider.name = "Volume_%s" % bus
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = Settings.get_volume(bus)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.value_changed.connect(func(value: float) -> void:
			Settings.set_volume(bus, value)
			if bus == AudioBuses.UI or bus == AudioBuses.MASTER:
				AudioManager.play_sfx(&"ui_confirm"))
		row.add_child(slider)


func _build_controls_tab() -> void:
	var page: VBoxContainer = _page("Commandes")
	var help := Label.new()
	help.text = "Cliquez sur une touche, puis appuyez sur la nouvelle (Échap : annuler)."
	help.modulate = Color(0.75, 0.85, 0.82)
	page.add_child(help)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override(&"h_separation", 16)
	page.add_child(grid)
	for title: String in ["Commande", "Clavier", "Manette"]:
		var head := Label.new()
		head.text = title
		head.modulate = Color(0.55, 1.0, 0.8)
		grid.add_child(head)
	for entry: Array in ACTION_NAMES:
		var action: StringName = entry[0]
		var label := Label.new()
		label.text = entry[1]
		label.custom_minimum_size.x = 260
		grid.add_child(label)
		for pad: bool in [false, true]:
			var button := Button.new()
			button.custom_minimum_size.x = 220
			button.pressed.connect(_start_rebind.bind(action, pad))
			grid.add_child(button)
			_binding_buttons["%s|%s" % [action, pad]] = button
	var reset := Button.new()
	reset.text = "Touches par défaut"
	reset.pressed.connect(func() -> void:
		InputActions.install_defaults()
		Settings.save_settings()
		_refresh_bindings())
	page.add_child(reset)
	_refresh_bindings()


func _build_assists_tab() -> void:
	var page: VBoxContainer = _page("Aides")
	_toggle(page, "Mode classique (comme en 1992 : sans rembobinage ni aides)", Settings.classic_mode,
			func(on: bool) -> void: Settings.classic_mode = on)
	_toggle(page, "Jeu ralenti (%d %% de la vitesse)" % roundi(Settings.assists.slow_speed * 100.0), Settings.slow_game,
			func(on: bool) -> void: Settings.slow_game = on)
	_toggle(page, "Rembobinages illimités", Settings.infinite_rewinds, func(on: bool) -> void: Settings.infinite_rewinds = on)
	_toggle(page, "Rebords plus faciles à attraper", Settings.ledge_assist, func(on: bool) -> void: Settings.ledge_assist = on)
	_toggle(page, "Accroupi : un appui pour se baisser, un autre pour se relever", Settings.toggle_crouch,
			func(on: bool) -> void: Settings.toggle_crouch = on)
	_toggle(page, "Bouclier : un appui pour le lever, un autre pour le baisser", Settings.toggle_shield,
			func(on: bool) -> void: Settings.toggle_shield = on)


func _build_display_tab() -> void:
	var page: VBoxContainer = _page("Image")
	_toggle(page, "Plein écran", Settings.fullscreen, func(on: bool) -> void: Settings.set_fullscreen(on))
	_toggle(page, "Voir les sons (cercles : jusqu'où les ennemis entendent)", Settings.show_sounds,
			func(on: bool) -> void: Settings.show_sounds = on)
	_toggle(page, "Moins de flashs (éclairs, éclats lumineux)", Settings.reduce_flashes, func(on: bool) -> void: Settings.reduce_flashes = on)
	_toggle(page, "Moins de secousses de l'image", Settings.reduce_shake, func(on: bool) -> void: Settings.reduce_shake = on)


## Un interrupteur : il applique le réglage, sauvegarde et prévient le jeu.
func _toggle(page: VBoxContainer, text: String, value: bool, apply: Callable) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.text = text
	toggle.button_pressed = value
	toggle.toggled.connect(func(on: bool) -> void:
		apply.call(on)
		Settings.save_settings()
		Events.settings_changed.emit())
	page.add_child(toggle)
	return toggle


# --------------------------------------------------------------------------
# Remappage
# --------------------------------------------------------------------------

func _refresh_bindings() -> void:
	for key: String in _binding_buttons:
		var parts: PackedStringArray = key.split("|")
		var button: Button = _binding_buttons[key]
		button.text = InputPrompt.action_label(StringName(parts[0]), parts[1] == "true")


func _start_rebind(action: StringName, pad: bool) -> void:
	_waiting_action = action
	_waiting_pad = pad
	var button: Button = _binding_buttons["%s|%s" % [action, pad]]
	button.text = "Bouton de manette..." if pad else "Appuyez sur une touche..."


## Capture la prochaine touche (ou le prochain bouton) pour la commande en attente.
func _input(event: InputEvent) -> void:
	if _waiting_action == &"":
		return
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		get_viewport().set_input_as_handled()
		if (event as InputEventKey).physical_keycode == KEY_ESCAPE:
			finish_rebind(null)  # Échap : annuler
		elif not _waiting_pad:
			finish_rebind(event)
	elif _waiting_pad and event is InputEventJoypadButton and event.is_pressed():
		get_viewport().set_input_as_handled()
		finish_rebind(event)
	elif _waiting_pad and event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.6:
		get_viewport().set_input_as_handled()
		finish_rebind(event)


## Termine le remappage (event nul : annulé). Public pour les tests.
func finish_rebind(event: InputEvent) -> void:
	if event != null:
		InputActions.rebind(_waiting_action, event)
		Settings.save_settings()
		Events.settings_changed.emit()
		AudioManager.play_sfx(&"ui_confirm")
	_waiting_action = &""
	_refresh_bindings()
