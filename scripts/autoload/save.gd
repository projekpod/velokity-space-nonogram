extends Node

signal startup_finished
signal _bridge_read(ok: bool, value: Variant)
signal _bridge_written(ok: bool)
signal _queue_drained

const Daily := preload("res://scripts/daily/calendar.gd")
const Bonus := preload("res://scripts/nonogram/bonus.gd")
const Meta := preload("res://scripts/meta/progression.gd")
const Cosmetics := preload("res://scripts/meta/cosmetics.gd")
const Twists := preload("res://scripts/nonogram/twists.gd")
const VERSION := 9
const VOLUME_SETTINGS := ["music_volume", "effects_volume"]
const MAX_FREE_COIN_ADS := 5
const PATH := "user://save.json"
const BRIDGE_KEY := "velokity-save"

var data := defaults()
var storage_path := PATH
var _future_saves: Dictionary = {}
var _corrupt_saves: Dictionary = {}
var startup_complete := false
var _bridge_storage
var _bridge_set: Callable
var _bridge_key := BRIDGE_KEY
var _bridge_writable := true
var _bridge_write_busy := false
var _pending_writes: Array[WriteRequest] = []


class WriteRequest extends RefCounted:
	signal finished(error: Error)
	var snapshot: Dictionary

	func _init(value: Dictionary) -> void:
		snapshot = value.duplicate(true)


func _ready() -> void:
	if OS.has_feature("web"):
		if OS.has_feature("qa"):
			storage_path = "user://qa-save.json"
			_bridge_key += "-qa"
		_bridge_storage = get_node("/root/Bridge").storage
		if _bridge_storage != null:
			_bridge_set = func(key: String, value: String, callback: Callable) -> void:
				_bridge_storage.set(key, value, callback)
	if _bridge_storage == null:
		load_game()
	else:
		await _load_bridge()
	startup_complete = true
	startup_finished.emit()


func _load_bridge() -> void:
	_bridge_storage.get([_bridge_key], _on_bridge_read)
	var response: Array = await _bridge_read
	if not response[0] or not response[1] is Array or response[1].size() != 1:
		_bridge_writable = false
		return
	var raw: Variant = response[1][0]
	if raw == null:
		if not FileAccess.file_exists(storage_path):
			return
		_bridge_writable = load_game() == OK
		if _bridge_writable:
			_bridge_writable = await _write_bridge(_bridge_key, JSON.stringify(data))
			if _bridge_writable and FileAccess.file_exists(storage_path):
				DirAccess.remove_absolute(storage_path)
		return

	var json := JSON.new()
	if raw is String and json.parse(raw) == OK and json.data is Dictionary:
		var version: Variant = json.data.get("version", 0)
		if _is_version(version):
			if version > VERSION:
				_future_saves[storage_path] = true
			else:
				data = migrate(json.data)
			return
	var archive := "%s-corrupt-%d" % [_bridge_key, int(Time.get_unix_time_from_system() * 1000000.0)]
	_bridge_writable = await _write_bridge(archive, raw if raw is String else JSON.stringify(raw))
	if _bridge_writable:
		_bridge_writable = await _write_bridge(_bridge_key, JSON.stringify(data))


func _on_bridge_read(ok: bool, value: Variant) -> void:
	_bridge_read.emit.call_deferred(ok, value)


func _on_bridge_written(ok: bool) -> void:
	_bridge_written.emit.call_deferred(ok)


func _write_bridge(key: String, value: String) -> bool:
	_bridge_set.call(key, value, _on_bridge_written)
	return await _bridge_written


# Transactions that read the saved state wait before validating or taking their snapshot.
func wait_for_pending_writes() -> void:
	while _bridge_write_busy:
		await _queue_drained


func commit(snapshot: Dictionary) -> Error:
	if not _bridge_set.is_valid():
		return write_game(snapshot)
	if not startup_complete:
		return ERR_BUSY
	if not _bridge_writable or _future_saves.has(storage_path):
		return ERR_FILE_CANT_WRITE
	var request := WriteRequest.new(snapshot)
	_pending_writes.push_back(request)
	if not _bridge_write_busy:
		_bridge_write_busy = true
		_drain_writes()
	return await request.finished


func _drain_writes() -> void:
	while not _pending_writes.is_empty():
		var request: WriteRequest = _pending_writes.pop_front()
		var saved := await _write_bridge(_bridge_key, JSON.stringify(request.snapshot))
		if saved:
			data = request.snapshot
		request.finished.emit(OK if saved else ERR_FILE_CANT_WRITE)
	_bridge_write_busy = false
	_queue_drained.emit.call_deferred()


func needs_onboarding() -> bool:
	return not data.onboarding_complete and not _future_saves.has(storage_path)


func mark_twist_seen(kind: String) -> bool:
	if kind not in Twists.KINDS:
		return false
	await wait_for_pending_writes()
	if data.twist_tips.has(kind):
		return true
	var snapshot := data.duplicate(true)
	snapshot.twist_tips[kind] = true
	return await commit(snapshot) == OK


static func defaults() -> Dictionary:
	return {
		"version": VERSION,
		"coins": 0,
		"onboarding_complete": false,
		"twist_tips": {},
		"daily": Daily.empty_progress(),
		"nonogram": {},
		"bonus_clears": 0,
		"free_coin_ads": {"last_day": -1, "count": 0},
		"meta": Meta.defaults(),
		"settings": {"sound": true, "music": true, "music_volume": 100, "effects_volume": 100, "vibration": true, "calm_mode": false, "language": ""},
	}


static func migrate(raw: Dictionary) -> Dictionary:
	var version: Variant = raw.get("version", 0)
	if not _is_version(version) or version > VERSION:
		return {}
	var result := defaults()
	result.onboarding_complete = version < 7 or raw.get("onboarding_complete") == true
	var tips: Variant = raw.get("twist_tips")
	if version >= 9 and tips is Dictionary:
		for kind: String in Twists.KINDS:
			if tips.get(kind) is bool and tips[kind]:
				result.twist_tips[kind] = true
	var coins: Variant = raw.get("coins", 0)
	if (coins is int or coins is float) and coins >= 0 and coins <= 2147483647 and coins == floor(coins):
		result.coins = int(coins)
	var stored_settings: Variant = raw.get("settings", {})
	if stored_settings is Dictionary:
		for key: String in result.settings:
			var value: Variant = stored_settings.get(key)
			if key in VOLUME_SETTINGS:
				if _is_version(value) and value <= 100:
					result.settings[key] = int(value)
			elif typeof(value) == typeof(result.settings[key]):
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
		if version >= 8:
			_restore_cosmetics(result.meta, stored_meta, "cat", "cats", Cosmetics.DEFAULT_CAT)
			_restore_cosmetics(result.meta, stored_meta, "skin", "skins", Cosmetics.DEFAULT_SKIN)
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


static func _restore_cosmetics(meta: Dictionary, stored: Dictionary, category: String, ownership: String, default_id: String) -> void:
	var purchased: Variant = stored.get(ownership)
	for id: String in Cosmetics.items(category):
		if id != default_id and purchased is Dictionary and purchased.get(id) == true:
			meta[ownership][id] = true
	var selected: Variant = stored.get(category)
	if selected is String and meta[ownership].has(selected):
		meta[category] = selected


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
