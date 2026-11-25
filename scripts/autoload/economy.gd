extends Node

@onready var _save := get_node("/root/Save")
@onready var _events := get_node("/root/Events")


func balance() -> int:
	return _save.data.coins


func earn(amount: int) -> bool:
	return amount > 0 and amount <= 2147483647 - balance() and _set_balance(balance() + amount)


func spend(amount: int) -> bool:
	return amount > 0 and amount <= balance() and _set_balance(balance() - amount)


func _set_balance(value: int) -> bool:
	var snapshot: Dictionary = _save.data.duplicate(true)
	snapshot.coins = value
	if _save.write_game(snapshot) != OK:
		return false
	_events.coins_changed.emit(value)
	return true
