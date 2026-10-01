class_name RoomAtmosphere
extends Resource
## L'ambiance visuelle d'une salle (essai graphique, après J8) : rien de tout cela
## ne compte pour le gameplay. Ce que voient les Sentinelles dépend seulement de
## Room.ambient_light et des lampes (Lighting).
##
##   - la « lumière principale » (lune, soleil voilé) : une lumière qui vient
##     d'une direction et fait ressortir le relief des textures partout ;
##   - la brume au ras du sol ;
##   - les poussières (ou lucioles) qui flottent ;
##   - le grain de l'image et l'assombrissement des bords de l'écran.
## Les fichiers sont dans resources/art/atmospheres/.

@export_group("Lumière principale")
## Intensité (0 = aucune).
@export_range(0.0, 2.0, 0.05) var key_energy: float = 0.0
@export var key_color: Color = Color(0.6, 0.72, 0.95)
## D'où vient la lumière : angle en degrés (0 = d'en haut, 30 = d'en haut à
## gauche, 90 = de la gauche, à l'horizontale).
@export_range(-90.0, 90.0, 1.0) var key_angle: float = 30.0
## 0 = rasante (relief très marqué), 1 = de face (relief effacé).
@export_range(0.0, 1.0, 0.05) var key_height: float = 0.35

@export_group("Brume au sol")
@export var fog_color: Color = Color(0.5, 0.62, 0.66, 0.0)
## Épaisseur de la nappe (pixels, depuis le bas de la salle).
@export var fog_height: float = 160.0

@export_group("Poussières")
@export var dust_amount: int = 0
@export var dust_color: Color = Color(0.8, 0.9, 0.85, 0.5)

@export_group("Image")
## Assombrissement des bords de l'écran (0 = aucun).
@export_range(0.0, 1.0, 0.05) var vignette: float = 0.0
## Grain de l'image (0 = aucun).
@export_range(0.0, 0.2, 0.01) var grain: float = 0.0
