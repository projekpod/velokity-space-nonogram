extends Node

const EFFECTS := &"SFX"
const MUSIC := &"Music"
const CUES := [&"fill", &"cross", &"mistake", &"line", &"combo", &"win", &"coin", &"button", &"celebration"]

@onready var _settings := get_node("/root/Settings")
@onready var _events := get_node("/root/Events")
@onready var _menu_music: AudioStreamWAV = load("res://audio/music_menu.wav")
@onready var _puzzle_music: AudioStreamWAV = load("res://audio/music_puzzle.wav")

var _effects: Dictionary = {}
var _music: AudioStreamPlayer
var _gameplay := false
var _input_received := false


func _ready() -> void:
	for bus: StringName in [EFFECTS, MUSIC]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	for effect: StringName in CUES:
		var player := AudioStreamPlayer.new()
		player.bus = EFFECTS
		player.stream = load("res://audio/%s.wav" % effect)
		player.max_polyphony = 2 if effect in [&"fill", &"cross"] else 1
		_effects[effect] = player
		add_child(player)
	_music = AudioStreamPlayer.new()
	# Web sample playback restarts through a browser callback. Stream the loop through the mixer.
	_music.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	_music.bus = MUSIC
	add_child(_music)
	_events.settings_changed.connect(_apply_settings)
	_events.coins_earned.connect(play_effect.bind(&"coin"))
	_apply_settings()


func _input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event is InputEventMouseButton:
		if event.button_index > MOUSE_BUTTON_MIDDLE:
			return
	elif not (event is InputEventScreenTouch or event is InputEventKey or event is InputEventJoypadButton):
		return
	_input_received = true
	set_process_input(false)
	_sync_music()


func _notification(what: int) -> void:
	if what == NOTIFICATION_UNPAUSED and _music != null:
		_sync_music()


func play_effect(effect: StringName) -> void:
	if _input_received and not get_tree().paused and _settings.get_value("sound"):
		var player: AudioStreamPlayer = _effects.get(effect)
		if player != null:
			player.play()


func set_gameplay(active: bool) -> void:
	_gameplay = active
	_sync_music()


func _sync_music() -> void:
	if not _input_received or not _settings.get_value("music"):
		_music.stop()
		return
	if get_tree().paused:
		return
	var track := _puzzle_music if _gameplay else _menu_music
	if _music.stream != track:
		_music.stream = track
	if not _music.playing:
		_music.play()


func _apply_settings() -> void:
	var calm: bool = _settings.get_value("calm_mode")
	var effects := AudioServer.get_bus_index(EFFECTS)
	var music := AudioServer.get_bus_index(MUSIC)
	AudioServer.set_bus_mute(effects, not _settings.get_value("sound"))
	AudioServer.set_bus_mute(music, not _settings.get_value("music"))
	AudioServer.set_bus_volume_db(effects, -14.0 if calm else -5.0)
	AudioServer.set_bus_volume_db(music, -22.0 if calm else -13.0)
	_sync_music()
