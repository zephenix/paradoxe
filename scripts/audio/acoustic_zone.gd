class_name AcousticZone
extends Resource
## Une zone acoustique (J5, PLAN §6.4) : l'ambiance et l'acoustique d'un groupe de
## salles. Fichiers : resources/audio/zones/<id>.tres. Chaque salle (Room) dit à
## quelle zone elle appartient (acoustic_zone) ; en y entrant, l'AudioManager
## passe en fondu à cette ambiance.
##
## Une ambiance, ce sont :
##   - des COUCHES : boucles jouées en continu (vent, bourdonnement…), qui
##     « respirent » lentement (houle de volume) pour ne jamais sonner figées ;
##   - des ÉVÈNEMENTS : petits sons ponctuels (goutte, grincement, cri lointain)
##     joués au hasard, à gauche ou à droite de l'écran, à intervalles irréguliers ;
##   - une ACOUSTIQUE : réverbération (taille, écho) et filtre de la salle.

## Identifiant (nom du fichier, et valeur de Room.acoustic_zone).
@export var id: StringName = &""
## Nom affiché (banc d'écoute).
@export var title: String = ""

@export_group("Couches (boucles)")
## Sons en boucle de la bibliothèque (identifiants).
@export var layers: Array[StringName] = []
## Volume de chaque couche (dB), ajouté au volume de la bibliothèque. Même ordre
## que « layers » ; une valeur manquante vaut 0.
@export var layer_volumes_db: Array[float] = []
## Amplitude de la houle (dB) et durée d'un cycle (secondes).
@export var swell_depth_db: float = 3.0
@export var swell_period: float = 18.0

@export_group("Évènements ponctuels")
## Sons ponctuels de la bibliothèque, tirés au hasard.
@export var events: Array[StringName] = []
## Intervalle entre deux évènements (secondes), tiré entre min et max.
@export var event_interval_min: float = 4.0
@export var event_interval_max: float = 11.0
## Distance à l'écoute (pixels), à gauche ou à droite.
@export var event_distance_min: float = 300.0
@export var event_distance_max: float = 1100.0
## Volume des évènements (dB), ajouté à celui de la bibliothèque.
@export var event_volume_db: float = 0.0

@export_group("Acoustique")
## Réverbération : quantité d'écho (0 à 1), taille perçue (0 à 1), amortissement
## des aigus (0 = métal brillant, 1 = pièce feutrée).
@export_range(0.0, 1.0, 0.01) var reverb_wet: float = 0.1
@export_range(0.0, 1.0, 0.01) var reverb_room_size: float = 0.5
@export_range(0.0, 1.0, 0.01) var reverb_damping: float = 0.5
## Filtre passe-bas des sons du monde (Hz) : 20500 = aucun filtre.
@export var lowpass_hz: float = 20500.0


## Volume propre de la couche n° index.
func layer_volume_db(index: int) -> float:
	return layer_volumes_db[index] if index < layer_volumes_db.size() else 0.0
