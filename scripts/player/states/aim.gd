extends PlayerState
## Arme dégainée, bras tendu : Élias est prêt à tirer ou à se protéger.
##
## On y entre depuis un état au sol (appui sur « tir » ou « bouclier »), ou en
## revenant d'un tir, d'une charge ou du bouclier. Dégainer prend un court
## instant (draw_time) ; l'action demandée (data["then"]) est exécutée ensuite.
##
## Depuis cet état :
##   - tir            -> Shoot (puis Charge si la détente reste enfoncée)
##   - bouclier       -> Shield, tant que la touche est maintenue
##   - direction opposée : Élias se retourne en gardant l'arme levée (il faut
##     relâcher la direction avant de pouvoir marcher)
##   - direction du regard : il rengaine et se remet à marcher
##   - saut, roulade, bas, haut : comme à l'arrêt (l'arme est rengainée)
##   - rien pendant holster_delay secondes : il rengaine (Idle)

## Arme prête à tirer (fin du geste pour dégainer).
var _drawn: bool = false
## Action à exécuter dès que l'arme est prête : &"fire", &"shield" ou &"".
var _then: StringName = &""
## Temps sans tirer ni se protéger.
var _idle_time: float = 0.0
## Vrai quand le bouclier vient d'être refusé ou de tomber (jauge vide, bouclier
## brisé) : garder la touche enfoncée ne le relève pas, il faut la relâcher.
var _shield_locked: bool = false
## Vrai après un demi-tour, tant que la direction reste enfoncée : on ne se met
## pas à marcher dans la foulée (il faut relâcher la direction d'abord).
var _turned: bool = false


func enter(previous: StringName, data: Dictionary) -> void:
	var p: Player = player
	p.set_crouched(false)
	_then = data.get("then", &"")
	_idle_time = 0.0
	_shield_locked = data.get("shield_locked", false)
	_turned = false
	# Au retour d'un tir, d'une charge ou du bouclier, l'arme est déjà en main.
	_drawn = previous in [&"Shoot", &"Charge", &"Shield"]
	if not _drawn:
		p.weapon.play_draw_sound()
	p.visual.play(&"aim")


func physics_update(delta: float) -> void:
	var p: Player = player
	p.move_on_ground(0.0, delta)  # un Élias qui courait s'arrête en quelques pixels
	if not _drawn:
		if p.lost_ground():
			machine.transition_to(&"Fall")
			return
		if time_in_state < p.weapon.config.draw_time:
			return
		_drawn = true
	if not p.input.shield:
		_shield_locked = false
	if (p.input.shield and not _shield_locked) or _then == &"shield" or p.wants(&"shield"):
		machine.transition_to(&"Shield")
		return
	if _then == &"fire" or p.wants(&"fire"):
		machine.transition_to(&"Shoot")
		return
	_then = &""
	if p.input.move == 0:
		_turned = false
	if p.input.move == -p.facing:
		p.facing = -p.facing  # demi-tour rapide, arme levée
		_turned = true
		_idle_time = 0.0
		return
	if handle_ground_actions():
		return
	if p.input.move == p.facing and not _turned:
		machine.transition_to(&"Run" if p.input.run else &"Walk")
		return
	_idle_time += delta
	if _idle_time >= p.weapon.config.holster_delay:
		machine.transition_to(&"Idle")
