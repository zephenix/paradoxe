class_name RespawnConfig
extends Resource
## Réglages de la mort et de la réapparition (fichier resources/world/respawn.tres).
## Le plan demande un retour en jeu en moins de 2 secondes :
## delay + fade_out + fade_in doit rester sous 2 s.

## Temps entre la mort et le début du fondu au noir (secondes) : on voit Élias tomber.
@export var delay: float = 1.3
## Durées du fondu au noir, puis du retour de l'image (secondes).
@export var fade_out: float = 0.25
@export var fade_in: float = 0.35
## Marge (pixels) sous la salle la plus basse au-delà de laquelle on meurt (vide sans fond).
@export var kill_margin: float = 400.0


## Durée totale entre la mort et le retour en jeu.
func total_time() -> float:
	return delay + fade_out + fade_in
