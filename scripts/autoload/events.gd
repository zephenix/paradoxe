extends Node
## Bus de signaux global (autoload « Events »).
##
## Plutôt que de relier chaque objet à tous les autres, un objet émet ici un
## signal « d'intérêt général », et ceux que ça concerne s'y abonnent :
##     Events.player_died.emit(&"fall")               # côté émetteur
##     Events.player_died.connect(_on_player_died)    # côté abonné
##
## Analogie VBA : ce sont des événements publics auxquels n'importe quel
## module peut s'abonner, sans que l'émetteur connaisse ses abonnés.
##
## Les signaux sont ajoutés au fil des jalons ; chacun indique qui l'émet.

# Ce script ne fait que déclarer des signaux émis ailleurs : on coupe
# l'avertissement « signal jamais émis dans cette classe ».
@warning_ignore_start("unused_signal")

## L'audio vient d'être débloqué (premier clic / première touche). Émis par AudioManager.
signal audio_unlocked

## Les réglages ont changé (volumes, touches, options). Émis par Settings.
signal settings_changed

## Le joueur est mort. cause : &"fall", &"shot", &"creature", &"hazard". (J3)
signal player_died(cause: StringName)

## Le joueur réapparaît au dernier checkpoint. (J3)
signal player_respawned

## Un checkpoint vient d'être atteint. (J3)
signal checkpoint_reached(checkpoint_id: StringName)

## Le joueur entre dans une nouvelle salle. (J2)
signal room_entered(room: Node)

## Le niveau d'alerte global (0 = calme, 1 = combat) a changé. (J6)
signal alert_level_changed(level: float)

@warning_ignore_restore("unused_signal")
