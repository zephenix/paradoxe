class_name EliasPoses
extends RefCounted
## Tables de poses et d'animations d'Élias (silhouette polygonale provisoire).
## Les Sentinelles (J3) partagent ce squelette et ces animations : leurs gestes
## sont humains, et c'est voulu (PLAN §4.3, indices du twist).
##
## Une POSE est un dictionnaire « articulation → valeur ». Les angles sont en
## degrés, avec une convention unique : POSITIF = VERS L'AVANT (dans le sens du
## regard). Une cuisse à +30 lance la jambe vers l'avant ; un tibia à -60 plie le
## genou ; un buste à +20 se penche en avant. Les articulations absentes d'une
## pose prennent la valeur de la pose « stand ».
##
## Une ANIMATION est une suite de poses clés datées (en secondes), plus des
## évènements (bruits de pas…) émis à des instants précis.
##
## Pour retoucher une animation : modifier les nombres ci-dessous, relancer le
## jeu. Pour voir toutes les poses d'un coup :
##     ./tools/screenshot.sh res://tools/godot/pose_sheet.tscn build/shots/poses.png

## Position du bassin du rig (Rig) et des hanches (Hips), en pixels, pieds en (0, 0).
const RIG_Y: float = -24.0
const HIPS_Y: float = -22.0

## Articulations : [nœud, propriété animée, signe, valeur de base].
##   - nœud : nom du pivot dans le squelette (voir EliasVisual) ;
##   - signe : les membres « pendants » (bras, jambes, pans) tournent en sens
##     inverse du buste et de la tête pour aller vers l'avant, d'où -1 ;
##   - valeur de base : ajoutée aux positions (pixels). Ignorée pour les angles,
##     dont la valeur de repos est toujours 0°.
const JOINTS: Dictionary = {
	"rig_rot": ["rig", "rotation", 1.0, 0.0],
	"rig_y": ["rig", "position:y", 1.0, RIG_Y],
	"rig_sx": ["rig", "scale:x", 1.0, 0.0],
	"hips_y": ["hips", "position:y", 1.0, HIPS_Y],
	"torso": ["torso", "rotation", 1.0, 0.0],
	"head": ["head", "rotation", 1.0, 0.0],
	"arm_b": ["arm_b", "rotation", -1.0, 0.0],
	"fore_b": ["fore_b", "rotation", -1.0, 0.0],
	"arm_f": ["arm_f", "rotation", -1.0, 0.0],
	"fore_f": ["fore_f", "rotation", -1.0, 0.0],
	"thigh_b": ["thigh_b", "rotation", -1.0, 0.0],
	"shin_b": ["shin_b", "rotation", -1.0, 0.0],
	"thigh_f": ["thigh_f", "rotation", -1.0, 0.0],
	"shin_f": ["shin_f", "rotation", -1.0, 0.0],
	"coat": ["coat", "rotation", -1.0, 0.0],
}

