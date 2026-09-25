class_name Projectile
extends Node2D
## Un tir d'énergie : il file en ligne droite jusqu'à toucher quelque chose.
##
## Plutôt qu'une zone de collision (qui, à 900 px/s, peut « sauter » par-dessus
## un mur fin d'une image à l'autre), le projectile lance à chaque pas de
## physique un RAYON entre sa position et sa position suivante, et regarde ce
## que ce rayon touche en premier :
##   - un bouclier ennemi (couche SHIELDS)  -> le bouclier l'arrête (ou se brise) ;
##   - un personnage visé (joueur/ennemis)  -> on lui demande take_hit(projectile) ;
##   - le décor (couche WORLD)              -> impact sur le mur.
## Les boucliers de son propre camp sont ignorés (on ne se tire pas dans le dos).
##
## Les projectiles sont dans le groupe « projectiles » : la réapparition au
## checkpoint les efface tous (et le rembobinage de J4 aussi, pour rester simple).

## Le tir a touché quelque chose. kind : &"wall", &"shield", &"body".
signal impacted(kind: StringName, at: Vector2)

## Camps : les tirs d'Élias visent les ennemis, et inversement.
const TEAM_PLAYER: StringName = &"player"
const TEAM_ENEMY: StringName = &"enemy"
## Longueur de la traînée lumineuse dessinée derrière le projectile (pixels).
const TRAIL_LENGTH: float = 26.0
## Nombre maximal d'objets ignorés (boucliers alliés, roulade) par pas de physique.
const MAX_PASSES: int = 4

## Sens de déplacement : 1 = droite, -1 = gauche.
var direction: int = 1
var speed: float = 900.0
## Tir chargé : brise les boucliers.
var charged: bool = false
var team: StringName = TEAM_PLAYER
## Qui a tiré (pour les journaux et le bruit).
var shooter: Node
var max_distance: float = 1500.0
var color: Color = Color.WHITE
## Distance déjà parcourue.
var travelled: float = 0.0

var _exclude: Array[RID] = []
var _done: bool = false


## Prépare le tir (à appeler avant de l'ajouter à la scène).
func setup(from_shooter: Node, shot_team: StringName, dir: int, shot_speed: float,
		is_charged: bool, weapon: WeaponConfig) -> void:
	shooter = from_shooter
	team = shot_team
	direction = 1 if dir >= 0 else -1
	speed = shot_speed
	charged = is_charged
	max_distance = weapon.projectile_range
	color = weapon.projectile_color


func _ready() -> void:
	add_to_group(&"projectiles")


func _physics_process(delta: float) -> void:
	step(delta)


## Avance d'un pas de physique et traite ce qui est touché.
func step(delta: float) -> void:
	if _done:
		return
	var motion := Vector2(direction * speed * delta, 0.0)
	var from: Vector2 = global_position
	var to: Vector2 = from + motion
	for i in MAX_PASSES:
		var hit: Dictionary = _cast(from, to)
		if hit.is_empty():
			break
		var collider: Object = hit["collider"]
		if collider is EnergyShield:
			var shield: EnergyShield = collider
			if shield.team == team:
				_exclude.append(hit["rid"])  # bouclier allié : on passe à travers
				continue
			shield.absorb(self)
			_impact(&"shield", hit["position"])
			return
		if collider.has_method(&"take_hit"):
			if collider.call(&"take_hit", self):
				_impact(&"body", hit["position"])
				return
			_exclude.append(hit["rid"])  # esquive (roulade) : le tir continue
			continue
		_impact(&"wall", hit["position"])
		return
	global_position = to
	travelled += motion.length()
	if travelled >= max_distance:
		_done = true
		queue_free()


## Couches que ce projectile peut toucher : le décor, les boucliers, et le camp adverse.
func collision_mask() -> int:
	var targets: int = PhysicsLayers.ENEMIES if team == TEAM_PLAYER else PhysicsLayers.PLAYER | PhysicsLayers.COMPANION
	return PhysicsLayers.WORLD | PhysicsLayers.SHIELDS | targets


func _cast(from: Vector2, to: Vector2) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(from, to, collision_mask(), _exclude)
	query.collide_with_areas = true
	return get_world_2d().direct_space_state.intersect_ray(query)


func _impact(kind: StringName, at: Vector2) -> void:
	_done = true
	global_position = at
	impacted.emit(kind, at)
	if kind != &"shield":  # le bouclier joue son propre son
		AudioManager.play_sfx(&"impact_body" if kind == &"body" else &"impact_wall", at, shooter)
	ImpactFlash.spawn(get_parent(), at, color, 1.6 if charged else 1.0)
	queue_free()


func _draw() -> void:
	# Traînée : un trait qui s'affine vers l'arrière, et une tête plus claire.
	var width: float = 6.0 if charged else 3.0
	var tail := Vector2(-direction * TRAIL_LENGTH * (1.6 if charged else 1.0), 0.0)
	draw_line(tail, Vector2.ZERO, Color(color, 0.35), width * 2.2)
	draw_line(tail * 0.6, Vector2.ZERO, color, width)
	draw_circle(Vector2.ZERO, width * 0.9, color.lightened(0.6))
