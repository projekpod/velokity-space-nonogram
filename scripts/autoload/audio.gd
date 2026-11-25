extends Node

@onready var _settings := get_node("/root/Settings")
@onready var _events := get_node("/root/Events")

const EFFECTS := &"SFX"
const MUSIC := &"Music"


func _ready() -> void:
	for bus: StringName in [EFFECTS, MUSIC]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	_events.settings_changed.connect(_apply_settings)
	_apply_settings()


func play_effect(player: AudioStreamPlayer) -> void:
	if not get_tree().paused and _settings.get_value("sound"):
		player.bus = EFFECTS
		player.play()


func play_music(player: AudioStreamPlayer) -> void:
	if not get_tree().paused:
		player.bus = MUSIC
		player.play()


func _apply_settings() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index(EFFECTS), not _settings.get_value("sound"))
	AudioServer.set_bus_mute(AudioServer.get_bus_index(MUSIC), not _settings.get_value("music"))
