extends SceneTree
## Construit ou complète la bibliothèque de sons (resources/audio/sound_library.tres)
## à partir des sons générés (assets/audio/generated/) et de leur catalogue
## (catalog.json, écrit par tools/audio/generate_sounds.py).
##
##   python3 tools/audio/generate_sounds.py        # 1) génère les sons
##   godot --headless --path . --import            # 2) Godot les importe
##   godot --headless --path . -s res://tools/godot/build_sound_library.gd   # 3) bibliothèque
##
## Les variantes d'un même son (foley_step_stone_01 à _04) deviennent UNE entrée
## (« foley_step_stone ») avec quatre fichiers. Une entrée qui existe déjà garde
## ses réglages (volume, rayon de bruit…) : seule sa liste de fichiers est mise à
## jour. On peut donc régler la bibliothèque dans l'inspecteur puis relancer l'outil
## sans rien perdre. Les réglages de départ d'un NOUVEAU son viennent des tables
## ci-dessous.

const LIBRARY_PATH: String = "res://resources/audio/sound_library.tres"
const SOUND_DIR: String = "res://assets/audio/generated"

## Réglages de départ par catégorie : [bus, volume dB, variation de hauteur].
const CATEGORY_DEFAULTS: Dictionary = {
	"foley": [&"SFX", -6.0, 0.08],
	"combat": [&"SFX", -3.0, 0.04],
	"creature": [&"Voix", -4.0, 0.0],   # la hauteur de voix est propre à chaque Sentinelle
	"voice": [&"Voix", -16.0, 0.05],
	"ambience": [&"Ambiance", -14.0, 0.12],
	"ui": [&"UI", -2.0, 0.02],
	"sfx": [&"SFX", -6.0, 0.0],
}

## Réglages de départ particuliers : identifiant -> {champ: valeur}.
## Les volumes suivent l'équilibrage mesuré par tools/audio/measure_levels.py
## (familles de sons au même niveau effectif).
## noise_radius : jusqu'où les ennemis entendent (pixels). Pour les pas, c'est le
## rayon d'un pas de COURSE ; la marche et la marche accroupie le réduisent
## (resources/audio/foley.tres).
const OVERRIDES: Dictionary = {
	&"foley_step_stone": {"volume_db": -6.0, "noise_radius": 300.0},
	&"foley_step_metal": {"volume_db": -2.5, "noise_radius": 420.0},
	&"foley_step_plant": {"volume_db": 1.5, "noise_radius": 240.0},
	&"foley_step_water": {"volume_db": -2.0, "noise_radius": 360.0},
	&"foley_jump": {"volume_db": -5.5, "noise_radius": 120.0},
	&"foley_land": {"volume_db": -6.0, "noise_radius": 300.0},
	&"foley_land_heavy": {"volume_db": -2.0, "noise_radius": 450.0},
	&"foley_roll": {"volume_db": -6.0, "noise_radius": 200.0},
	&"foley_slide": {"volume_db": -9.0, "noise_radius": 280.0},
	&"foley_skid": {"volume_db": -8.0, "noise_radius": 220.0},
	&"foley_grab": {"volume_db": -6.0, "noise_radius": 120.0},
	&"foley_climb": {"volume_db": -8.0, "noise_radius": 100.0},
	&"foley_body_fall": {"volume_db": -5.5, "noise_radius": 400.0},
	&"foley_turn": {"volume_db": -9.5},
	&"foley_crouch": {"volume_db": -11.5},
	&"weapon_shot": {"volume_db": -1.5, "noise_radius": 700.0},
	&"weapon_shot_charged": {"volume_db": -1.0, "noise_radius": 900.0},
	&"weapon_shot_sentinel": {"volume_db": -6.0, "noise_radius": 650.0},
	&"weapon_charge": {"volume_db": -8.0, "pitch_random": 0.0},
	&"weapon_charge_ready": {"volume_db": -10.0},
	&"weapon_empty": {"volume_db": -6.0, "noise_radius": 80.0},
	&"weapon_draw": {"volume_db": -10.0},
	&"weapon_holster": {"volume_db": -2.0},
	&"shield_up": {"volume_db": -16.0},
	&"shield_down": {"volume_db": -6.5},
	&"shield_loop": {"volume_db": -14.0, "pitch_random": 0.0, "volume_random_db": 0.0},
	&"shield_hit": {"volume_db": -6.0, "noise_radius": 250.0},
	&"shield_break": {"volume_db": -2.0, "noise_radius": 500.0},
	&"impact_wall": {"volume_db": -4.0, "noise_radius": 250.0},
	&"impact_body": {"volume_db": -9.0, "noise_radius": 150.0},
	&"breath_calm": {"volume_db": -24.0},
	&"breath_effort": {"volume_db": -18.0},
	&"breath_exhausted": {"volume_db": -13.0},
	&"ui_confirm": {"volume_db": -4.5},
	&"ui_move": {"volume_db": 4.5},
	&"ui_back": {"volume_db": -4.0},
	&"test_impact": {"volume_db": 0.0},
	&"portal_hum_loop": {"bus": &"Ambiance", "volume_db": -8.0, "pitch_random": 0.0, "volume_random_db": 0.0},
	&"checkpoint_on": {"volume_db": -8.0},
	&"rewind_loop": {"bus": &"UI", "pitch_random": 0.0, "volume_random_db": 0.0},
	&"rewind_release": {"bus": &"UI", "volume_db": -4.0},
	&"creature_alert": {"volume_db": -8.0},
	&"creature_death": {"volume_db": -7.0},
	&"creature_search": {"volume_db": -6.5},
	&"amb_debris": {"volume_db": -6.0},
	&"amb_electric_loop": {"volume_db": 6.5},
	&"lamp_break": {"volume_db": -2.5, "noise_radius": 450.0},
	&"stone_impact": {"volume_db": 0.5, "noise_radius": 520.0},
	&"stone_throw": {"volume_db": -12.0, "noise_radius": 60.0},
	&"stone_pickup": {"volume_db": -12.0, "noise_radius": 60.0},
	&"lever_pull": {"volume_db": -2.0, "noise_radius": 150.0},
	&"plate_click": {"volume_db": -1.0},
	&"door_slide": {"volume_db": -12.5, "noise_radius": 250.0},
	&"bars_clank": {"volume_db": -4.0, "noise_radius": 300.0},
	&"elevator_loop": {"volume_db": -16.0, "pitch_random": 0.0, "volume_random_db": 0.0},
	&"elevator_stop": {"volume_db": -9.0, "noise_radius": 250.0},
	&"terminal_beep": {"volume_db": -12.0},
	&"item_pickup": {"volume_db": 7.0},
	&"companion_ok": {"volume_db": -6.0},
	&"companion_follow": {"volume_db": -6.0},
	&"companion_wait": {"volume_db": -6.0},
	&"companion_no": {"volume_db": -6.0},
	&"companion_surprise": {"volume_db": -6.0},
	&"creature_menace": {"volume_db": -6.0},
	&"amb_chain": {"volume_db": -4.5},
}