## Poses de référence.
const POSES: Dictionary = {
	"stand": {"rig_rot": 0, "rig_y": 0, "rig_sx": 1, "hips_y": 0, "torso": 2, "head": 0,
		"arm_b": 6, "fore_b": 10, "arm_f": -4, "fore_f": 8,
		"thigh_b": -2, "shin_b": 0, "thigh_f": 3, "shin_f": -2, "coat": 0},
	"breath": {"torso": 4, "head": -2, "hips_y": 1, "arm_b": 8, "arm_f": -2, "fore_f": 12},
	# Marche : contact (talon avant posé) puis passage (jambe arrière qui ramène).
	"walk_contact": {"thigh_f": 24, "shin_f": -4, "thigh_b": -20, "shin_b": -12,
		"arm_f": -20, "fore_f": 12, "arm_b": 20, "fore_b": 18, "torso": 4, "hips_y": 2, "coat": -6},
	"walk_pass": {"thigh_f": -2, "shin_f": -2, "thigh_b": 14, "shin_b": -45,
		"arm_f": 0, "fore_f": 10, "arm_b": 2, "fore_b": 12, "torso": 3, "hips_y": -1, "coat": -3},
	# Course : grande amplitude, buste penché, avant-bras pliés.
	"run_contact": {"thigh_f": 42, "shin_f": -18, "thigh_b": -34, "shin_b": -50,
		"arm_f": -50, "fore_f": 75, "arm_b": 45, "fore_b": 85, "torso": 14, "hips_y": 3, "coat": -22},
	"run_pass": {"thigh_f": -8, "shin_f": -30, "thigh_b": 55, "shin_b": -105,
		"arm_f": 5, "fore_f": 80, "arm_b": -5, "fore_b": 80, "torso": 12, "hips_y": -4, "coat": -30},
	"skid": {"torso": -14, "thigh_f": 34, "shin_f": -8, "thigh_b": -12, "shin_b": -50, "hips_y": 9,
		"arm_f": 40, "fore_f": 30, "arm_b": 55, "fore_b": 35, "coat": 20},
	# Accroupi : genoux pliés, buste penché ; hauteur totale ≈ 1,2 bloc.
	"crouch": {"hips_y": 24, "thigh_f": 75, "shin_f": -125, "thigh_b": 60, "shin_b": -120,
		"torso": 42, "head": -25, "arm_f": 25, "fore_f": 40, "arm_b": 15, "fore_b": 35, "coat": -40},
	"crouch_step": {"hips_y": 23, "thigh_f": 85, "shin_f": -110, "thigh_b": 45, "shin_b": -125,
		"torso": 40, "head": -24, "arm_f": 35, "fore_f": 40, "arm_b": 5, "fore_b": 35, "coat": -40},
	"windup": {"hips_y": 10, "thigh_f": 40, "shin_f": -65, "thigh_b": 32, "shin_b": -65,
		"torso": 18, "arm_f": -35, "fore_f": 20, "arm_b": -40, "fore_b": 20, "coat": -10},
	"jump": {"thigh_f": 25, "shin_f": -40, "thigh_b": -8, "shin_b": -25, "torso": 0, "head": -8,
		"arm_f": 165, "fore_f": 10, "arm_b": 150, "fore_b": 15, "coat": 12},
	"leap": {"thigh_f": 65, "shin_f": -55, "thigh_b": -45, "shin_b": -35, "torso": 18,
		"arm_f": 70, "fore_f": 25, "arm_b": -55, "fore_b": 20, "coat": 25},
	"fall": {"thigh_f": 18, "shin_f": -28, "thigh_b": -6, "shin_b": -30, "torso": 4, "head": -6,
		"arm_f": 120, "fore_f": 25, "arm_b": 95, "fore_b": 30, "coat": 35},
	"land": {"hips_y": 12, "thigh_f": 45, "shin_f": -75, "thigh_b": 38, "shin_b": -75,
		"torso": 20, "arm_f": 25, "fore_f": 20, "arm_b": 20, "fore_b": 20, "coat": -12},
	"land_heavy": {"hips_y": 22, "thigh_f": 70, "shin_f": -120, "thigh_b": 55, "shin_b": -115,
		"torso": 45, "head": -20, "arm_f": 60, "fore_f": 10, "arm_b": 50, "fore_b": 10, "coat": -35},
	# Roulade : boule serrée qui tourne sur elle-même.
	"tuck": {"hips_y": 16, "thigh_f": 115, "shin_f": -145, "thigh_b": 105, "shin_b": -145,
		"torso": 70, "head": 20, "arm_f": 70, "fore_f": 60, "arm_b": 60, "fore_b": 60, "coat": -60},
	"slide": {"hips_y": 26, "rig_y": 4, "torso": -40, "head": 15, "thigh_f": 80, "shin_f": -8,
		"thigh_b": 35, "shin_b": -115, "arm_f": 35, "fore_f": 15, "arm_b": -45, "fore_b": 10, "coat": 40},
	# Suspendu : bras tendus au-dessus de la tête, mains à ~104 px des pieds.
	"hang": {"torso": 0, "head": -12, "arm_f": 178, "fore_f": 2, "arm_b": 172, "fore_b": 4,
		"thigh_f": 6, "shin_f": -6, "thigh_b": -4, "shin_b": -10, "coat": 4},
	"pull": {"torso": 12, "head": -8, "arm_f": 150, "fore_f": 95, "arm_b": 145, "fore_b": 95,
		"thigh_f": 60, "shin_f": -85, "thigh_b": 10, "shin_b": -40, "coat": -10},
	"mantle": {"hips_y": 14, "torso": 55, "head": -15, "arm_f": 35, "fore_f": 5, "arm_b": 25, "fore_b": 5,
		"thigh_f": 95, "shin_f": -120, "thigh_b": 20, "shin_b": -60, "coat": -30},
	"sit_edge": {"hips_y": 22, "torso": 25, "head": -10, "arm_f": 50, "fore_f": 20, "arm_b": 40,
		"fore_b": 20, "thigh_f": 80, "shin_f": -95, "thigh_b": 70, "shin_b": -95, "coat": -30},
	"collapse": {"hips_y": 22, "torso": 45, "head": 25, "arm_f": 30, "fore_f": 20, "arm_b": 20, "fore_b": 30,
		"thigh_f": 70, "shin_f": -120, "thigh_b": 50, "shin_b": -110, "coat": -30},
	"lying": {"rig_rot": -88, "rig_y": 17, "hips_y": 0, "torso": 4, "head": -10,
		"arm_f": 30, "fore_f": 20, "arm_b": -20, "fore_b": 10, "thigh_f": 12, "shin_f": -15,
		"thigh_b": -5, "shin_b": -5, "coat": 10},
	"squeeze": {"rig_sx": 0.12},
	# Combat (J3). Bras avant à 90° : tendu à l'horizontale, pistolet au bout.
	"aim": {"torso": 0, "head": -2, "hips_y": 1, "arm_f": 90, "fore_f": 0, "arm_b": 40, "fore_b": 70,
		"thigh_f": 14, "shin_f": -6, "thigh_b": -12, "shin_b": -4, "coat": 2},
	"recoil": {"torso": -3, "head": -4, "hips_y": 1, "arm_f": 97, "fore_f": 3, "arm_b": 36, "fore_b": 70,
		"thigh_f": 14, "shin_f": -6, "thigh_b": -12, "shin_b": -4, "coat": 6},
	"charge": {"torso": 5, "head": 0, "hips_y": 4, "arm_f": 88, "fore_f": 0, "arm_b": 72, "fore_b": 25,
		"thigh_f": 20, "shin_f": -18, "thigh_b": -16, "shin_b": -12, "coat": -2},
	"guard": {"torso": -6, "head": -8, "hips_y": 5, "arm_f": 75, "fore_f": 40, "arm_b": 55, "fore_b": 60,
		"thigh_f": 22, "shin_f": -16, "thigh_b": -20, "shin_b": -12, "coat": 8},
	# Lancer (J6) : bras armé derrière la tête, puis fouetté vers l'avant.
	"throw_back": {"torso": -8, "head": -6, "hips_y": 2, "arm_f": -130, "fore_f": 70, "arm_b": 45, "fore_b": 20,
		"thigh_f": 18, "shin_f": -8, "thigh_b": -14, "shin_b": -6, "coat": 6},
	"throw_release": {"torso": 16, "head": -2, "hips_y": 3, "arm_f": 115, "fore_f": 10, "arm_b": -25, "fore_b": 20,
		"thigh_f": 24, "shin_f": -14, "thigh_b": -18, "shin_b": -10, "coat": -8},
	"crouch_throw_back": {"hips_y": 24, "thigh_f": 75, "shin_f": -125, "thigh_b": 60, "shin_b": -120,
		"torso": 25, "head": -18, "arm_f": -120, "fore_f": 70, "arm_b": 20, "fore_b": 30, "coat": -40},
	"crouch_throw_release": {"hips_y": 24, "thigh_f": 75, "shin_f": -125, "thigh_b": 60, "shin_b": -120,
		"torso": 45, "head": -25, "arm_f": 105, "fore_f": 10, "arm_b": 10, "fore_b": 30, "coat": -40},
	# À genou (tir bas des Sentinelles) : jambes de l'accroupi, buste droit.
	"kneel_aim": {"hips_y": 24, "thigh_f": 75, "shin_f": -125, "thigh_b": 60, "shin_b": -120,
		"torso": 8, "head": -4, "arm_f": 82, "fore_f": 0, "arm_b": 40, "fore_b": 70, "coat": -40},
}

