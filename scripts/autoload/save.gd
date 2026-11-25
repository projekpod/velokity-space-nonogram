extends Node

const Daily := preload("res://scripts/daily/calendar.gd")
const Bonus := preload("res://scripts/nonogram/bonus.gd")
const Meta := preload("res://scripts/meta/progression.gd")
const VERSION := 7
const MAX_FREE_COIN_ADS := 5
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
		"onboarding_complete": false,
		"daily": Daily.empty_progress(),
		"nonogram": {},
		"bonus_clears": 0,
		"free_coin_ads": {"last_day": -1, "count": 0},
		"meta": Meta.defaults(),
		"settings": {"sound": true, "music": true, "vibration": true, "calm_mode": false, "language": ""},
	}


static func migrate(raw: Dictionary) -> Dictionary:
	var version: Variant = raw.get("version", 0)
	if not _is_version(version) or version > VERSION:
		return {}
	var result := defaults()
	result.onboarding_complete = version < 7 or raw.get("onboarding_complete") == true
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
	var badges := 0
	if version >= 3 and progress is Dictionary:
		for level_id: Variant in progress:
			var record: Variant = progress[level_id]
			if not level_id is String or level_id.is_empty() or not record is Dictionary:
				continue
			var reward: Variant = record.get("reward")
			var doubled: Variant = record.get("doubled")
			if _is_version(reward) and reward > 0 and reward <= 2147483647 and doubled is bool:
				result.nonogram[level_id] = {"reward": int(reward), "doubled": doubled}
				if version >= 4 and record.get("flawless") is bool and record.flawless:
					result.nonogram[level_id].flawless = true
					badges += 1
	var bonus_clears: Variant = raw.get("bonus_clears")
	if version >= 4 and _is_version(bonus_clears) and bonus_clears <= Bonus.unlocked_clears(badges):
		result.bonus_clears = int(bonus_clears)
	var legacy_xp: int = (result.nonogram.size() + result.daily.clears) * Meta.CLEAR_XP
	result.meta.xp = mini(legacy_xp, Meta.MAX_XP)
	var stored_meta: Variant = raw.get("meta")
	if version >= 5 and stored_meta is Dictionary:
		_restore_meta(result.meta, stored_meta)
	var ad_claims: Variant = raw.get("free_coin_ads")
	if version >= 6 and ad_claims is Dictionary:
		var day: Variant = ad_claims.get("last_day")
		var count: Variant = ad_claims.get("count")
		if _is_version(day) and day <= Daily.MAX_DAY and _is_version(count):
			result.free_coin_ads = {"last_day": int(day), "count": int(min(count, MAX_FREE_COIN_ADS))}
	return result


static func _restore_meta(meta: Dictionary, stored: Dictionary) -> void:
	var xp: Variant = stored.get("xp")
	if _is_version(xp) and xp <= Meta.MAX_XP:
		meta.xp = maxi(meta.xp, int(xp))
	meta.login = Daily.clean_progress(stored.get("login"))
	var purchased: Variant = stored.get("purchased")
	var equipped: Variant = stored.get("equipped")
	for id: String in Meta.COSTUMES:
		var costume: Dictionary = Meta.COSTUMES[id]
		if costume.has("price") and purchased is Dictionary and purchased.get(id) is bool and purchased[id]:
			meta.purchased[id] = true
		if equipped is Dictionary and equipped.get(costume.slot) == id:
			meta.equipped[costume.slot] = id


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
