class_name Weapon
extends Node2D
## L'arme à énergie d'un personnage, et son bouclier (Élias et Sentinelles).
##
## Ce nœud est un enfant du personnage, placé à ses pieds. Il ne décide de rien :
## ce sont les états du personnage (Aim, Shoot, Charge, Shield pour Élias ; le
## combat des Sentinelles) qui appellent ses fonctions :
##     weapon.fire()                        un tir (coûte de l'énergie ; clic à vide sinon)
##     weapon.start_charge() / update_charge(delta) / release_charge()
##     weapon.raise_shield() / sustain_shield(delta) / lower_shield()
## Tous les sons de l'arme partent d'ici, en passant par l'AudioManager ; un tir
## porte un rayon de bruit que les ennemis entendent (signal noise_emitted).

## Un projectile vient de partir.
signal fired(projectile: Projectile)
## Détente pressée sans assez d'énergie : rien ne part.
signal dry_fired
## La charge est complète (le tir chargé est prêt).
signal charge_ready

## Réglages de l'arme et du bouclier.
@export var config: WeaponConfig = preload("res://resources/weapons/pistol.tres")
## Camp du porteur (Projectile.TEAM_PLAYER ou Projectile.TEAM_ENEMY).
@export var team: StringName = Projectile.TEAM_PLAYER

## Jauge d'énergie qui alimente l'arme (fournie par le personnage).
var energy: EnergyPool
## Sens du tir : 1 = droite, -1 = gauche. Le bouclier suit.
var facing: int = 1:
	set(value):
		facing = 1 if value >= 0 else -1
		_place_shield()
## Le mur d'énergie (créé au démarrage).
var shield: EnergyShield
## Temps de charge accumulé (secondes).
var charge: float = 0.0
## Vrai pendant une charge.
var is_charging: bool = false

var _charge_sound: AudioStreamPlayer2D
var _charge_ready_sent: bool = false


func _ready() -> void:
	shield = EnergyShield.new()
	shield.name = "Shield"
	shield.team = team
	shield.config = config
	add_child(shield)
	_place_shield()


# --------------------------------------------------------------------------
# Tir
# --------------------------------------------------------------------------

## Vrai si la jauge permet ce tir.
func can_fire(charged: bool = false) -> bool:
	return energy != null and energy.can_spend(_cost(charged))


## Point de départ d'un tir (coordonnées du monde). low : tir à genou.
func muzzle_position(low: bool = false) -> Vector2:
	var offset: Vector2 = config.low_muzzle_offset if low else config.muzzle_offset
	return global_position + Vector2(offset.x * facing, offset.y)


## Tire. Renvoie le projectile, ou null si l'énergie manque (clic à vide).
func fire(charged: bool = false, low: bool = false) -> Projectile:
	if energy == null or not energy.try_spend(_cost(charged)):
		AudioManager.play_stream_2d(CombatSounds.EMPTY, muzzle_position(low), AudioBuses.SFX, -6.0)
		dry_fired.emit()
		return null
	var projectile := Projectile.new()
	var speed: float = config.charged_projectile_speed if charged else config.projectile_speed
	projectile.setup(get_parent(), team, facing, speed, charged, config)
	var container: Node = _projectile_container()
	container.add_child(projectile)
	projectile.global_position = muzzle_position(low)
	var stream: AudioStream = CombatSounds.SHOT_CHARGED if charged else config.shot_sound
	var noise: float = config.charged_noise_radius if charged else config.shot_noise_radius
	AudioManager.play_stream_2d(stream, projectile.global_position, AudioBuses.SFX, -3.0,
			randf_range(0.96, 1.04), noise, get_parent())
	ImpactFlash.spawn(container, projectile.global_position, config.projectile_color, 0.7)
	fired.emit(projectile)
	return projectile


## Son de l'arme qu'on dégaine.
func play_draw_sound() -> void:
	AudioManager.play_stream_2d(CombatSounds.DRAW, global_position + Vector2(0, -60), AudioBuses.SFX, -10.0)


# --------------------------------------------------------------------------
# Tir chargé
# --------------------------------------------------------------------------

func start_charge() -> void:
	is_charging = true
	charge = 0.0
	_charge_ready_sent = false
	_charge_sound = AudioManager.play_stream_2d(CombatSounds.CHARGE, muzzle_position(), AudioBuses.SFX, -8.0)


## Fait monter la charge ; émet charge_ready (et un tintement) quand elle est complète.
func update_charge(delta: float) -> void:
	if not is_charging:
		return
	charge += delta
	if is_charged() and not _charge_ready_sent:
		_charge_ready_sent = true
		AudioManager.play_stream_2d(CombatSounds.CHARGE_READY, muzzle_position(), AudioBuses.SFX, -10.0)
		charge_ready.emit()


func is_charged() -> bool:
	return is_charging and charge >= config.charge_time


## Fin de la charge (détente relâchée) : tir chargé si la charge est complète.
func release_charge(low: bool = false) -> Projectile:
	var full: bool = is_charged()
	cancel_charge()
	return fire(true, low) if full else null


## Abandonne la charge sans tirer.
func cancel_charge() -> void:
	is_charging = false
	charge = 0.0
	# Le lecteur a pu être réutilisé pour un autre son une fois la charge jouée :
	# on ne l'arrête que s'il joue encore NOTRE son de charge.
	if _charge_sound and _charge_sound.playing and _charge_sound.stream == CombatSounds.CHARGE:
		_charge_sound.stop()
	_charge_sound = null


# --------------------------------------------------------------------------
# Bouclier
# --------------------------------------------------------------------------

## Lève le bouclier. Refusé si la jauge est presque vide ou s'il vient d'être brisé.
func raise_shield() -> bool:
	if energy == null or energy.value < energy.config.shield_min_energy:
		return false
	return shield.raise()


## À appeler à chaque pas de physique tant que le bouclier doit rester levé :
## consomme l'énergie. Renvoie faux si le bouclier est tombé (jauge vide, brisé).
func sustain_shield(delta: float) -> bool:
	if not shield.is_up:
		return false
	if not energy.drain(energy.config.shield_cost_per_second, delta):
		shield.lower()
		return false
	return true


func lower_shield() -> void:
	shield.lower()


func is_shield_up() -> bool:
	return shield != null and shield.is_up


## Remet l'arme au repos (réapparition, mort) : ni charge, ni bouclier.
func reset() -> void:
	cancel_charge()
	if shield:
		shield.lower()
		shield.broken_timer = 0.0


# --------------------------------------------------------------------------
# Interne
# --------------------------------------------------------------------------

func _cost(charged: bool) -> float:
	if energy == null:
		return INF
	return energy.config.charged_shot_cost if charged else energy.config.shot_cost


## Les projectiles vivent à côté du tireur (dans le niveau), pas sous lui :
## sinon ils suivraient ses déplacements.
func _projectile_container() -> Node:
	var character: Node = get_parent()
	return character.get_parent() if character and character.get_parent() else character


func _place_shield() -> void:
	if shield:
		shield.position = Vector2(facing * config.shield_offset_x, 0.0)
