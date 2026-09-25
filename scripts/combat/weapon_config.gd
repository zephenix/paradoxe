class_name WeaponConfig
extends Resource
## Réglages d'une arme à énergie et de son bouclier (resources/weapons/pistol.tres
## pour Élias, resources/weapons/sentinel_gun.tres pour les Sentinelles).
##
## Les coûts en énergie ne sont pas ici mais dans la jauge (EnergyConfig) : la
## même arme peut ainsi être plus ou moins gourmande selon qui la porte.
##
## Repère : x est compté dans le sens du regard (positif = devant), y vers le bas,
## depuis les pieds du tireur.

@export_group("Tir")
## Temps pour dégainer avant le premier tir (secondes).
@export var draw_time: float = 0.12
## Durée d'un tir (recul) : c'est aussi l'intervalle minimal entre deux tirs.
@export var fire_cooldown: float = 0.28
## Arme rengainée automatiquement après ce temps sans tirer ni se protéger.
@export var holster_delay: float = 3.0
## Vitesse du projectile (pixels par seconde).
@export var projectile_speed: float = 900.0
## Distance maximale parcourue par un projectile avant de s'éteindre (pixels) :
## environ la largeur d'un écran. Pas de tir d'un bout à l'autre d'une grande salle.
@export var projectile_range: float = 1000.0
## Point de départ du tir debout, depuis les pieds. Sa hauteur compte pour le
## gameplay : un personnage accroupi (1,2 bloc = 58 px) est plus bas que le tir,
## qui lui passe au-dessus ; un couvert de 1,5 bloc (72 px) arrête les tirs bas
## mais pas celui-ci… qui passe juste au-dessus.
@export var muzzle_offset: Vector2 = Vector2(38, -76)
## Point de départ d'un tir à genou (les Sentinelles visent ainsi un Élias accroupi).
@export var low_muzzle_offset: Vector2 = Vector2(36, -40)

@export_group("Tir chargé")
## Temps de charge (secondes), en maintenant la détente après un tir.
@export var charge_time: float = 0.8
## Vitesse du projectile chargé.
@export var charged_projectile_speed: float = 1150.0

@export_group("Bouclier")
## Distance entre le tireur et son bouclier (pixels, vers l'avant).
@export var shield_offset_x: float = 30.0
## Taille du mur d'énergie (largeur, hauteur) en pixels. Il couvre tout le corps.
@export var shield_size: Vector2 = Vector2(14, 104)
## Après avoir été brisé par un tir chargé, délai avant de pouvoir le relever.
@export var shield_broken_cooldown: float = 2.0

@export_group("Apparence et son")
## Son du tir normal : identifiant dans la bibliothèque de sons (le tir chargé et
## le bouclier sont communs à toutes les armes). Le RAYON DE BRUIT d'un tir est
## réglé dans la bibliothèque (resources/audio/sound_library.tres), avec le son.
@export var shot_sound_id: StringName = &"weapon_shot"
## Couleur du projectile et de ses impacts.
@export var projectile_color: Color = Color("9ff5d0")
## Couleur du bouclier.
@export var shield_color: Color = Color("7fe8ff")
