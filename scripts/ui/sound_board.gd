extends Control
## Banc d'écoute (J5, PLAN §6.6) : écouter et régler tous les sons du jeu, sur
## toutes les plateformes (y compris le navigateur).
##
##   - à gauche : les catégories et la liste des sons de la bibliothèque ;
##   - au centre : le son choisi. « Jouer » tire une variante au hasard, avec
##     ses variations de hauteur et de volume ; « Rafale » en joue cinq de
##     suite pour juger de la variété ; les curseurs règlent le son EN DIRECT ;
##   - à droite : les ambiances par zone, et les effets globaux (rembobinage,
##     silence dramatique, volume général).
##
## « Enregistrer » garde les réglages sur cet appareil (user://sound_tuning.json) :
## ils s'appliquent aussi en jeu. « Copier les valeurs » met le texte des
## réglages modifiés dans le presse-papiers, pour les reporter dans
## resources/audio/sound_library.tres (ou les transmettre à Claude).
##
## L'interface est construite par le code (et non dans l'éditeur) : c'est plus
## court, et chaque bloc est commenté.

const TITLE_SCENE: String = "res://scenes/ui/title_screen.tscn"
const LOOP_ID: StringName = &"sound_board_loop"
const ACCENT: Color = Color("6effc0")
## Noms affichés des catégories de la bibliothèque.
const CATEGORY_LABELS: Dictionary = {
	&"ambience": "Ambiances", &"combat": "Combat", &"creature": "Créatures",
	&"foley": "Bruitages d'Élias (Foley)", &"sfx": "Effets", &"ui": "Interface",
	&"voice": "Respiration d'Élias",
}

var _library: SoundLibrary
var _selected: SoundEntry
var _category_select: OptionButton
var _categories: Array[StringName] = []
var _list: ItemList
var _list_ids: Array[StringName] = []
var _name_label: Label
var _description: Label
var _info: Label
var _loop_toggle: CheckButton
var _bus_select: OptionButton
var _sliders: Dictionary = {}  # champ -> HSlider
var _slider_values: Dictionary = {}  # champ -> Label
var _zone_select: OptionButton
var _zone_ids: Array[StringName] = []
var _zone_info: Label
var _status: Label
var _rewind_toggle: CheckButton
var _updating: bool = false


func _ready() -> void:
	_library = AudioManager.library
	_build()
	_fill_categories()
	_fill_zones()
	_refresh_status("Choisir un son dans la liste, puis « Jouer ».")


func _exit_tree() -> void:
	# On rend le mixage tel qu'on l'a trouvé.
	AudioManager.stop_loop(LOOP_ID, 0.2)
	AudioManager.stop_loop(&"sound_board_rewind", 0.2)
	AudioManager.set_muffle(0.0, 0.0)
	AudioManager.set_zone(&"", 0.5)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_back()


# --------------------------------------------------------------------------
# Actions
# --------------------------------------------------------------------------

## Choisit un son (par son identifiant) : affiche ses réglages.
func select_sound(id: StringName) -> void:
	_selected = _library.get_entry(id)
	if _selected == null:
		return
	AudioManager.stop_loop(LOOP_ID, 0.2)
	_updating = true
	_name_label.text = String(id)
	_description.text = _selected.description
	_loop_toggle.set_pressed_no_signal(false)
	_loop_toggle.disabled = not _is_loop(_selected)
	for i in _bus_select.item_count:
		if _bus_select.get_item_text(i) == String(_selected.bus):
			_bus_select.select(i)
	for field: String in _sliders:
		(_sliders[field] as HSlider).value = _selected.get(field)
	_updating = false
	_update_info()


## Joue le son choisi (une variante au hasard).
func play_selected() -> void:
	if _selected == null:
		return
	if _is_loop(_selected):
		_loop_toggle.button_pressed = true
		return
	AudioManager.play_sfx(_selected.id)
	_refresh_status("Joué : %s" % _selected.id)


func _play_burst() -> void:
	if _selected == null or _is_loop(_selected):
		return
	var id: StringName = _selected.id
	for i in 5:
		if not is_inside_tree():
			return
		AudioManager.play_sfx(id)
		await get_tree().create_timer(0.45).timeout
	_refresh_status("Rafale : %s (5 fois)" % id)


func _on_loop_toggled(enabled: bool) -> void:
	if enabled and _selected:
		AudioManager.play_loop_sfx(LOOP_ID, _selected.id, 0.5)
		_refresh_status("En boucle : %s" % _selected.id)
	else:
		AudioManager.stop_loop(LOOP_ID, 0.5)


func _on_slider_changed(value: float, field: String) -> void:
	(_slider_values[field] as Label).text = _format(field, value)
	if _updating or _selected == null:
		return
	_selected.set(field, value)
	if field == "volume_db" and AudioManager.is_loop_playing(LOOP_ID):
		AudioManager.play_loop_sfx(LOOP_ID, _selected.id, 0.1)  # même boucle : le volume suit
	_update_info()


