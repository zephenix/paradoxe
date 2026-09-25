class_name PlayerFoley
extends Node
## Bruitages d'Élias (J5). Deux sources d'évènements :
##   - les pistes d'évènements des ANIMATIONS, pour ce qui doit tomber à l'image
##     près (pied qui touche le sol, corps qui s'effondre) ;
##   - les ÉTATS, pour les actions (saut, réception, demi-tour, accroupi…).
## C'est l'animation ou l'état qui dit QUAND ; ce script dit QUEL son, et le
## joue par la bibliothèque (AudioManager.play_sfx), qui prévient les ennemis
## selon le rayon de bruit du son.
##
## Trois nouveautés en J5 :
##   - les PAS dépendent du sol : sous les pieds, un rayon trouve le bloc et lit
##     sa « surface » (pierre, métal, plantes, eau) -> son « foley_step_<surface> » ;
##     l'allure (marche, course, accroupi) règle volume et rayon de bruit ;
##   - la RESPIRATION suit l'effort : calme, effort, essoufflement ;
##   - l'arme qu'on RENGAINE fait un petit bruit (sortie de l'état Aim).
##
## Réglages : resources/audio/foley.tres (FoleyConfig).

## Pseudo-son « pas » : le vrai son dépend de la surface sous les pieds.
const STEP: StringName = &"step"

## Évènement -> [identifiant du son (ou STEP), allure].
## L'allure (&"walk", &"run", &"soft", &"knee" ou &"") règle le volume et la
## portée du bruit (voir FoleyConfig).
const EVENTS: Dictionary = {
	&"footstep": [STEP, &"walk"],
	&"footstep_run": [STEP, &"run"],
	&"footstep_soft": [STEP, &"soft"],
	&"climb_knee": [STEP, &"knee"],
	&"jump": [&"foley_jump", &""],
	&"land": [&"foley_land", &""],
	&"land_heavy": [&"foley_land_heavy", &""],
	&"roll": [&"foley_roll", &""],
	&"slide": [&"foley_slide", &""],
	&"skid": [&"foley_skid", &""],
	&"grab": [&"foley_grab", &""],
	&"climb": [&"foley_climb", &""],
	&"body_fall": [&"foley_body_fall", &""],
	&"turn": [&"foley_turn", &""],
	&"crouch": [&"foley_crouch", &""],
}

## Surfaces connues (un son de pas « foley_step_<surface> » pour chacune).
const SURFACES: Array[StringName] = [&"stone", &"metal", &"plant", &"water"]

## Évènements volontairement muets (par préfixe). « death_<cause> » : le corps
## qui tombe est déjà joué par l'animation.
const SILENT_PREFIXES: Array[String] = ["death_"]

## États où l'arme est en main (quitter Aim vers un autre état = rengainer).
const ARMED_STATES: Array[StringName] = [&"Aim", &"Shoot", &"Charge", &"Shield", &"Dead"]

@export var config: FoleyConfig = preload("res://resources/audio/foley.tres")

## Effort de 0 (reposé) à 1 (épuisé).
var effort: float = 0.0
## Dernière surface foulée (utile pour le banc d'écoute et les tests).
var last_surface: StringName = &"stone"

var _player: Player
var _breath_timer: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_player = get_parent() as Player
	if _player == null:
		return
	_player.anim_event.connect(_on_anim_event)
	# Les enfants sont prêts AVANT leur parent : on attend qu'Élias le soit
	# (ses variables @onready, dont « machine », sont remplies à ce moment-là).
	if not _player.is_node_ready():
		await _player.ready
	_player.machine.state_changed.connect(_on_state_changed)
	_breath_timer = config.breath_interval_calm


func _physics_process(delta: float) -> void:
	if _player == null or _player.is_dead:
		return
	# Effort : monte en courant, redescend sinon.
	if _player.machine.current_name == &"Run":
		effort += config.effort_run_per_second * delta
	else:
		effort -= config.effort_decay_per_second * delta
	effort = clampf(effort, 0.0, 1.0)
	_breath_timer -= delta
	if _breath_timer <= 0.0:
		var tier: StringName = breath_tier()
		AudioManager.play_sfx(StringName("breath_" + String(tier)), _player.global_position + Vector2(0, -150), _player)
		_breath_timer = _interval(tier) + _rng.randf_range(-config.breath_interval_jitter, config.breath_interval_jitter)


## Palier de respiration actuel : &"calm", &"effort" ou &"exhausted".
func breath_tier() -> StringName:
	if effort >= config.exhausted_tier:
		return &"exhausted"
	if effort >= config.effort_tier:
		return &"effort"
	return &"calm"


func _interval(tier: StringName) -> float:
	match tier:
		&"exhausted": return config.breath_interval_exhausted
		&"effort": return config.breath_interval_effort
	return config.breath_interval_calm


func _on_anim_event(event_name: StringName) -> void:
	if not EVENTS.has(event_name):
		if not is_silent(event_name):
			push_warning("PlayerFoley : aucun son pour l'évènement « %s »" % event_name)
		return
	var spec: Array = EVENTS[event_name]
	var sound_id: StringName = spec[0]
	var gait: StringName = spec[1]
	if sound_id == STEP:
		last_surface = surface_under_feet()
		sound_id = step_sound_for(last_surface)
	AudioManager.play_sfx(sound_id, _player.global_position, _player,
			config.gait_volume_db(gait), config.gait_noise(gait))
	effort = minf(effort + config.effort_of(event_name), 1.0)


## Rengainer : on quitte l'état Aim pour un état sans arme (pas au retour d'un
## rembobinage : l'état repris n'est pas un geste).
func _on_state_changed(from: StringName, to: StringName) -> void:
	if from == &"Aim" and not ARMED_STATES.has(to) and not RewindManager.is_rewinding:
		_player.weapon.play_holster_sound()


## Nature du sol sous les pieds d'Élias (&"stone" si le bloc ne précise rien).
func surface_under_feet() -> StringName:
	var from: Vector2 = _player.global_position + Vector2(0, -4)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, config.surface_probe + 4.0),
			PhysicsLayers.WORLD, [_player.get_rid()])
	var hit: Dictionary = _player.get_world_2d().direct_space_state.intersect_ray(query)
	var block: SolidBlock = hit.get("collider") as SolidBlock
	if block and SURFACES.has(block.surface):
		return block.surface
	return config.default_surface


## Son de pas d'une surface.
static func step_sound_for(surface: StringName) -> StringName:
	return StringName("foley_step_" + String(surface))


## Vrai si l'évènement est volontairement sans son.
static func is_silent(event_name: StringName) -> bool:
	for prefix in SILENT_PREFIXES:
		if String(event_name).begins_with(prefix):
			return true
	return false