## Animations : longueur (s), boucle, poses clés [instant, pose, retouches éventuelles],
## évènements [instant, nom].
const ANIMATIONS: Dictionary = {
	"idle": {"length": 2.4, "loop": true, "keys": [[0.0, "stand"], [1.2, "breath"], [2.4, "stand"]]},
	"walk": {"length": 1.0, "loop": true,
		"keys": [[0.0, "walk_contact"], [0.25, "walk_pass"], [0.5, "walk_contact", true],
			[0.75, "walk_pass", true], [1.0, "walk_contact"]],
		"events": [[0.02, "footstep"], [0.52, "footstep"]]},
	"run": {"length": 0.6, "loop": true,
		"keys": [[0.0, "run_contact"], [0.15, "run_pass"], [0.3, "run_contact", true],
			[0.45, "run_pass", true], [0.6, "run_contact"]],
		"events": [[0.02, "footstep_run"], [0.32, "footstep_run"]]},
	"skid": {"length": 0.3, "keys": [[0.0, "run_contact"], [0.08, "skid"], [0.3, "skid"]],
		"events": [[0.05, "skid"]]},
	"turn": {"length": 0.2, "keys": [[0.0, "stand"], [0.1, "squeeze"], [0.2, "stand"]]},
	"crouch": {"length": 0.15, "keys": [[0.0, "land"], [0.15, "crouch"]]},
	"crouch_walk": {"length": 1.2, "loop": true,
		"keys": [[0.0, "crouch"], [0.3, "crouch_step"], [0.6, "crouch"], [0.9, "crouch_step", true], [1.2, "crouch"]],
		"events": [[0.3, "footstep_soft"], [0.9, "footstep_soft"]]},
	"jump_windup": {"length": 0.1, "keys": [[0.0, "stand"], [0.1, "windup"]]},
	"jump": {"length": 0.25, "keys": [[0.0, "windup"], [0.25, "jump"]]},
	"leap": {"length": 0.25, "keys": [[0.0, "run_contact"], [0.25, "leap"]]},
	"fall": {"length": 0.4, "keys": [[0.0, "jump"], [0.4, "fall"]]},
	"land": {"length": 0.12, "keys": [[0.0, "land"], [0.12, "stand"]]},
	"land_heavy": {"length": 0.45, "keys": [[0.0, "land_heavy"], [0.3, "land_heavy"], [0.45, "stand"]]},
	"roll": {"length": 0.5,
		"keys": [[0.0, "land"], [0.08, "tuck"], [0.42, "tuck", false, {"rig_rot": 360}], [0.5, "crouch", false, {"rig_rot": 360}]]},
	"slide": {"length": 0.2, "keys": [[0.0, "run_contact"], [0.2, "slide"]]},
	"hang": {"length": 2.0, "loop": true,
		"keys": [[0.0, "hang"], [1.0, "hang", false, {"thigh_f": 10, "thigh_b": 2, "coat": 8}], [2.0, "hang"]]},
	"climb": {"length": 0.6, "keys": [[0.0, "hang"], [0.25, "pull"], [0.4, "mantle"], [0.6, "stand"]],
		"events": [[0.35, "climb_knee"]]},
	"descend": {"length": 0.5, "keys": [[0.0, "stand"], [0.18, "sit_edge"], [0.35, "pull"], [0.5, "hang"]]},
	# Combat (J3). « shoot » dure fire_cooldown (réglage de l'arme).
	"aim": {"length": 1.6, "loop": true, "keys": [[0.0, "aim"], [0.8, "aim", false, {"torso": 2, "hips_y": 2}], [1.6, "aim"]]},
	"shoot": {"length": 0.28, "keys": [[0.0, "aim"], [0.04, "recoil"], [0.14, "aim"], [0.28, "aim"]]},
	"charge": {"length": 0.3, "loop": true, "keys": [[0.0, "charge"], [0.15, "charge", false, {"arm_f": 86, "hips_y": 5}], [0.3, "charge"]]},
	"shield": {"length": 0.15, "keys": [[0.0, "aim"], [0.15, "guard"]]},
	"kneel_aim": {"length": 0.2, "keys": [[0.0, "crouch"], [0.2, "kneel_aim"]]},
	"kneel_shoot": {"length": 0.28, "keys": [[0.0, "kneel_aim"], [0.05, "kneel_aim", false, {"arm_f": 96, "torso": 2}], [0.28, "kneel_aim"]]},
	# Lancer (J6) : dure throw_config.duration (resources/player/throw.tres).
	"throw": {"length": 0.4, "keys": [[0.0, "stand"], [0.12, "throw_back"], [0.2, "throw_release"], [0.4, "stand"]]},
	"crouch_throw": {"length": 0.4,
		"keys": [[0.0, "crouch"], [0.12, "crouch_throw_back"], [0.2, "crouch_throw_release"], [0.4, "crouch"]]},
	"death": {"length": 0.8, "keys": [[0.0, "land_heavy"], [0.25, "collapse"], [0.7, "lying"], [0.8, "lying"]],
		"events": [[0.62, "body_fall"]]},
}


