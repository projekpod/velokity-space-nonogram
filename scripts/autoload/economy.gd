extends Node

const Daily := preload("res://scripts/daily/calendar.gd")
const MAX_COINS := 2147483647

@onready var _save := get_node("/root/Save")
@onready var _events := get_node("/root/Events")


func balance() -> int:
	return _save.data.coins


func earn(amount: int) -> bool:
	return amount > 0 and amount <= MAX_COINS - balance() and _set_balance(balance() + amount)


func spend(amount: int) -> bool:
	return amount > 0 and amount <= balance() and _set_balance(balance() - amount)


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
