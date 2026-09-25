extends TestCase
## Vérifie la correspondance entre les évènements sonores d'Élias et ses
## bruitages (PlayerFoley), dans les deux sens :
##   - chaque évènement émis (par une animation ou par un état) a un son, ou
##     est déclaré volontairement muet ;
##   - chaque son déclaré correspond à un évènement réellement émis.

const STATES_DIR: String = "res://scripts/player/states"


## Évènements émis par les pistes d'animation (tables de poses).
func _animation_events() -> Array[String]:
	var names: Array[String] = []
	for anim_name: String in EliasPoses.ANIMATIONS:
		for event: Array in EliasPoses.ANIMATIONS[anim_name].get("events", []):
			if not names.has(event[1]):
				names.append(event[1])
	return names


## Évènements émis par les états : on lit leur code source et, sur chaque
## ligne qui appelle « anim_event.emit », on relève tous les noms &"…" (il peut
## y en avoir deux : &"land_heavy" if heavy else &"land"). &"death_" + cause
## donne le préfixe « death_ ».
func _state_events() -> Array[String]:
	var names: Array[String] = []
	var regex := RegEx.create_from_string("&\"([a-z_]+)\"")
	for file in DirAccess.get_files_at(STATES_DIR):
		if not file.ends_with(".gd"):
			continue
		var source: String = FileAccess.get_file_as_string(STATES_DIR.path_join(file))
		for line in source.split("\n"):
			if not line.contains("anim_event.emit"):
				continue
			var found: Array[String] = []
			for m in regex.search_all(line):
				found.append(m.get_string(1))
			# Un nom qui finit par « _ » est un préfixe (&"death_" + cause) : les
			# autres noms de la ligne sont alors des paramètres, pas des évènements.
			var prefixes: Array[String] = found.filter(func(n: String) -> bool: return n.ends_with("_"))
			for event_name in (prefixes if not prefixes.is_empty() else found):
				if not names.has(event_name):
					names.append(event_name)
	return names


func test_every_emitted_event_has_a_sound_or_is_silent() -> void:
	var emitted: Array[String] = _animation_events() + _state_events()
	assert_true(emitted.size() >= 10, "évènements trouvés : %s" % [emitted])
	for event_name in emitted:
		var covered: bool = PlayerFoley.EVENTS.has(StringName(event_name)) or PlayerFoley.is_silent(StringName(event_name))
		assert_true(covered, "l'évènement « %s » n'a pas de son" % event_name)


func test_every_sound_matches_an_emitted_event() -> void:
	var emitted: Array[String] = _animation_events() + _state_events()
	for event_name: StringName in PlayerFoley.EVENTS:
		assert_true(emitted.has(String(event_name)), "le son « %s » n'est déclenché par rien" % event_name)


func test_death_events_are_intentionally_silent() -> void:
	assert_true(PlayerFoley.is_silent(&"death_fall"))
	assert_false(PlayerFoley.is_silent(&"footstep"))


func test_every_sound_exists_in_the_library() -> void:
	for event_name: StringName in PlayerFoley.EVENTS:
		var sound_id: StringName = PlayerFoley.EVENTS[event_name][0]
		if sound_id != PlayerFoley.STEP:
			assert_true(AudioManager.library.has(sound_id), "%s -> %s" % [event_name, sound_id])
	for surface: StringName in PlayerFoley.SURFACES:
		assert_true(AudioManager.library.has(PlayerFoley.step_sound_for(surface)), "pas sur %s" % surface)
	for tier: String in ["calm", "effort", "exhausted"]:
		assert_true(AudioManager.library.has(StringName("breath_" + tier)), "respiration %s" % tier)
