class_name Lighting
extends RefCounted
## Calcul de la lumière reçue en un point (J6, PLAN §5.4) : c'est ce que les
## Sentinelles « voient ». Le calcul utilise les MÊMES données que l'affichage :
##
##   lumière = lumière ambiante de la salle
##           + somme, pour chaque lampe allumée qui « voit » le point,
##             de  énergie × (1 - distance / rayon)
##
## - la lumière ambiante vient de la salle (Room.ambient_light : 1 = plein jour,
##   0,2 = pénombre). À l'écran, c'est la teinte du CanvasModulate du niveau ;
## - une lampe (LightSource) éclaire un disque de rayon « radius » : pleine
##   énergie en son centre, rien au bord (la même pente que sa texture à
##   l'écran) ;
## - le décor arrête la lumière : si un mur se trouve entre la lampe et le point,
##   la lampe ne compte pas (à l'écran, le mur projette une ombre) ;
## - une lampe brisée ne compte plus.
##
## Le résultat est plafonné à 1 (« on voit parfaitement »).
##
## Analogie Excel : une colonne par lampe, chacune =SI(visible ; énergie × (1 - d/r) ; 0),
## puis une SOMME avec la lumière ambiante, et un =MIN(… ; 1).

## Groupe Godot des lampes.
const GROUP: StringName = &"lights"
## Teinte de l'écran pour une lumière ambiante nulle (nuit bleutée, pas un noir pur).
const DARK_TINT: Color = Color(0.1, 0.12, 0.19)


## Lumière reçue au point « point » (coordonnées du monde), de 0 à 1.
## « context » : n'importe quel nœud de la scène (pour trouver salles et lampes).
static func level_at(context: Node, point: Vector2) -> float:
	var total: float = ambient_at(context, point)
	for node in context.get_tree().get_nodes_in_group(GROUP):
		var lamp: LightSource = node as LightSource
		if lamp:
			total += lamp.contribution_at(point)
	return clampf(total, 0.0, 1.0)


## Lumière ambiante de la salle qui contient « point » (1 hors de toute salle).
static func ambient_at(context: Node, point: Vector2) -> float:
	for node in context.get_tree().get_nodes_in_group(&"rooms"):
		var room: Room = node as Room
		if room and room.world_rect().has_point(point):
			return room.ambient_light
	return 1.0


## Couleur de la teinte d'écran (CanvasModulate) pour une lumière ambiante donnée.
static func ambient_color(ambient: float) -> Color:
	return DARK_TINT.lerp(Color.WHITE, clampf(ambient, 0.0, 1.0))
