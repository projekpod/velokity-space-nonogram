extends Node

@onready var _settings := get_node("/root/Settings")


func play_effect(player: AudioStreamPlayer) -> void:
	if _settings.get_value("sound"):
		player.play()
