class_name SurfaceStyle
extends Resource
## La « matière » d'une surface du décor (essai graphique, après J8) : une texture
## de couleur et son relief, qui se répètent comme un carrelage. Un SolidBlock ou
## une façade (Ruin) qui en reçoit une n'est plus un aplat : la couleur du bloc
## teinte la texture, et la lumière des lampes accroche le relief.
##
## Les fichiers .tres sont dans resources/art/surfaces/ ; les images viennent du
## générateur tools/art/generate_textures.py.

## Couleur (surtout des gris : la couleur du bloc la teinte).
@export var diffuse: Texture2D
## Relief (normal map) : sans elle, la lumière éclaire la surface uniformément.
@export var normal: Texture2D
## Taille d'un pixel de la texture dans le monde (2 = texture agrandie deux fois).
@export_range(0.25, 8.0, 0.25) var texel_size: float = 1.0
## Éclaircissement de la couleur du bloc : la texture, plus sombre que le blanc,
## l'assombrit un peu ; ce réglage compense.
@export_range(0.0, 1.0, 0.05) var lighten: float = 0.15

var _canvas_texture: CanvasTexture


## La texture prête à poser (couleur + relief, répétée). Créée une seule fois.
func canvas_texture() -> CanvasTexture:
	if _canvas_texture == null:
		_canvas_texture = CanvasTexture.new()
		_canvas_texture.diffuse_texture = diffuse
		_canvas_texture.normal_texture = normal
		_canvas_texture.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	return _canvas_texture


## Coordonnées de texture de points du monde, pour un Polygon2D (en pixels de
## la texture) : des blocs voisins se raccordent, puisqu'ils lisent la même
## « grande nappe ».
func uvs_for(world_points: PackedVector2Array) -> PackedVector2Array:
	var uvs := PackedVector2Array()
	for point in world_points:
		uvs.append(point / texel_size)
	return uvs


## Les mêmes, pour les fonctions de dessin (draw_colored_polygon…), qui comptent
## en fractions de l'image (1 = une largeur de texture). Le nœud qui dessine doit
## avoir texture_repeat = TEXTURE_REPEAT_ENABLED.
func draw_uvs_for(world_points: PackedVector2Array) -> PackedVector2Array:
	var uvs := uvs_for(world_points)
	var size: Vector2 = Vector2(diffuse.get_size()) if diffuse else Vector2.ONE
	for i in uvs.size():
		uvs[i] = uvs[i] / size
	return uvs
