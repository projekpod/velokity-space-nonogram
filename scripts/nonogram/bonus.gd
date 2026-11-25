extends RefCounted

const DIRECTORY := "res://data/levels/bonus"
const BADGES_PER_ROUND := 4
const STAGES := 3
const BASE_COINS := 10
const ROUND_COINS := BASE_COINS * (1 + 2 + 3)


static func unlocked_clears(badges: int) -> int:
	@warning_ignore("integer_division")
	return (badges / BADGES_PER_ROUND) * STAGES


static func multiplier(index: int) -> int:
	return index % STAGES + 1


static func puzzle_for(index: int) -> Dictionary:
	var files := DirAccess.get_files_at(DIRECTORY)
	if index < 0 or files.is_empty():
		return {}
	files.sort()
	var path := DIRECTORY.path_join(files[index % files.size()])
	var level: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return level if level is Dictionary else {}
