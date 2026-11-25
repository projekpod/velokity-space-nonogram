extends RefCounted

const DIRECTORY := "res://data/levels"
const PLANETS := ["moon", "mars", "saturn"]


static func read() -> Array[Dictionary]:
	var levels: Array[Dictionary] = []
	var paths := DirAccess.get_files_at(DIRECTORY)
	paths.sort()
	for planet in PLANETS:
		for file in paths:
			if not file.begins_with(planet + "-") or not file.ends_with(".json"):
				continue
			var level: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY.path_join(file)))
			if level is Dictionary:
				levels.append(level)
	return levels
