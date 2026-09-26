class_name NoiseRings
extends Node2D
## « Voir les sons » (J6, option d'accessibilité, PLAN §5.4) : chaque fois
## qu'Élias fait du bruit (pas, tir, pierre qui retombe, lampe qu'il brise…),
## un cercle s'étend jusqu'au RAYON DE BRUIT exact que perçoivent les ennemis,
## puis s'efface. Utile au joueur qui entend mal, et pour régler le jeu.
##
## Les bruits des Sentinelles elles-mêmes ne sont pas montrés.
## Le niveau place ce nœud dans un calque (CanvasLayer) qui suit la caméra mais
## échappe à la teinte de la lumière ambiante : les cercles restent visibles
## dans le noir.

## Durée d'un cercle : il s'étend pendant GROW, puis s'efface jusqu'à LIFE.
const GROW: float = 0.2
const LIFE: float = 0.8
const COLOR: Color = Color(0.45, 0.95, 1.0)

## Cercles en cours : [centre, rayon, âge].
var rings: Array[Array] = []


func _ready() -> void:
	AudioManager.noise_emitted.connect(_on_noise)


## Vrai si les cercles doivent s'afficher (réglage du joueur).
func is_active() -> bool:
	return Settings.show_sounds


func _on_noise(at: Vector2, radius: float, source: Node) -> void:
	if not is_active() or radius <= 0.0:
		return
	if source != null and is_instance_valid(source) and source.is_in_group(&"enemies"):
		return
	rings.append([at, radius, 0.0])
	queue_redraw()


func _process(delta: float) -> void:
	if rings.is_empty():
		return
	for ring in rings:
		ring[2] += delta
	rings = rings.filter(func(ring: Array) -> bool: return ring[2] < LIFE)
	queue_redraw()


func _draw() -> void:
	for ring in rings:
		var age: float = ring[2]
		var grow: float = clampf(age / GROW, 0.0, 1.0)
		var alpha: float = 1.0 - clampf((age - GROW) / (LIFE - GROW), 0.0, 1.0)
		var radius: float = ring[1] * (1.0 - pow(1.0 - grow, 3.0))  # ralentit en arrivant au bord
		draw_arc(ring[0], radius, 0.0, TAU, 64, Color(COLOR, 0.8 * alpha), 2.0, true)
		draw_circle(ring[0], radius, Color(COLOR, 0.06 * alpha))
