class_name EnergyConfig
extends Resource
## Réglages d'une jauge d'énergie (fichiers resources/player/energy.tres et
## resources/enemies/sentinel_energy.tres).
##
## Une seule jauge alimente tout (PLAN §5.2, « énergie unifiée ») : le tir coûte
## une unité, le bouclier consomme en continu, le tir chargé coûte cher. Après un
## court délai sans rien consommer, la jauge se recharge toute seule.
## Élias et les Sentinelles utilisent le même code, avec des réglages différents.

## Nombre d'unités quand la jauge est pleine.
@export var capacity: float = 10.0
## Temps sans consommation avant que la recharge commence (secondes).
@export var recharge_delay: float = 1.0
## Vitesse de recharge (unités par seconde).
@export var recharge_rate: float = 2.5

@export_group("Coûts")
## Coût d'un tir normal (unités).
@export var shot_cost: float = 1.0
## Coût d'un tir chargé (unités) : il brise un bouclier.
@export var charged_shot_cost: float = 4.0
## Consommation du bouclier levé (unités par seconde).
@export var shield_cost_per_second: float = 3.0
## Énergie minimale pour lever le bouclier (sinon il clignoterait sans rien protéger).
@export var shield_min_energy: float = 0.5
