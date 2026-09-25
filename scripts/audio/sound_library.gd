class_name SoundLibrary
extends Resource
## La bibliothèque de sons du jeu (resources/audio/sound_library.tres).
##
## Chaque entrée (SoundEntry) se règle dans l'inspecteur de Godot : volume,
## variations, bus, rayon de bruit. L'outil tools/godot/build_sound_library.gd
## ajoute les sons nouvellement générés SANS toucher aux réglages existants.
##
## Analogie Excel : un tableau dont chaque ligne est un son (identifiant,
## fichiers, volume, rayon…) ; le code fait une « RECHERCHEV » sur l'identifiant.

@export var entries: Array[SoundEntry] = []

var _by_id: Dictionary = {}  # identifiant -> SoundEntry (index construit à la demande)


## L'entrée d'un identifiant, ou null.
func get_entry(id: StringName) -> SoundEntry:
	if _by_id.size() != entries.size():
		_rebuild_index()
	return _by_id.get(id)


func has(id: StringName) -> bool:
	return get_entry(id) != null


## Catégories présentes, dans l'ordre alphabétique.
func categories() -> Array[StringName]:
	var found: Array[StringName] = []
	for entry in entries:
		if not found.has(entry.category):
			found.append(entry.category)
	found.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return found


## Entrées d'une catégorie, par identifiant.
func in_category(category: StringName) -> Array[SoundEntry]:
	var found: Array[SoundEntry] = entries.filter(func(e: SoundEntry) -> bool: return e.category == category)
	found.sort_custom(func(a: SoundEntry, b: SoundEntry) -> bool: return String(a.id) < String(b.id))
	return found


func _rebuild_index() -> void:
	_by_id.clear()
	for entry in entries:
		_by_id[entry.id] = entry
