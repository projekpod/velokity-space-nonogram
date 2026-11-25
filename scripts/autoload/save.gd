extends Node

const VERSION := 1
const PATH := "user://save.json"

var data := defaults()


func _ready() -> void:
	load_game()


static func defaults() -> Dictionary:
	return {
		"version": VERSION,
		"coins": 0,
		"settings": {"sound": true, "music": true, "vibration": true, "calm_mode": false, "language": ""},
	}


static func migrate(raw: Dictionary) -> Dictionary:
	var version: Variant = raw.get("version", 0)
	if not (version is int or version is float) or (version != 0 and version != VERSION):
		return {}
	var result := defaults()
	var coins: Variant = raw.get("coins", 0)
	if (coins is int or coins is float) and coins >= 0 and coins <= 2147483647 and coins == floor(coins):
		result.coins = int(coins)
	var stored_settings: Variant = raw.get("settings", {})
	if stored_settings is Dictionary:
		for key: String in result.settings:
			var value: Variant = stored_settings.get(key)
			if typeof(value) == typeof(result.settings[key]):
				result.settings[key] = value
		if result.settings.language not in ["", "en", "id"]:
			result.settings.language = ""
	return result


func load_game(path := PATH) -> Error:
	if not FileAccess.file_exists(path):
		return OK
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not raw is Dictionary:
		return ERR_FILE_CORRUPT
	var migrated := migrate(raw)
	if migrated.is_empty():
		return ERR_INVALID_DATA
	data = migrated
	return OK


func write_game(snapshot: Dictionary, path := PATH) -> Error:
	var staged := path + ".tmp"
	var file := FileAccess.open(staged, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(snapshot))
	file.flush()
	var error := file.get_error()
	file.close()
	if error == OK:
		error = DirAccess.rename_absolute(staged, path)
	if error == OK:
		data = snapshot
	else:
		DirAccess.remove_absolute(staged)
	return error
