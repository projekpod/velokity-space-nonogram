extends Node

@onready var _save := get_node("/root/Save")
@onready var _events := get_node("/root/Events")
var _device_locale := TranslationServer.get_locale()


func _ready() -> void:
	for language in ["en", "id"]:
		var path := "res://i18n/strings.%s.translation" % language
		if ResourceLoader.exists(path):
			TranslationServer.add_translation(load(path))
	_apply_locale()


func get_value(key: String) -> Variant:
	return _save.data.settings.get(key)


func set_value(key: String, value: Variant) -> bool:
	var previous: Variant = get_value(key)
	if previous == null or typeof(previous) != typeof(value):
		return false
	if key == "language" and value not in ["", "en", "id"]:
		return false
	var snapshot: Dictionary = _save.data.duplicate(true)
	snapshot.settings[key] = value
	if _save.write_game(snapshot) != OK:
		return false
	_apply_locale()
	_events.settings_changed.emit()
	return true


func _apply_locale() -> void:
	var locale: String = get_value("language")
	TranslationServer.set_locale(_device_locale if locale.is_empty() else locale)


func vibrate_for_mistake() -> void:
	if get_value("vibration") and not get_value("calm_mode"):
		Input.vibrate_handheld(45)
