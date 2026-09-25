class_name EliasVisual
extends CharacterVisual
## Silhouette d'Élias en polygones aplatis, animée par un AnimationPlayer.
##
## Tout est construit par code au démarrage :
##   1. le « squelette » (rig) : des pivots Node2D imbriqués (hanches → cuisse →
##      tibia…), chacun portant un Polygon2D coloré ;
##   2. les animations : générées à partir des tables de poses d'EliasPoses
##      (angles en degrés). Pour retoucher une animation, on modifie ces tables.
##
## Structure :  Visual
##                └ Flip (miroir gauche/droite)
##                    └ Rig (bascule du corps entier : roulade, chute, demi-tour)
##                        └ Hips ─ LegB, Coat, Torso (ArmB, Head, ArmF), LegF

## Assombrissement des membres « arrière » (effet de profondeur).
const BACK_DARKEN := 0.72
## Durée du fondu entre deux animations (secondes).
const BLEND_TIME: float = 0.06
## Animations où l'arme est en main (le pistolet n'est dessiné que pendant celles-ci).
const WEAPON_ANIMATIONS: Array[StringName] = [&"aim", &"shoot", &"charge", &"shield", &"kneel_aim", &"kneel_shoot"]
## Lueur du bracelet : éteint (jauge vide) -> vif (jauge pleine).
const BRACELET_EMPTY := Color("1d3b37")
const BRACELET_FULL := Color("7dffd8")

## Couleurs (style aplats : une teinte claire, une teinte d'ombre). Ce sont des
## variables et non des constantes : un personnage qui réutilise ce squelette
## (SentinelVisual) les change avant la construction.
var coat_color := Color("b9c6cc")
var coat_shade := Color("8a99a1")
var trousers_color := Color("2d3446")
var shoes_color := Color("171a22")
var skin_color := Color("d6a387")
var hair_color := Color("241d1f")
var gun_color := Color("2a2f38")
var gun_glow := Color("9ff5d0")

var _flip: Node2D
var _gun: Node2D
var _bracelet: Polygon2D
var _rig: Node2D
var _player: AnimationPlayer
## Chemin (depuis ce nœud) de chaque articulation animée.
var _joint_paths: Dictionary = {}


func _ready() -> void:
	_build_rig()
	_player = AnimationPlayer.new()
	_player.name = "AnimationPlayer"
	add_child(_player)
	_player.add_animation_library(&"", EliasPoses.build_library(_joint_paths))
	play(&"idle")


func play(animation: StringName, duration: float = -1.0) -> void:
	if _player == null or not _player.has_animation(animation):
		push_warning("EliasVisual : animation inconnue « %s »" % animation)
		return
	var length: float = _player.get_animation(animation).length
	_player.speed_scale = length / duration if duration > 0.0 else 1.0
	# 0,06 s de fondu entre deux animations, sauf en sortant d'une roulade : son
	# corps a fait un tour complet (360°) et un fondu vers 0° le ferait tourner
	# à l'envers pendant deux images.
	var blend: float = 0.0 if current == &"roll" else BLEND_TIME
	current = animation
	_player.play(animation, blend)
	_player.advance(0.0)
	if _gun:
		_gun.visible = animation in WEAPON_ANIMATIONS


func set_facing(direction: int) -> void:
	if _flip:
		_flip.scale.x = 1.0 if direction >= 0 else -1.0


## Le bracelet du poignet gauche brille selon l'énergie (interface « dans le
## monde » : pas de jauge à l'écran, PLAN §5.10).
func set_energy(ratio: float) -> void:
	if _bracelet:
		_bracelet.color = BRACELET_EMPTY.lerp(BRACELET_FULL, clampf(ratio, 0.0, 1.0))


func capture_pose() -> Dictionary:
	if _player == null or current == &"":
		return {}
	return {"anim": current, "time": _player.current_animation_position, "speed": _player.speed_scale}


