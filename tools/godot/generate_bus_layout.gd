extends SceneTree
## Génère res://default_bus_layout.tres (la table de mixage audio du jeu)
## à partir de la description de scripts/audio/audio_buses.gd.
##
## Pourquoi un générateur plutôt que l'éditeur ? Pour que l'organisation des
## bus soit décrite à UN seul endroit, lisible et commentée, et reproductible.
## (Rien n'empêche de retoucher ensuite les réglages dans l'onglet « Audio »
## de l'éditeur : ce fichier ne sert qu'à repartir d'une base propre.)
##
## Lancement :
##     godot --headless --path . -s res://tools/godot/generate_bus_layout.gd

const OUTPUT_PATH: String = "res://default_bus_layout.tres"


func _initialize() -> void:
	_reset_mixer()

	# 1) Création des bus, dans l'ordre imposé (un bus n'envoie que vers la gauche).
	for i in range(1, AudioBuses.ORDER.size()):
		AudioServer.add_bus(i)
		AudioServer.set_bus_name(i, AudioBuses.ORDER[i])
	for bus: StringName in AudioBuses.SENDS:
		AudioServer.set_bus_send(AudioBuses.index(bus), AudioBuses.SENDS[bus])

	# 2) Effets du Master : étouffement, gain dramatique, limiteur.
	var master: int = AudioBuses.index(AudioBuses.MASTER)
	var master_lowpass := AudioEffectLowPassFilter.new()
	master_lowpass.resource_name = "Etouffement"
	master_lowpass.cutoff_hz = AudioBuses.LOWPASS_OPEN_HZ
	master_lowpass.resonance = 0.6
	AudioServer.add_bus_effect(master, master_lowpass, AudioBuses.MASTER_FX_LOWPASS)
	AudioServer.set_bus_effect_enabled(master, AudioBuses.MASTER_FX_LOWPASS, false)

	var drama_gain := AudioEffectAmplify.new()
	drama_gain.resource_name = "GainDramatique"
	drama_gain.volume_db = 0.0
	AudioServer.add_bus_effect(master, drama_gain, AudioBuses.MASTER_FX_GAIN)

	var limiter := AudioEffectHardLimiter.new()
	limiter.resource_name = "Limiteur"
	limiter.ceiling_db = -0.5
	AudioServer.add_bus_effect(master, limiter, AudioBuses.MASTER_FX_LIMITER)

	# 3) Effets du bus Monde : acoustique de la salle (réglée par zone en J5).
	var world: int = AudioBuses.index(AudioBuses.WORLD)
	var reverb := AudioEffectReverb.new()
	reverb.resource_name = "ReverbSalle"
	reverb.predelay_msec = 20.0
	reverb.predelay_feedback = 0.2
	reverb.room_size = 0.6
	reverb.damping = 0.5
	reverb.hipass = 0.2   # pas de réverbération dans les graves : évite un son boueux
	reverb.dry = 1.0
	reverb.wet = 0.0
	AudioServer.add_bus_effect(world, reverb, AudioBuses.WORLD_FX_REVERB)
	AudioServer.set_bus_effect_enabled(world, AudioBuses.WORLD_FX_REVERB, false)

	var world_lowpass := AudioEffectLowPassFilter.new()
	world_lowpass.resource_name = "FiltreSalle"
	world_lowpass.cutoff_hz = AudioBuses.LOWPASS_OPEN_HZ
	AudioServer.add_bus_effect(world, world_lowpass, AudioBuses.WORLD_FX_LOWPASS)
	AudioServer.set_bus_effect_enabled(world, AudioBuses.WORLD_FX_LOWPASS, false)

	# 4) Sauvegarde.
	var layout: AudioBusLayout = AudioServer.generate_bus_layout()
	var err: Error = ResourceSaver.save(layout, OUTPUT_PATH)
	if err != OK:
		printerr("Échec de l'enregistrement de %s (erreur %d)" % [OUTPUT_PATH, err])
		quit(1)
		return
	print("Table de mixage écrite dans %s : %s" % [OUTPUT_PATH, ", ".join(AudioBuses.ORDER)])
	quit(0)


## Remet le mixeur à zéro : un seul bus (Master), sans effet.
func _reset_mixer() -> void:
	while AudioServer.bus_count > 1:
		AudioServer.remove_bus(AudioServer.bus_count - 1)
	while AudioServer.get_bus_effect_count(0) > 0:
		AudioServer.remove_bus_effect(0, 0)
	AudioServer.set_bus_name(0, AudioBuses.MASTER)
	AudioServer.set_bus_volume_db(0, 0.0)
