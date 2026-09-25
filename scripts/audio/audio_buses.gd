class_name AudioBuses
extends RefCounted
## Noms et organisation des bus audio : LA référence unique du projet.
##
## Un « bus » est une table de mixage : plusieurs sons y arrivent, on y règle
## un volume commun et on peut y brancher des effets (réverbération, filtre…).
## Chaque bus envoie ensuite sa sortie vers un autre bus, jusqu'au Master.
##
##     SFX ──┐
##     Voix ─┼──► Monde (réverb + filtre de la salle) ──┐
##  Ambiance ┘                                          ├──► Master (étouffement + gain + limiteur)
##               Musique ───────────────────────────────┤
##               UI ────────────────────────────────────┘
##
## Le fichier res://default_bus_layout.tres est GÉNÉRÉ à partir de ce script par
## tools/godot/generate_bus_layout.gd : pour changer l'organisation des bus,
## modifie ce fichier puis relance le générateur (voir docs/SOUND_DESIGN.md).

const MASTER: StringName = &"Master"
const MUSIC: StringName = &"Musique"
const UI: StringName = &"UI"
const WORLD: StringName = &"Monde"  # bus intermédiaire : sons « dans le monde du jeu »
const AMBIENCE: StringName = &"Ambiance"
const SFX: StringName = &"SFX"
const VOICE: StringName = &"Voix"

## Ordre des bus dans le mixeur. Contrainte de Godot : un bus ne peut envoyer
## sa sortie que vers un bus situé AVANT lui dans la liste.
const ORDER: Array[StringName] = [MASTER, MUSIC, UI, WORLD, AMBIENCE, SFX, VOICE]

## Destination de chaque bus (le Master n'a pas de destination).
const SENDS: Dictionary = {
	MUSIC: MASTER,
	UI: MASTER,
	WORLD: MASTER,
	AMBIENCE: WORLD,
	SFX: WORLD,
	VOICE: WORLD,
}

## Bus dont le joueur règle le volume dans les options (Monde est interne).
const PLAYER_ADJUSTABLE: Array[StringName] = [MASTER, MUSIC, AMBIENCE, SFX, VOICE, UI]

## Libellés affichés dans le menu d'options.
const LABELS: Dictionary = {
	MASTER: "Général",
	MUSIC: "Musique",
	AMBIENCE: "Ambiance",
	SFX: "Effets sonores",
	VOICE: "Voix",
	UI: "Interface",
}

## Position des effets dans la chaîne de chaque bus (0 = premier effet).
const MASTER_FX_LOWPASS: int = 0  # étouffement : rembobinage, sonné, coupures
const MASTER_FX_GAIN: int = 1     # gain « dramatique » : silences et fondus de mise en scène
const MASTER_FX_LIMITER: int = 2  # évite la saturation
const WORLD_FX_REVERB: int = 0    # réverbération de la salle
const WORLD_FX_LOWPASS: int = 1   # filtre de la salle (jungle étouffée, sous l'eau…)

## Fréquence de coupure d'un passe-bas « transparent » (laisse tout passer).
const LOWPASS_OPEN_HZ: float = 20500.0


## Index d'un bus dans le mixeur (-1 s'il n'existe pas).
static func index(bus: StringName) -> int:
	return AudioServer.get_bus_index(bus)
