extends RefCounted

const WEEKDAY_COUNTS := [18, 17, 17, 17, 17, 17, 17]
const REWARDS := [10, 15, 20, 25, 30, 40, 60]
const SECONDS_PER_DAY := 86400
const MAX_DAY := 3652059


static func day_number(date: Dictionary) -> int:
	# Interpret the local date's Y/M/D as midnight to get a timezone-independent ordinal.
	var midnight := {"year": date.year, "month": date.month, "day": date.day}
	@warning_ignore("integer_division")
	return Time.get_unix_time_from_datetime_dict(midnight) / SECONDS_PER_DAY


static func today() -> int:
	return day_number(Time.get_date_dict_from_system())


static func weekday(day: int) -> int:
	# Unix day zero is a Thursday.
	return posmod(day + 3, 7)


static func puzzle_name(day: int) -> String:
	var weekday_index := weekday(day)
	@warning_ignore("integer_division")
	var week := (day + 3 - weekday_index) / 7
	var member := posmod(week, WEEKDAY_COUNTS[weekday_index]) + 1
	return "daily-%d-%02d.json" % [weekday_index + 1, member]


static func puzzle_for(day: int) -> Dictionary:
	var path := "res://data/daily/" + puzzle_name(day)
	var puzzle: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return puzzle if puzzle is Dictionary else {}


static func empty_progress() -> Dictionary:
	return {"last_day": -1, "streak": 0, "clears": 0}


static func clean_progress(saved: Variant) -> Dictionary:
	if saved is Dictionary:
		var day: Variant = saved.get("last_day")
		var streak: Variant = saved.get("streak")
		if _is_whole_number(day) and _is_whole_number(streak):
			if day >= 0 and streak > 0 and streak <= day + 1:
				var clears: Variant = saved.get("clears", streak)
				if not _is_whole_number(clears) or clears < streak or clears > day + 1:
					clears = streak
				return {"last_day": int(day), "streak": int(streak), "clears": int(clears)}
	return empty_progress()


static func _is_whole_number(value: Variant) -> bool:
	return (value is int or value is float) and value >= 0 and value <= MAX_DAY and value == floor(value)


static func active_streak(progress: Dictionary, day: int) -> int:
	return progress.streak if progress.last_day in [day - 1, day] else 0


static func advance(progress: Dictionary, day: int) -> Dictionary:
	if not _is_whole_number(day) or day <= progress.last_day:
		return {}
	return {
		"last_day": day,
		"streak": active_streak(progress, day) + 1,
		"clears": progress.get("clears", progress.streak) + 1,
	}


static func reward(streak: int) -> int:
	return REWARDS[(streak - 1) % REWARDS.size()]


static func collected_slots(progress: Dictionary, day: int, cycle_size := REWARDS.size()) -> int:
	var streak := active_streak(progress, day)
	if streak == 0:
		return 0
	if progress.last_day == day:
		return (streak - 1) % cycle_size + 1
	return streak % cycle_size
