class_name ThrownStone
extends Node2D
## Une pierre lancée par Élias (J6). Elle suit une courbe en cloche (gravité)
## et, comme un tir, lance un rayon à chaque pas de physique pour ne jamais
## traverser un mur. Au premier contact avec le décor, elle fait du bruit
## (son « stone_impact », avec son rayon de bruit) : les Sentinelles qui
## l'entendent vont voir. Puis elle glisse jusqu'au sol, y reste un moment
## et disparaît.
##
## Une pierre qui touche une lampe la brise (la lampe fait alors son propre bruit).
##
## Elle est dans le groupe « projectiles » : la réapparition au checkpoint et
## le rembobinage l'effacent, comme les tirs.

## Émis au premier contact (position du bruit).
signal landed(at: Vector2)

var velocity: Vector2 = Vector2.ZERO
var gravity: float = 1400.0
## Qui l'a lancée (source du bruit : les ennemis savent que c'est Élias… ou non).
var thrower: Node
## Vrai une fois le bruit fait.
var has_landed: bool = false

var _resting: bool = false
var _exclude: Array[RID] = []
var _linger: float = 4.0
var _age: float = 0.0

## Durée de vie maximale (une pierre lancée dans le vide ne vit pas éternellement).
const MAX_LIFETIME: float = 8.0
const RADIUS: float = 5.0


## Prépare la pierre (avant add_child).
func setup(from_thrower: Node, start_velocity: Vector2, config: ThrowConfig) -> void:
	thrower = from_thrower
	velocity = start_velocity
	gravity = config.gravity
	_linger = config.linger_time


func _ready() -> void:
	add_to_group(&"projectiles")
	z_index = 5


func _physics_process(delta: float) -> void:
	step(delta)


## Avance d'un pas de physique.
func step(delta: float) -> void:
	_age += delta
	if _age >= MAX_LIFETIME or (_resting and _age >= _linger):
		queue_free()
		return
	if _resting:
		return
	velocity.y += gravity * delta
	var motion: Vector2 = velocity * delta
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + motion,
			PhysicsLayers.WORLD | PhysicsLayers.PROPS, _exclude)
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position += motion
		return
	var lamp: LightSource = hit["collider"] as LightSource
	if lamp:
		lamp.take_hit(self)  # brisée (si elle peut l'être) ; la pierre continue sa chute
		_exclude.append(hit["rid"])
		has_landed = true  # le bruit est celui du verre
		return
	var normal: Vector2 = hit["normal"]
	global_position = hit["position"] + normal * RADIUS
	if not has_landed:
		has_landed = true
		AudioManager.play_sfx(&"stone_impact", global_position, thrower)
		landed.emit(global_position)
		_age = 0.0  # le temps d'attente au sol commence maintenant
	if normal.y < -0.7:
		_resting = true  # posée sur un sol
	else:
		velocity = Vector2(0.0, maxf(velocity.y, 0.0))  # contre un mur : elle retombe


func _draw() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(-5, 1), Vector2(-3, -4), Vector2(3, -5),
			Vector2(6, 0), Vector2(3, 4), Vector2(-3, 4)]), Color(0.55, 0.55, 0.52))
