class_name PlayerFoley
extends Node
## Bruitages provisoires d'Élias (J2), déclenchés par les évènements
## d'animation (pied qui touche le sol, mains qui agrippent…).
##
## J5 remplacera ce tableau par la bibliothèque de sons centrale (sons selon la
## surface, respiration, rayon de bruit pour les ennemis). Le principe restera :
## c'est l'animation qui dit QUAND, ce script dit QUEL son.

const DIR: String = "res://assets/audio/generated/foley/"

## Évènement -> [fichiers, volume (dB), variation de hauteur].
## Plusieurs fichiers = une variante tirée au hasard à chaque fois.
const EVENTS: Dictionary = {
	&"footstep": [["foley_step_stone_01", "foley_step_stone_02", "foley_step_stone_03", "foley_step_stone_04"], -12.0, 1.08],
	&"footstep_run": [["foley_step_stone_01", "foley_step_stone_02", "foley_step_stone_03", "foley_step_stone_04"], -6.0, 1.1],
	&"footstep_soft": [["foley_step_stone_01", "foley_step_stone_03"], -24.0, 1.05],
	&"jump": [["foley_jump"], -9.0, 1.1],
	&"land": [["foley_land"], -6.0, 1.08],
	&"land_heavy": [["foley_land_heavy"], -2.0, 1.05],
	&"roll": [["foley_roll"], -6.0, 1.08],
	&"slide": [["foley_slide"], -6.0, 1.05],
	&"skid": [["foley_skid"], -10.0, 1.1],
	&"grab": [["foley_grab"], -6.0, 1.1],
	&"climb": [["foley_climb"], -8.0, 1.05],
	&"climb_knee": [["foley_step_stone_02"], -14.0, 1.1],
	&"body_fall": [["foley_body_fall"], -3.0, 1.0],
}

var _streams: Dictionary = {}  # évènement -> AudioStreamRandomizer


func _ready() -> void:
	for event_name: StringName in EVENTS:
		var spec: Array = EVENTS[event_name]
		# AudioStreamRandomizer : choisit une variante au hasard et fait varier
		# légèrement hauteur et volume, pour que deux pas ne sonnent jamais pareil.
		var randomizer := AudioStreamRandomizer.new()
		randomizer.random_pitch = spec[2]
		randomizer.random_volume_offset_db = 1.5
		for file: String in spec[0]:
			randomizer.add_stream(-1, load(DIR + file + ".wav"))
		_streams[event_name] = randomizer
	var player: Player = get_parent() as Player
	if player:
		player.anim_event.connect(_on_anim_event)


func _on_anim_event(event_name: StringName) -> void:
	if not _streams.has(event_name):
		return
	AudioManager.play_stream(_streams[event_name], AudioBuses.SFX, EVENTS[event_name][1])
