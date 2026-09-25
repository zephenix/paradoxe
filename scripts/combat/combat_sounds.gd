class_name CombatSounds
extends RefCounted
## Sons provisoires du combat (J3), générés par tools/audio/generate_sounds.py.
##
## Un seul endroit pour les trouver tous. L'arme, le bouclier et les projectiles
## sont les mêmes pour Élias et les Sentinelles (PLAN §5.2) : ils puisent ici.
## J5 remplacera ce tableau par la bibliothèque de sons centrale.

const DIR: String = "res://assets/audio/generated/combat/"

const SHOT: AudioStream = preload(DIR + "weapon_shot.wav")
const SHOT_CHARGED: AudioStream = preload(DIR + "weapon_shot_charged.wav")
const SHOT_SENTINEL: AudioStream = preload(DIR + "weapon_shot_sentinel.wav")
const CHARGE: AudioStream = preload(DIR + "weapon_charge.wav")
const CHARGE_READY: AudioStream = preload(DIR + "weapon_charge_ready.wav")
const EMPTY: AudioStream = preload(DIR + "weapon_empty.wav")
const DRAW: AudioStream = preload(DIR + "weapon_draw.wav")
const SHIELD_UP: AudioStream = preload(DIR + "shield_up.wav")
const SHIELD_LOOP: AudioStream = preload(DIR + "shield_loop.wav")
const SHIELD_DOWN: AudioStream = preload(DIR + "shield_down.wav")
const SHIELD_HIT: AudioStream = preload(DIR + "shield_hit.wav")
const SHIELD_BREAK: AudioStream = preload(DIR + "shield_break.wav")
const IMPACT_WALL: AudioStream = preload(DIR + "impact_wall.wav")
const IMPACT_BODY: AudioStream = preload(DIR + "impact_body.wav")
