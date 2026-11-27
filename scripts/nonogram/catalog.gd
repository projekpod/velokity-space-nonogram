extends RefCounted

const DIRECTORY := "res://data/levels"
const MANIFEST := "res://data/config/planets.json"
const PLANET_CLEAR_REQUIREMENT := 15
const PICTURES_PER_ALBUM := 20


static var _worlds := _read_worlds()


static func _read_worlds() -> Dictionary:
	var worlds := {}
	var entries: Array = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	for entry: Dictionary in entries:
		worlds[entry.id] = entry
	return worlds


static func planets() -> PackedStringArray:
	return PackedStringArray(_worlds.keys())


static func album_coins(planet: String) -> int:
	return int(_worlds.get(planet, {}).get("coins", 0))


static func previous_planet(planet: String) -> String:
	var ordered := planets()
	var index := ordered.find(planet)
	return ordered[index - 1] if index > 0 else ""


static func read() -> Array[Dictionary]:
	var levels: Array[Dictionary] = []
	var paths := DirAccess.get_files_at(DIRECTORY)
	paths.sort()
	for planet in planets():
		for file in paths:
			if not file.begins_with(planet + "-") or not file.ends_with(".json"):
				continue
			var level: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY.path_join(file)))
			if level is Dictionary:
				levels.append(level)
	return levels
