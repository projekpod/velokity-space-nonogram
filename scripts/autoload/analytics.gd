extends Node

const ALLOWED := [&"puzzle_started", &"puzzle_won", &"puzzle_lost"]
var _counts: Dictionary = {}


func record(event: StringName) -> void:
	if event in ALLOWED:
		_counts[event] = count(event) + 1


func count(event: StringName) -> int:
	return _counts.get(event, 0)
