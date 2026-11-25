extends Node

const Daily := preload("res://scripts/daily/calendar.gd")
const Combo := preload("res://scripts/nonogram/combo.gd")
const Bonus := preload("res://scripts/nonogram/bonus.gd")
const MAX_COINS := 2147483647
const MAX_FIRST_CLEAR := 60
const HINT_COST := 10
const CONTINUE_COST := 20

@onready var _save := get_node("/root/Save")
@onready var _events := get_node("/root/Events")


func balance() -> int:
	return _save.data.coins


func earn(amount: int) -> bool:
	return amount > 0 and amount <= MAX_COINS - balance() and _set_balance(balance() + amount)


func spend(amount: int) -> bool:
	return amount > 0 and amount <= balance() and _set_balance(balance() - amount)


func is_nonogram_cleared(level_id: String) -> bool:
	return _save.data.nonogram.has(level_id)


func player_level() -> int:
	var clears: int = _save.data.nonogram.size() + _save.data.daily.get("clears", _save.data.daily.streak)
	@warning_ignore("integer_division")
	return 1 + clears / 2


func has_flawless_badge(level_id: String) -> bool:
	return _save.data.nonogram.get(level_id, {}).get("flawless", false)


func badge_count() -> int:
	var count := 0
	for level_id: String in _save.data.nonogram:
		count += int(has_flawless_badge(level_id))
	return count


# Save the first-clear reward and any new badge in the same transaction.
func award_nonogram(level_id: String, lives: int, combo_lines := 0) -> int:
	if level_id.is_empty() or lives < 1 or lives > 3 or combo_lines < 0:
		return -1
	var first_clear := not is_nonogram_cleared(level_id)
	var new_badge := lives == 3 and not has_flawless_badge(level_id)
	if not first_clear and not new_badge:
		return 0
	var amount := mini((15 + 5 * lives) * Combo.multiplier(combo_lines), MAX_FIRST_CLEAR) if first_clear else 0
	if amount > MAX_COINS - balance():
		return -1
	var snapshot: Dictionary = _save.data.duplicate(true)
	if first_clear:
		snapshot.nonogram[level_id] = {"reward": amount, "doubled": false}
	if new_badge:
		snapshot.nonogram[level_id].flawless = true
	snapshot.coins += amount
	return amount if _commit(snapshot) else -1


func next_bonus_index() -> int:
	var index: int = _save.data.bonus_clears
	return index if index < Bonus.unlocked_clears(badge_count()) else -1


func award_bonus(index: int) -> int:
	if index < 0 or index != next_bonus_index():
		return -1
	var amount := Bonus.BASE_COINS * Bonus.multiplier(index)
	if amount > MAX_COINS - balance():
		return -1
	var snapshot: Dictionary = _save.data.duplicate(true)
	snapshot.bonus_clears += 1
	snapshot.coins += amount
	return amount if _commit(snapshot) else -1


func double_nonogram_reward(level_id: String) -> int:
	var progress: Dictionary = _save.data.nonogram
	if not progress.has(level_id) or progress[level_id].doubled:
		return 0
	var amount: int = progress[level_id].reward
	if amount > MAX_COINS - balance():
		return -1
	var snapshot: Dictionary = _save.data.duplicate(true)
	snapshot.nonogram[level_id].doubled = true
	snapshot.coins += amount
	return amount if _commit(snapshot) else -1


# Positive values are coins collected. Zero is an already recorded date, -1 a failed write.
func award_daily(day: int) -> int:
	var progress := Daily.advance(_save.data.daily, day)
	if progress.is_empty():
		return 0
	var amount := Daily.reward(progress.streak)
	if amount > MAX_COINS - balance():
		return -1
	var snapshot: Dictionary = _save.data.duplicate(true)
	snapshot.daily = progress
	snapshot.coins += amount
	return amount if _commit(snapshot) else -1


func _set_balance(value: int) -> bool:
	var snapshot: Dictionary = _save.data.duplicate(true)
	snapshot.coins = value
	return _commit(snapshot)


func _commit(snapshot: Dictionary) -> bool:
	if _save.write_game(snapshot) != OK:
		return false
	_events.coins_changed.emit(snapshot.coins)
	return true