## Construit la bibliothèque d'animations à partir des tables.
## joint_paths : chemin de chaque nœud articulé, fourni par EliasVisual.
static func build_library(joint_paths: Dictionary) -> AnimationLibrary:
	var library := AnimationLibrary.new()
	for anim_name: String in ANIMATIONS:
		library.add_animation(StringName(anim_name), _build_animation(ANIMATIONS[anim_name], joint_paths))
	return library


## Valeur complète d'une articulation pour une clé [instant, pose, miroir?, retouches?].
## « miroir » échange les membres avant et arrière (pas suivant de la marche).
static func pose_value(key: Array, joint: String) -> float:
	var pose: Dictionary = POSES[key[1]]
	var mirrored: bool = key.size() > 2 and key[2]
	var source_joint: String = joint
	if mirrored:
		if joint.ends_with("_f"):
			source_joint = joint.trim_suffix("_f") + "_b"
		elif joint.ends_with("_b"):
			source_joint = joint.trim_suffix("_b") + "_f"
	var overrides: Dictionary = key[3] if key.size() > 3 else {}
	if overrides.has(joint):
		return float(overrides[joint])
	if pose.has(source_joint):
		return float(pose[source_joint])
	return float(POSES["stand"].get(joint, 0.0))


static func _build_animation(spec: Dictionary, joint_paths: Dictionary) -> Animation:
	var anim := Animation.new()
	anim.length = spec["length"]
	anim.loop_mode = Animation.LOOP_LINEAR if spec.get("loop", false) else Animation.LOOP_NONE
	for joint: String in JOINTS:
		var def: Array = JOINTS[joint]
		var track: int = anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(track, NodePath(String(joint_paths[def[0]]) + ":" + def[1]))
		anim.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
		for key: Array in spec["keys"]:
			var value: float = pose_value(key, joint)
			var is_angle: bool = def[1] == "rotation"
			var final_value: float = deg_to_rad(value) * def[2] if is_angle else value * def[2] + def[3]
			anim.track_insert_key(track, key[0], final_value)
	if spec.has("events"):
		var events: int = anim.add_track(Animation.TYPE_METHOD)
		anim.track_set_path(events, NodePath("."))
		for event: Array in spec["events"]:
			anim.track_insert_key(events, event[0], {"method": &"emit_anim_event", "args": [StringName(event[1])]})
	return anim
