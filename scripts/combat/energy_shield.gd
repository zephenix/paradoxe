class_name EnergyShield
extends Area2D
## Bouclier d'énergie : un mur lumineux devant le personnage, qui arrête les tirs.
##
## Élias et les Sentinelles utilisent exactement ce même code et ces mêmes sons
## (PLAN §5.2). Le bouclier ne consomme rien lui-même : c'est l'arme (Weapon)
## qui puise dans la jauge d'énergie tant qu'il est levé.
##
## Un tir normal est arrêté. Un tir CHARGÉ brise le bouclier : il tombe et ne
## peut pas être relevé pendant config.shield_broken_cooldown secondes.
##
## Détail technique : le bouclier baissé n'est pas « désactivé » ; il quitte
## simplement la couche SHIELDS (collision_layer = 0), si bien que les rayons des
## projectiles ne le voient plus. Changer de couche est permis à tout moment,
## contrairement à l'activation d'une forme pendant un calcul physique.

## Un tir vient d'être arrêté par le bouclier.
signal blocked(projectile: Projectile)
## Un tir chargé vient de briser le bouclier.
signal broken

## Camp du porteur (voir Projectile.TEAM_*) : ses propres tirs traversent.
var team: StringName = Projectile.TEAM_PLAYER
## Réglages de taille, de couleur et de délai après une rupture.
var config: WeaponConfig
## Vrai quand le bouclier est levé.
var is_up: bool = false
## Temps restant avant de pouvoir relever un bouclier brisé.
var broken_timer: float = 0.0

var _shape := RectangleShape2D.new()
var _time: float = 0.0
var _flash: float = 0.0
var _loop_id: StringName


func _init() -> void:
	collision_layer = 0
	collision_mask = 0
	monitoring = false  # le bouclier ne cherche rien : ce sont les tirs qui le trouvent
	var shape_node := CollisionShape2D.new()
	shape_node.shape = _shape
	add_child(shape_node)
	visible = false


func _ready() -> void:
	_loop_id = StringName("shield_%d" % get_instance_id())
	if config:
		_shape.size = config.shield_size
		(get_child(0) as Node2D).position = Vector2(0.0, -config.shield_size.y * 0.5)


func _exit_tree() -> void:
	AudioManager.stop_loop(_loop_id, 0.0)


func _physics_process(delta: float) -> void:
	broken_timer = maxf(broken_timer - delta, 0.0)


func _process(delta: float) -> void:
	_time += delta
	_flash = maxf(_flash - delta * 5.0, 0.0)
	if visible:
		queue_redraw()


## Vrai si le bouclier peut être levé maintenant (pas brisé récemment).
func can_raise() -> bool:
	return broken_timer <= 0.0


## Lève le bouclier. Renvoie faux s'il vient d'être brisé.
func raise() -> bool:
	if not can_raise():
		return false
	if is_up:
		return true
	is_up = true
	collision_layer = PhysicsLayers.SHIELDS
	visible = true
	_flash = 0.6
	AudioManager.play_sfx(&"shield_up", global_position, get_parent())
	AudioManager.play_loop_sfx(_loop_id, &"shield_loop", 0.1)
	return true


## Baisse le bouclier (relâchement de la touche, énergie épuisée).
func lower() -> void:
	if not is_up:
		return
	_set_down()
	AudioManager.play_sfx(&"shield_down", global_position, get_parent())


## Appelé par un projectile adverse qui vient de heurter le bouclier.
func absorb(projectile: Projectile) -> void:
	if projectile.charged:
		_set_down()
		broken_timer = config.shield_broken_cooldown if config else 2.0
		AudioManager.play_sfx(&"shield_break", global_position, get_parent())
		ImpactFlash.spawn(get_parent(), global_position + Vector2(0, -50), Color.WHITE, 3.0)
		broken.emit()
	else:
		_flash = 1.0
		AudioManager.play_sfx(&"shield_hit", global_position, get_parent())
	blocked.emit(projectile)


func _set_down() -> void:
	is_up = false
	collision_layer = 0
	visible = false
	AudioManager.stop_loop(_loop_id, 0.08)


func _draw() -> void:
	if config == null:
		return
	var size: Vector2 = config.shield_size
	var base: Color = config.shield_color
	var rect := Rect2(Vector2(-size.x * 0.5, -size.y), size)
	# Voile translucide qui « respire », plus lumineux quand un tir le frappe.
	var alpha: float = 0.22 + 0.06 * sin(_time * 23.0) + 0.5 * _flash
	draw_rect(rect, Color(base, alpha))
	# Lignes d'énergie horizontales qui défilent (effet de grésillement).
	var lines: int = 7
	for i in lines:
		var y: float = -fmod(_time * 90.0 + i * size.y / lines, size.y)
		draw_line(Vector2(-size.x * 0.5, y), Vector2(size.x * 0.5, y), Color(base.lightened(0.5), 0.35 + 0.4 * _flash), 1.5)
	# Bords verticaux plus nets.
	draw_line(rect.position, rect.position + Vector2(0, size.y), Color(base, 0.8), 2.0)
	draw_line(rect.position + Vector2(size.x, 0), rect.end, Color(base, 0.8), 2.0)