func restore_pose(pose: Dictionary) -> void:
	if _player == null or pose.is_empty():
		return
	current = pose["anim"]
	_player.play(current)
	_player.seek(pose["time"], true)  # true : met la pose à jour tout de suite
	_player.speed_scale = pose["speed"]
	if _gun:
		_gun.visible = current in WEAPON_ANIMATIONS


## Place l'animation à un instant donné (outil de planche de poses).
func seek_fraction(animation: StringName, fraction: float) -> void:
	current = animation
	if _gun:
		_gun.visible = animation in WEAPON_ANIMATIONS
	_player.play(animation)
	_player.seek(_player.get_animation(animation).length * fraction, true)
	_player.pause()


# --------------------------------------------------------------------------
# Construction du squelette
# --------------------------------------------------------------------------

func _build_rig() -> void:
	_flip = _node("Flip", self, Vector2.ZERO)
	_rig = _node("Rig", _flip, Vector2(0, EliasPoses.RIG_Y))
	var hips: Node2D = _node("Hips", _rig, Vector2(0, EliasPoses.HIPS_Y))
	_register("rig", _rig)
	_register("hips", hips)

	# Jambes : cuisse (23 px) puis tibia (23 px) et pied.
	var leg_b: Node2D = _leg("LegB", hips, true)
	leg_b.z_index = -2
	# Pans de la blouse, par-dessus les cuisses.
	var coat: Node2D = _node("Coat", hips, Vector2(0, -2))
	coat.z_index = 1
	_poly(coat, [Vector2(-9, 0), Vector2(10, 0), Vector2(12, 24), Vector2(-11, 26)], coat_shade)
	_poly(coat, [Vector2(-9, 0), Vector2(3, 0), Vector2(2, 25), Vector2(-11, 26)], coat_color)
	_register("coat", coat)

	# Buste (blouse), tête et bras.
	var torso: Node2D = _node("Torso", hips, Vector2.ZERO)
	var arm_b: Node2D = _arm("ArmB", torso, true)
	arm_b.z_index = -3
	_poly(torso, [Vector2(-9, 2), Vector2(9, 2), Vector2(10, -30), Vector2(3, -34), Vector2(-7, -33), Vector2(-10, -26)], coat_color)
	_poly(torso, [Vector2(3, 2), Vector2(9, 2), Vector2(10, -30), Vector2(4, -33)], coat_shade)
	var head: Node2D = _node("Head", torso, Vector2(1, -33))
	_build_head(head)
	var arm_f: Node2D = _arm("ArmF", torso, false)
	arm_f.z_index = 2
	_register("torso", torso)
	_register("head", head)

	_leg("LegF", hips, false)  # dessinée après le buste : devant lui
	_build_gun(arm_f.get_node(^"Fore"))
	_decorate(arm_b.get_node(^"Fore"), torso, head)


## Tête d'Élias : cou, visage de profil, cheveux. (Redéfinie par SentinelVisual.)
func _build_head(head: Node2D) -> void:
	_poly(head, [Vector2(-3, 0), Vector2(3, 0), Vector2(3, -4)], skin_color)  # cou
	_poly(head, [Vector2(-6, -3), Vector2(5, -4), Vector2(8, -9), Vector2(7, -14), Vector2(1, -17), Vector2(-5, -15), Vector2(-7, -9)], skin_color)
	_poly(head, [Vector2(-7, -8), Vector2(-6, -15), Vector2(0, -18), Vector2(6, -16), Vector2(7, -13), Vector2(1, -13), Vector2(-3, -9)], hair_color)