func _on_bus_selected(index: int) -> void:
	if _selected == null:
		return
	_selected.bus = StringName(_bus_select.get_item_text(index))
	_update_info()


func _on_reset_pressed() -> void:
	if _selected == null:
		return
	AudioManager.reset_tuning(_selected.id)
	select_sound(_selected.id)
	_refresh_status("Réglages d'origine rétablis : %s" % _selected.id)


func _on_save_pressed() -> void:
	var err: Error = AudioManager.save_tuning()
	_refresh_status("Réglages enregistrés sur cet appareil." if err == OK else "Échec de l'enregistrement : %s" % error_string(err))


func _on_copy_pressed() -> void:
	var text: String = AudioManager.tuning_report()
	DisplayServer.clipboard_set(text)
	_refresh_status("Copié dans le presse-papiers :\n" + text.get_slice("\n", 1 if text.contains("\n") else 0))


func _on_zone_selected(index: int) -> void:
	var id: StringName = _zone_ids[index]
	AudioManager.set_zone(id, 1.5)
	var zone: AcousticZone = AudioManager.ambience.zone
	if zone == null:
		_zone_info.text = "Aucune ambiance."
	else:
		_zone_info.text = "Couches : %s\nÉvènements : %s\nÉcho %.0f %%, taille %.0f %%, filtre %s" % [
			", ".join(zone.layers), ", ".join(zone.events), zone.reverb_wet * 100.0,
			zone.reverb_room_size * 100.0, "aucun" if zone.lowpass_hz >= 20000.0 else "%.0f Hz" % zone.lowpass_hz]


func _on_event_pressed() -> void:
	var id: StringName = AudioManager.ambience.play_random_event()
	_refresh_status("Évènement : %s" % id if id != &"" else "Choisir d'abord une zone.")


## Effet de rembobinage (comme à la mort d'Élias) : son étouffé + boucle.
func _on_rewind_toggled(enabled: bool) -> void:
	var cfg: RewindConfig = RewindManager.config
	AudioManager.set_muffle(cfg.muffle if enabled else 0.0, 0.25)
	if enabled:
		AudioManager.play_loop_sfx(&"sound_board_rewind", &"rewind_loop", 0.15)
	else:
		AudioManager.stop_loop(&"sound_board_rewind", 0.1)
		AudioManager.play_sfx(&"rewind_release")


func _on_silence_pressed() -> void:
	AudioManager.cut_to_silence(1.2, 1.5)


func _on_volume_changed(value: float) -> void:
	Settings.set_volume(AudioBuses.MASTER, value)
	Settings.save_settings()


func _back() -> void:
	AudioManager.play_sfx(&"ui_back")
	SceneTransition.change_scene(TITLE_SCENE)


# --------------------------------------------------------------------------
# Remplissage
# --------------------------------------------------------------------------

func _fill_categories() -> void:
	_category_select.clear()
	_categories = _library.categories()
	for category in _categories:
		_category_select.add_item(CATEGORY_LABELS.get(category, String(category)))
	_on_category_selected(0)


func _on_category_selected(index: int) -> void:
	_list.clear()
	_list_ids.clear()
	if index < 0:
		return
	for entry in _library.in_category(_categories[index]):
		var label: String = String(entry.id)
		if entry.streams.size() > 1:
			label += "  (x%d)" % entry.streams.size()
		if _is_loop(entry):
			label += "  [boucle]"
		_list.add_item(label)
		_list_ids.append(entry.id)
	if not _list_ids.is_empty():
		_list.select(0)
		select_sound(_list_ids[0])


func _fill_zones() -> void:
	_zone_select.clear()
	_zone_ids = [&""]
	_zone_select.add_item("Aucune")
	for id in AudioManager.ambience.zone_ids():
		var zone: AcousticZone = AudioManager.ambience.load_zone(id)
		_zone_select.add_item(zone.title if zone.title != "" else String(id))
		_zone_ids.append(id)
	_zone_select.select(0)
	_on_zone_selected(0)


func _update_info() -> void:
	if _selected == null:
		return
	var length: float = _selected.streams[0].get_length() if not _selected.streams.is_empty() else 0.0
	_info.text = "%d variante%s  ·  %.2f s  ·  bus %s%s%s" % [
		_selected.streams.size(), "s" if _selected.streams.size() > 1 else "", length, _selected.bus,
		"  ·  entendu à %.0f px par les ennemis" % _selected.noise_radius if _selected.noise_radius > 0.0 else "",
		"\n(modifié)" if AudioManager.is_tuned(_selected.id) else ""]


func _refresh_status(text: String) -> void:
	_status.text = text


static func _is_loop(entry: SoundEntry) -> bool:
	var wav: AudioStreamWAV = entry.streams[0] as AudioStreamWAV if not entry.streams.is_empty() else null
	return wav != null and wav.loop_mode != AudioStreamWAV.LOOP_DISABLED


static func _format(field: String, value: float) -> String:
	match field:
		"volume_db": return "%.1f dB" % value
		"pitch_random": return "± %.0f %%" % (value * 100.0)
		"volume_random_db": return "± %.1f dB" % value
		"noise_radius": return "%.0f px" % value
	return str(value)


