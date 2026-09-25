class_name SoundEntry
extends Resource
## Un son de la bibliothèque (PLAN §6.3) : ses fichiers (variantes), son bus,
## son volume, ses variations aléatoires, et son RAYON DE BRUIT, c'est-à-dire
## jusqu'où les ennemis l'entendent. Un seul système pour ce que le joueur
## entend et ce que les ennemis entendent.

## Identifiant utilisé par le code : AudioManager.play_sfx(&"foley_jump").
@export var id: StringName = &""
## Catégorie (foley, combat, creature, voice, ambience, ui, sfx) : sert au banc d'écoute.
@export var category: StringName = &"sfx"
## Variantes : une est tirée au hasard à chaque lecture.
@export var streams: Array[AudioStream] = []
## Bus de destination (voir AudioBuses) : SFX, Voix, Ambiance, UI…
@export var bus: StringName = &"SFX"
## Volume de base (dB).
@export_range(-40.0, 12.0, 0.5) var volume_db: float = 0.0
## Variation de hauteur à chaque lecture (0,05 = ± 5 %).
@export_range(0.0, 0.5, 0.01) var pitch_random: float = 0.05
## Variation de volume à chaque lecture (± dB).
@export_range(0.0, 12.0, 0.5) var volume_random_db: float = 1.5
## Rayon de bruit (pixels) : les ennemis à cette distance l'entendent. 0 = inaudible pour eux.
@export var noise_radius: float = 0.0
## À quoi sert ce son (repris du générateur).
@export_multiline var description: String = ""


## Tire une variante au hasard.
func pick(rng: RandomNumberGenerator) -> AudioStream:
	if streams.is_empty():
		return null
	return streams[rng.randi_range(0, streams.size() - 1)]


## Réglages modifiables (banc d'écoute) : {"bus", "volume_db", "pitch_random",
## "volume_random_db", "noise_radius"}.
func get_tuning() -> Dictionary:
	return {"bus": String(bus), "volume_db": volume_db, "pitch_random": pitch_random,
			"volume_random_db": volume_random_db, "noise_radius": noise_radius}


## Applique des réglages (seuls les champs présents et connus sont pris).
func set_tuning(values: Dictionary) -> void:
	if values.has("bus"):
		bus = StringName(values["bus"])
	for field: String in ["volume_db", "pitch_random", "volume_random_db", "noise_radius"]:
		if values.has(field):
			set(field, float(values[field]))
