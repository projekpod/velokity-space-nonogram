extends Node

const Daily := preload("res://scripts/daily/calendar.gd")
const VERSION := 3
const PATH := "user://save.json"

var data := defaults()
var storage_path := PATH
var _future_saves: Dictionary = {}
var _corrupt_saves: Dictionary = {}


func _ready() -> void:
	if OS.has_feature("web") and OS.has_feature("qa"):
		storage_path = "user://qa-save.json"
	load_game()


static func defaults() -> Dictionary:
	return {
		"version": VERSION,
		"coins": 0,
		"daily": Daily.empty_progress(),
		"nonogram": {},
		"settings": {"sound": true, "music": true, "vibration": true, "calm_mode": false, "language": ""},
	}


static func migrate(raw: Dictionary) -> Dictionary:
	var version: Variant = raw.get("version", 0)
	if not _is_version(version) or version > VERSION:
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
	var progress: Variant = raw.get("nonogram")
	if version >= 3 and progress is Dictionary:
		for level_id: Variant in progress:
			var record: Variant = progress[level_id]
			if not level_id is String or level_id.is_empty() or not record is Dictionary:
				continue
			var reward: Variant = record.get("reward")
			var doubled: Variant = record.get("doubled")
			if _is_version(reward) and reward > 0 and reward <= 2147483647 and doubled is bool:
				result.nonogram[level_id] = {"reward": int(reward), "doubled": doubled}
	return result


static func _is_version(version: Variant) -> bool:
	return (version is int or version is float) and is_finite(version) and version >= 0 and version == floor(version)


func load_game(path := "") -> Error:
	if path.is_empty():
		path = storage_path
	if not FileAccess.file_exists(path):
		data = defaults()
		_future_saves.erase(path)
		_corrupt_saves.erase(path)
		return OK
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	var json := JSON.new()
	var parsed := json.parse(file.get_as_text())
	file.close()
	_future_saves.erase(path)
	_corrupt_saves.erase(path)
	if parsed == OK and json.data is Dictionary:
		var version: Variant = json.data.get("version", 0)
		if _is_version(version):
			if version > VERSION:
				_future_saves[path] = true
				return ERR_FILE_UNRECOGNIZED
			data = migrate(json.data)
			return OK
	data = defaults()
	_corrupt_saves[path] = true
	return _archive_corrupt(path)


func _archive_corrupt(path: String) -> Error:
	if not FileAccess.file_exists(path):
		_corrupt_saves.erase(path)
		return OK
	var prefix := "%s.corrupt-%d" % [path.get_basename(), int(Time.get_unix_time_from_system())]
	var archive := prefix + ".json"
	var suffix := 1
	while FileAccess.file_exists(archive) or DirAccess.dir_exists_absolute(archive):
		archive = "%s-%d.json" % [prefix, suffix]
		suffix += 1
	var error := DirAccess.rename_absolute(path, archive)
	if error == OK:
		_corrupt_saves.erase(path)
	return error


func write_game(snapshot: Dictionary, path := "") -> Error:
	if path.is_empty():
		path = storage_path
	if _future_saves.has(path):
		return ERR_FILE_UNRECOGNIZED
	if _corrupt_saves.has(path):
		var error := _archive_corrupt(path)
		if error != OK:
			return error
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