# --------------------------------------------------------------------------
# Construction de l'interface
# --------------------------------------------------------------------------

func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("071212")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	# Titre et retour.
	var header := HBoxContainer.new()
	root.add_child(header)
	var title := _label("BANC D'ÉCOUTE", 26, ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(_button("Retour (Échap)", _back))

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 20)
	root.add_child(columns)

	# 1) Colonne de gauche : catégories et sons.
	var left := _column(columns, 360)
	left.add_child(_label("Catégorie", 15, ACCENT))
	_category_select = OptionButton.new()
	_category_select.item_selected.connect(_on_category_selected)
	left.add_child(_category_select)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(func(i: int) -> void: select_sound(_list_ids[i]))
	_list.item_activated.connect(func(i: int) -> void:
		select_sound(_list_ids[i])
		play_selected())
	left.add_child(_list)

	# 2) Colonne du milieu : le son choisi.
	var middle := _column(columns, 440)
	_name_label = _label("", 22, Color.WHITE)
	middle.add_child(_name_label)
	_description = _label("", 14, Color("b8d8d0"))
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description.custom_minimum_size.y = 40
	middle.add_child(_description)
	_info = _label("", 13, Color("8fb0a8"))
	middle.add_child(_info)
	var play_row := HBoxContainer.new()
	middle.add_child(play_row)
	play_row.add_child(_button("Jouer (Entrée)", play_selected))
	play_row.add_child(_button("Rafale x5", _play_burst))
	_loop_toggle = CheckButton.new()
	_loop_toggle.text = "Boucle"
	_loop_toggle.toggled.connect(_on_loop_toggled)
	play_row.add_child(_loop_toggle)
	var bus_row := HBoxContainer.new()
	middle.add_child(bus_row)
	bus_row.add_child(_label("Bus", 14, ACCENT))
	_bus_select = OptionButton.new()
	for bus: StringName in [AudioBuses.SFX, AudioBuses.VOICE, AudioBuses.AMBIENCE, AudioBuses.UI, AudioBuses.MUSIC]:
		_bus_select.add_item(String(bus))
	_bus_select.item_selected.connect(_on_bus_selected)
	bus_row.add_child(_bus_select)
	_add_slider(middle, "volume_db", "Volume", -40.0, 12.0, 0.5)
	_add_slider(middle, "pitch_random", "Variation de hauteur", 0.0, 0.5, 0.01)
	_add_slider(middle, "volume_random_db", "Variation de volume", 0.0, 12.0, 0.5)
	_add_slider(middle, "noise_radius", "Rayon de bruit (ennemis)", 0.0, 1500.0, 10.0)
	var tune_row := HBoxContainer.new()
	middle.add_child(tune_row)
	tune_row.add_child(_button("Rétablir ce son", _on_reset_pressed))
	tune_row.add_child(_button("Enregistrer", _on_save_pressed))
	tune_row.add_child(_button("Copier les valeurs", _on_copy_pressed))

	# 3) Colonne de droite : ambiances et effets.
	var right := _column(columns, 360)
	right.add_child(_label("Ambiance de zone", 15, ACCENT))
	_zone_select = OptionButton.new()
	_zone_select.item_selected.connect(_on_zone_selected)
	right.add_child(_zone_select)
	right.add_child(_button("Évènement ponctuel", _on_event_pressed))
	_zone_info = _label("", 13, Color("8fb0a8"))
	_zone_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_zone_info)
	right.add_child(HSeparator.new())
	right.add_child(_label("Effets", 15, ACCENT))
	_rewind_toggle = CheckButton.new()
	_rewind_toggle.text = "Rembobinage (son étouffé)"
	_rewind_toggle.toggled.connect(_on_rewind_toggled)
	right.add_child(_rewind_toggle)
	right.add_child(_button("Silence dramatique", _on_silence_pressed))
	right.add_child(_label("Volume général", 14, ACCENT))
	var volume := HSlider.new()
	volume.min_value = 0.0
	volume.max_value = 1.0
	volume.step = 0.01
	volume.value = Settings.get_volume(AudioBuses.MASTER)
	volume.value_changed.connect(_on_volume_changed)
	right.add_child(volume)
	right.add_child(HSeparator.new())
	_status = _label("", 13, Color("d8f8ee"))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_status)

	_category_select.grab_focus.call_deferred()


func _column(parent: Control, width: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = width
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.08, 0.08, 0.9)
	style.border_color = Color(0.43, 1, 0.75, 0.3)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	return box


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	return button


func _add_slider(parent: Control, field: String, text: String, min_value: float, max_value: float, step: float) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var name_label := _label(text, 14, ACCENT)
	name_label.custom_minimum_size.x = 200
	row.add_child(name_label)
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var value_label := _label("", 13, Color.WHITE)
	value_label.custom_minimum_size.x = 80
	row.add_child(value_label)
	_sliders[field] = slider
	_slider_values[field] = value_label
	slider.value_changed.connect(_on_slider_changed.bind(field))
