@tool
class_name LightSource
extends StaticBody2D
## Une lampe (J6) : elle éclaire un disque autour d'elle, à l'écran ET pour les
## Sentinelles (voir Lighting.level_at). Un tir peut la briser : elle s'éteint
## partout d'un coup, dans un bruit de verre que les ennemis entendent.
##
## L'origine du nœud est l'ampoule. La lampe pend d'un fil de longueur
## « cord_length » (pur décor).
##
## Côté écran : un PointLight2D (créé par ce script) avec une texture ronde qui
## va du blanc au transparent, du centre au bord : la même pente que le calcul.
## Il projette des ombres derrière les blocs du décor (LightOccluder2D des
## SolidBlock).
##
## Rembobinage : une lampe brisée pendant les secondes remontées se rallume.
## Réapparition au checkpoint : comme les Sentinelles, une lampe brisée depuis
## le dernier checkpoint est réparée ; brisée AVANT, elle le reste.

## Émis quand la lampe se brise.
signal broken

## Rayon éclairé (pixels) : au-delà, la lampe n'éclaire plus rien.
@export var radius: float = 280.0:
	set(value):
		radius = maxf(value, 1.0)
		_update_light()
## Énergie au centre (ajoutée à la lumière ambiante ; 1 = pleine lumière).
@export_range(0.0, 2.0, 0.05) var energy: float = 0.9:
	set(value):
		energy = value
		_update_light()
## Couleur de la lumière (à l'écran seulement).
@export var color: Color = Color(1.0, 0.86, 0.62):
	set(value):
		color = value
		_update_light()
## Un tir peut-il la briser ?
@export var destructible: bool = true
## Longueur du fil (pixels, vers le haut) : pur décor.
@export var cord_length: float = 60.0:
	set(value):
		cord_length = value
		queue_redraw()

## Vrai tant que la lampe éclaire.
var lit: bool = true

var _light: PointLight2D
var _stays_broken: bool = false

## Taille de la texture de lumière (pixels) : elle est ensuite agrandie au rayon.
const TEXTURE_SIZE: int = 256


func _ready() -> void:
	collision_layer = PhysicsLayers.PROPS
	collision_mask = 0
	# Petite forme touchable par les tirs (l'abat-jour).
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(26.0, 20.0)
	shape.shape = rect
	shape.position = Vector2(0.0, -6.0)
	add_child(shape)
	_light = PointLight2D.new()
	_light.texture = _make_texture()
	_light.shadow_enabled = true
	_light.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	_light.shadow_color = Color(0.0, 0.0, 0.0, 0.85)
	add_child(_light)
	_update_light()
	if Engine.is_editor_hint():
		return
	add_to_group(Lighting.GROUP)
	add_to_group(RewindManager.GROUP)
	Events.player_respawned.connect(_on_player_respawned)
	Events.checkpoint_reached.connect(_on_checkpoint_reached)


## Lumière que cette lampe apporte au point « point » (0 si éteinte, trop loin
## ou cachée par le décor).
func contribution_at(point: Vector2) -> float:
	if not lit:
		return 0.0
	var distance: float = global_position.distance_to(point)
	if distance >= radius:
		return 0.0
	# Un mur entre l'ampoule et le point : il est dans l'ombre.
	var query := PhysicsRayQueryParameters2D.create(global_position, point, PhysicsLayers.WORLD)
	if not get_world_2d().direct_space_state.intersect_ray(query).is_empty():
		return 0.0
	return energy * (1.0 - distance / radius)


## Appelé par un projectile qui la touche. Renvoie vrai si elle se brise.
func take_hit(_projectile: Node) -> bool:
	if not destructible or not lit:
		return false
	shatter()
	return true


## Brise la lampe : elle s'éteint et fait du bruit (les ennemis l'entendent).
func shatter() -> void:
	if not lit:
		return
	_set_lit(false)
	AudioManager.play_sfx(&"lamp_break", global_position, self)
	ImpactFlash.spawn(get_parent(), global_position, color, 2.2)
	broken.emit()


# --------------------------------------------------------------------------
# Rembobinage et réapparition
# --------------------------------------------------------------------------

func capture_state() -> Dictionary:
	return {"lit": lit}


func apply_state(state: Dictionary) -> void:
	_set_lit(state["lit"])


func resume_state(_state: Dictionary) -> void:
	pass


func _on_checkpoint_reached(_checkpoint_id: StringName) -> void:
	if not lit:
		_stays_broken = true


func _on_player_respawned() -> void:
	if not _stays_broken:
		_set_lit(true)


# --------------------------------------------------------------------------
# Affichage
# --------------------------------------------------------------------------

func _set_lit(value: bool) -> void:
	lit = value
	if _light:
		_light.enabled = lit
	queue_redraw()


func _update_light() -> void:
	if _light == null:
		return
	_light.color = color
	_light.energy = energy
	_light.texture_scale = radius * 2.0 / TEXTURE_SIZE
	queue_redraw()


## Texture ronde : blanc au centre, transparent au bord, en ligne droite
## (la même pente que contribution_at).
static func _make_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = TEXTURE_SIZE
	texture.height = TEXTURE_SIZE
	return texture


func _draw() -> void:
	# Fil, abat-jour conique, ampoule (allumée : claire ; brisée : sombre).
	draw_line(Vector2(0.0, -cord_length), Vector2(0.0, -14.0), Color(0.2, 0.22, 0.25), 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-5, -16), Vector2(5, -16), Vector2(14, -2), Vector2(-14, -2)]),
			Color(0.28, 0.3, 0.33))
	if lit:
		draw_circle(Vector2(0.0, 1.0), 6.0, color.lightened(0.4))
		draw_circle(Vector2(0.0, 1.0), 11.0, Color(color, 0.25))
	else:
		draw_circle(Vector2(0.0, 1.0), 5.0, Color(0.16, 0.16, 0.17))
