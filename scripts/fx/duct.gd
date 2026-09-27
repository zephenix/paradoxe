@tool
class_name Duct
extends Node2D
## Bouche de conduit (J8, décor de l'écran 6) : une ouverture basse dans un muret,
## dont la grille a été arrachée (elle est posée par terre, à côté). C'est par là
## que Marek s'en va : le conduit est trop étroit pour Élias.
##
## Deux profondeurs de dessin :
##   - le fond noir de l'ouverture est DERRIÈRE les personnages : on voit Marek
##     s'y engager ;
##   - le muret (à gauche de l'ouverture) et le cadre sont DEVANT eux : quand
##     Marek avance dans le conduit, vers la gauche, le muret le cache peu à peu.
## L'origine est au sol, au milieu de l'ouverture.

## Taille de l'ouverture (pixels).
@export var size: Vector2 = Vector2(72.0, 58.0):
	set(value):
		size = value
		queue_redraw()
		if _mouth:
			_mouth.queue_redraw()

const WALL: Color = Color("262c34")
const FRAME: Color = Color("3a424c")
const DARK: Color = Color("040506")

var _mouth: Node2D


func _ready() -> void:
	z_index = 8  # devant les personnages (voir EliasVisual.BASE_Z)
	_mouth = Node2D.new()
	_mouth.name = "Mouth"
	_mouth.z_as_relative = false
	_mouth.z_index = 0  # derrière les personnages
	_mouth.draw.connect(func() -> void:
		_mouth.draw_rect(Rect2(-size.x * 0.5, -size.y, size.x, size.y), DARK))
	add_child(_mouth)


func _draw() -> void:
	var half: float = size.x * 0.5
	# Le muret : à gauche de l'ouverture, et au-dessus d'elle (le linteau).
	draw_colored_polygon(PackedVector2Array([Vector2(-half - 150.0, 0.0), Vector2(-half - 150.0, -84.0), Vector2(-half - 60.0, -96.0),
			Vector2(half + 10.0, -92.0), Vector2(half + 10.0, -size.y - 8.0), Vector2(-half, -size.y - 8.0), Vector2(-half, 0.0)]), WALL)
	# Cadre de l'ouverture.
	draw_rect(Rect2(-half - 6.0, -size.y - 8.0, size.x + 12.0, 8.0), FRAME)
	draw_rect(Rect2(half, -size.y - 8.0, 6.0, size.y + 8.0), FRAME)
	# La grille arrachée, posée de travers à droite.
	draw_set_transform(Vector2(half + 40.0, 0.0), -0.35)
	draw_rect(Rect2(0.0, -46.0, 60.0, 46.0), FRAME, false, 3.0)
	for i in range(1, 5):
		draw_line(Vector2(i * 12.0, -46.0), Vector2(i * 12.0, 0.0), FRAME, 2.0)
	draw_set_transform(Vector2.ZERO)
