extends Node

const Daily := preload("res://scripts/daily/calendar.gd")
const VERSION := 2
const PATH := "user://save.json"

var data := defaults()
var storage_path := PATH
var _startup_error := OK


func _ready() -> void:
	_startup_error = load_game(storage_path)


static func defaults() -> Dictionary:
	return {
		"version": VERSION,
		"coins": 0,
		"daily": Daily.empty_progress(),
		"settings": {"sound": true, "music": true, "vibration": true, "calm_mode": false, "language": ""},
	}


static func migrate(raw: Dictionary) -> Dictionary:
	var version: Variant = raw.get("version", 0)
	if not (version is int or version is float) or version < 0 or version > VERSION or version != floor(version):
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
	result.daily = Daily.clean_progress(raw.get("daily"))
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


func write_game(snapshot: Dictionary, path := "") -> Error:
	if path.is_empty():
		if _startup_error != OK:
			return _startup_error
		path = storage_path
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