## Pistolet dans la main avant. Repère de l'avant-bras : +y va du coude vers la
## main ; quand le bras est tendu à l'horizontale, +y pointe vers l'avant et
## -x vers le bas. Le canon prolonge donc l'avant-bras, la crosse pend vers -x.
func _build_gun(fore: Node2D) -> void:
	_gun = _node("Gun", fore, Vector2.ZERO)
	_gun.z_index = 1
	_poly(_gun, [Vector2(-3, 11), Vector2(4, 11), Vector2(4, 26), Vector2(-2, 26), Vector2(-3, 21)], gun_color)
	_poly(_gun, [Vector2(-10, 12), Vector2(-3, 12), Vector2(-3, 17), Vector2(-10, 16)], gun_color.darkened(0.3))  # crosse
	_poly(_gun, [Vector2(0, 13), Vector2(3, 13), Vector2(3, 22), Vector2(0, 22)], gun_glow.darkened(0.3))  # cellule d'énergie
	_poly(_gun, [Vector2(-1, 24), Vector2(3, 24), Vector2(3, 27), Vector2(-1, 27)], gun_glow)  # bouche du canon
	_gun.visible = false


## Détails propres au personnage. Élias : le bracelet au poignet gauche, dont
## la lueur suit l'énergie. De profil vers la droite, on voit le côté gauche
## d'Élias : son bras gauche est le bras « avant », celui qui tient l'arme ; le
## bracelet est donc bien visible quand il tire (PLAN §5.10).
func _decorate(_back_fore: Node2D, _torso: Node2D, _head: Node2D) -> void:
	_bracelet = Polygon2D.new()
	_bracelet.polygon = PackedVector2Array([Vector2(-3.5, 7), Vector2(3.5, 7), Vector2(3.5, 10.5), Vector2(-3.5, 10.5)])
	_bracelet.color = BRACELET_FULL
	_gun.get_parent().add_child(_bracelet)


func _leg(leg_name: String, hips: Node2D, back: bool) -> Node2D:
	var suffix: String = "b" if back else "f"
	var dim: float = BACK_DARKEN if back else 1.0
	var thigh: Node2D = _node(leg_name, hips, Vector2(0, 0))
	_poly(thigh, [Vector2(-6, -2), Vector2(6, -2), Vector2(5, 23), Vector2(-4, 23)], trousers_color.darkened(1.0 - dim))
	var shin: Node2D = _node("Shin", thigh, Vector2(0, 23))
	_poly(shin, [Vector2(-4, 0), Vector2(5, 0), Vector2(4, 21), Vector2(-3, 21)], trousers_color.darkened(1.0 - dim))
	_poly(shin, [Vector2(-4, 20), Vector2(4, 19), Vector2(11, 22), Vector2(11, 24), Vector2(-4, 24)], shoes_color.darkened(1.0 - dim))
	_register("thigh_" + suffix, thigh)
	_register("shin_" + suffix, shin)
	return thigh


func _arm(arm_name: String, torso: Node2D, back: bool) -> Node2D:
	var suffix: String = "b" if back else "f"
	var dim: float = BACK_DARKEN if back else 1.0
	var upper: Node2D = _node(arm_name, torso, Vector2(0, -29))
	_poly(upper, [Vector2(-4, -2), Vector2(4, -2), Vector2(3, 16), Vector2(-3, 16)], coat_color.darkened(1.0 - dim))
	var fore: Node2D = _node("Fore", upper, Vector2(0, 16))
	_poly(fore, [Vector2(-3, 0), Vector2(3, 0), Vector2(2, 12), Vector2(-2, 12)], coat_color.darkened(1.0 - dim))
	_poly(fore, [Vector2(-2, 11), Vector2(3, 11), Vector2(3, 16), Vector2(-1, 16)], skin_color.darkened(1.0 - dim))
	_register("arm_" + suffix, upper)
	_register("fore_" + suffix, fore)
	return upper


func _node(node_name: String, parent: Node, offset: Vector2) -> Node2D:
	var n := Node2D.new()
	n.name = node_name
	n.position = offset
	parent.add_child(n)
	return n


func _poly(parent: Node, points: Array[Vector2], color: Color) -> void:
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array(points)
	p.color = color
	parent.add_child(p)


func _register(joint: String, node: Node) -> void:
	if joint != "":
		_joint_paths[joint] = get_path_to(node)