func _initialize() -> void:
	var catalog: Dictionary = _read_catalog()
	if catalog.is_empty():
		push_error("catalog.json introuvable : lancer d'abord tools/audio/generate_sounds.py")
		quit(1)
		return
	var library: SoundLibrary = load(LIBRARY_PATH) if ResourceLoader.exists(LIBRARY_PATH) else SoundLibrary.new()
	# 1) Regroupe les variantes : « nom_01 », « nom_02 »… -> « nom ».
	var groups: Dictionary = {}  # identifiant -> [noms de fichiers]
	var variant := RegEx.create_from_string("_\\d\\d$")
	for file_name: String in catalog:
		var id := StringName(variant.sub(file_name, ""))
		if not groups.has(id):
			groups[id] = []
		groups[id].append(file_name)
	var added: int = 0
	for id: StringName in groups:
		var names: Array = groups[id]
		names.sort()
		var info: Dictionary = catalog[names[0]]
		var streams: Array[AudioStream] = []
		for file_name: String in names:
			var path: String = "%s/%s/%s.wav" % [SOUND_DIR, info["category"], file_name]
			var stream: AudioStream = load(path)
			if stream == null:
				push_error("Son introuvable : %s (réimporter le projet)" % path)
				continue
			streams.append(stream)
		var entry: SoundEntry = library.get_entry(id)
		if entry == null:
			entry = _new_entry(id, info)
			library.entries.append(entry)
			added += 1
		entry.streams = streams
	library.entries.sort_custom(func(a: SoundEntry, b: SoundEntry) -> bool: return String(a.id) < String(b.id))
	for entry in library.entries:
		if not groups.has(entry.id):
			push_warning("Entrée sans fichier : %s" % entry.id)
	var err: Error = ResourceSaver.save(library, LIBRARY_PATH)
	print("Bibliothèque : %d entrées (%d nouvelles) -> %s : %s" % [library.entries.size(), added, LIBRARY_PATH, error_string(err)])
	quit(0 if err == OK else 1)


func _new_entry(id: StringName, info: Dictionary) -> SoundEntry:
	var entry := SoundEntry.new()
	entry.id = id
	entry.category = StringName(info["category"])
	var defaults: Array = CATEGORY_DEFAULTS.get(info["category"], [&"SFX", -6.0, 0.05])
	entry.bus = defaults[0]
	entry.volume_db = defaults[1]
	entry.pitch_random = defaults[2]
	if info["loop"] or info["category"] == "creature":
		entry.volume_random_db = 0.0
	if String(info["category"]) == "ambience" and not info["loop"]:
		entry.volume_random_db = 3.0
	var description: String = info["description"]
	entry.description = RegEx.create_from_string(", variante \\d+").sub(description, "")
	var overrides: Dictionary = OVERRIDES.get(id, {})
	for field: String in overrides:
		entry.set(field, overrides[field])
	return entry


func _read_catalog() -> Dictionary:
	var text: String = FileAccess.get_file_as_string(SOUND_DIR + "/catalog.json")
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}
