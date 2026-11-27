extends Node

const Daily := preload("res://scripts/daily/calendar.gd")
const Combo := preload("res://scripts/nonogram/combo.gd")
const Bonus := preload("res://scripts/nonogram/bonus.gd")
const Catalog := preload("res://scripts/nonogram/catalog.gd")
const Cosmetics := preload("res://scripts/meta/cosmetics.gd")
const Meta := preload("res://scripts/meta/progression.gd")
const SaveSchema := preload("res://scripts/autoload/save.gd")
const FREE_COIN_AMOUNT := 25
const FREE_COIN_LIMIT := SaveSchema.MAX_FREE_COIN_ADS
const MAX_COINS := 2147483647
const MAX_FIRST_CLEAR := 60
const HINT_COST := 30
const CONTINUE_COST := 50

var levels := Catalog.read()

@onready var _save := get_node("/root/Save")
@onready var _events := get_node("/root/Events")


func balance() -> int:
	return _save.data.coins


func earn(amount: int) -> bool:
	await _save.wait_for_pending_writes()
	return amount > 0 and amount <= MAX_COINS - balance() and await _set_balance(balance() + amount)


func spend(amount: int) -> bool:
	await _save.wait_for_pending_writes()
	return amount > 0 and amount <= balance() and await _set_balance(balance() - amount)


func is_nonogram_cleared(level_id: String) -> bool:
	return _save.data.nonogram.has(level_id)


func player_level() -> int:
	var xp: int = _save.data.meta.xp
	@warning_ignore("integer_division")
	return 1 + xp / Meta.XP_PER_LEVEL


func xp_progress() -> int:
	return _save.data.meta.xp % Meta.XP_PER_LEVEL


func album_collected(planet: String) -> int:
	var count := 0
	for level in levels:
		if level.planet == planet and is_nonogram_cleared(level.id):
			count += 1
	return count


func album_reward_title(planet: String) -> String:
	var coins := Catalog.album_coins(planet)
	if coins > 0:
		return tr("COIN_BALANCE") % coins
	return tr(Meta.costume_title(Meta.ALBUM_REWARDS.get(planet, "")))


func achievement_progress(id: String) -> int:
	match id:
		"explorer":
			return _save.data.nonogram.size()
		"flawless":
			return badge_count()
		"stargazer":
			return _save.data.daily.clears
		"bonus_pilot":
			return _save.data.bonus_clears
	return 0


func owns_costume(id: String) -> bool:
	var costume: Dictionary = Meta.COSTUMES.get(id, {})
	if costume.has("price"):
		return _save.data.meta.purchased.has(id)
	if costume.has("album"):
		return album_collected(costume.album) >= Catalog.PICTURES_PER_ALBUM
	if costume.has("achievement"):
		var goal: int = Meta.ACHIEVEMENTS[costume.achievement].goal
		return achievement_progress(costume.achievement) >= goal
	return false


func buy_costume(id: String) -> bool:
	await _save.wait_for_pending_writes()
	var price: int = Meta.COSTUMES.get(id, {}).get("price", 0)
	if price <= 0 or price > balance() or owns_costume(id):
		return false
	var snapshot: Dictionary = _save.data.duplicate(true)
	snapshot.meta.purchased[id] = true
	snapshot.coins -= price
	return await _commit(snapshot)


func equipped_costumes() -> Dictionary:
	var equipped := {}
	for slot: String in _save.data.meta.equipped:
		var id: String = _save.data.meta.equipped[slot]
		if Meta.COSTUMES.get(id, {}).get("slot") == slot and owns_costume(id):
			equipped[slot] = id
	return equipped


func equip_costume(slot: String, id: String) -> bool:
	await _save.wait_for_pending_writes()
	if slot not in Meta.SLOTS:
		return false
	if not id.is_empty() and (Meta.COSTUMES.get(id, {}).get("slot") != slot or not owns_costume(id)):
		return false
	if _save.data.meta.equipped.get(slot, "") == id:
		return true
	var snapshot: Dictionary = _save.data.duplicate(true)
	if id.is_empty():
		snapshot.meta.equipped.erase(slot)
	else:
		snapshot.meta.equipped[slot] = id
	return await _commit(snapshot)


func equipped_cosmetic(category: String) -> String:
	return _save.data.meta[category] if not Cosmetics.items(category).is_empty() else ""


func owns_cosmetic(category: String, id: String) -> bool:
	var item: Dictionary = Cosmetics.items(category).get(id, {})
	return not item.is_empty() and (item.price == 0 or _save.data.meta[category + "s"].has(id))


func buy_cosmetic(category: String, id: String) -> bool:
	await _save.wait_for_pending_writes()
	var price: int = Cosmetics.items(category).get(id, {}).get("price", 0)
	if price <= 0 or price > balance() or owns_cosmetic(category, id):
		return false
	var snapshot: Dictionary = _save.data.duplicate(true)
	snapshot.meta[category + "s"][id] = true
	snapshot.coins -= price
	return await _commit(snapshot)


func equip_cosmetic(category: String, id: String) -> bool:
	await _save.wait_for_pending_writes()
	if not owns_cosmetic(category, id):
		return false
	if equipped_cosmetic(category) == id:
		return true
	var snapshot: Dictionary = _save.data.duplicate(true)
	snapshot.meta[category] = id
	return await _commit(snapshot)


func login_status(day: int) -> Dictionary:
	var progress: Dictionary = _save.data.meta.login
	var slots := Daily.collected_slots(progress, maxi(day, progress.last_day), Meta.LOGIN_REWARDS.size())
	var next := Daily.advance(progress, day)
	return {
		"slots": slots,
		"reward": 0 if next.is_empty() else _login_reward(next.streak),
		"clock_behind": day < progress.last_day,
	}


func claim_login(day: int) -> int:
	await _save.wait_for_pending_writes()
	var next := Daily.advance(_save.data.meta.login, day)
	if next.is_empty():
		return 0
	var amount := _login_reward(next.streak)
	if amount > MAX_COINS - balance():
		return -1
	var snapshot: Dictionary = _save.data.duplicate(true)
	snapshot.meta.login = next
	snapshot.coins += amount
	return amount if await _commit(snapshot) else -1


func free_coin_ads_remaining(day: int) -> int:
	var claims: Dictionary = _save.data.free_coin_ads
	if day < 0 or day > Daily.MAX_DAY or day < claims.last_day:
		return 0
	return FREE_COIN_LIMIT - claims.count if day == claims.last_day else FREE_COIN_LIMIT


# Called after a rewarded ad closes with a grant. Save the quota and coins together.
func award_free_ad_coins(day: int) -> int:
	await _save.wait_for_pending_writes()
	var remaining := free_coin_ads_remaining(day)
	if remaining == 0:
		return 0
	if FREE_COIN_AMOUNT > MAX_COINS - balance():
		return -1
	var snapshot: Dictionary = _save.data.duplicate(true)
	snapshot.free_coin_ads = {"last_day": day, "count": FREE_COIN_LIMIT - remaining + 1}
	snapshot.coins += FREE_COIN_AMOUNT
	return FREE_COIN_AMOUNT if await _commit(snapshot) else -1


static func _login_reward(streak: int) -> int:
	return Meta.LOGIN_REWARDS[(streak - 1) % Meta.LOGIN_REWARDS.size()]


func has_flawless_badge(level_id: String) -> bool:
	return _save.data.nonogram.get(level_id, {}).get("flawless", false)


func badge_count() -> int:
	var count := 0
	for level_id: String in _save.data.nonogram:
		count += int(has_flawless_badge(level_id))
	return count


# Save the first-clear reward and any new badge in the same transaction.
func award_nonogram(level_id: String, lives: int, combo_lines := 0) -> int:
	await _save.wait_for_pending_writes()
	if level_id.is_empty() or lives < 1 or lives > 3 or combo_lines < 0:
		return -1
	var first_clear := not is_nonogram_cleared(level_id)
	var new_badge := lives == 3 and not has_flawless_badge(level_id)
	if not first_clear and not new_badge:
		return 0
	var amount := mini((15 + 5 * lives) * Combo.multiplier(combo_lines), MAX_FIRST_CLEAR) if first_clear else 0
	var album_bonus := _album_coin_bonus(level_id) if first_clear else 0
	if amount + album_bonus > MAX_COINS - balance():
		return -1
	var snapshot: Dictionary = _save.data.duplicate(true)
	if not levels.is_empty() and level_id == levels[0].id:
		snapshot.onboarding_complete = true
	if first_clear:
		snapshot.nonogram[level_id] = {"reward": amount, "doubled": false}
		_add_xp(snapshot, Meta.CLEAR_XP)
	if new_badge:
		snapshot.nonogram[level_id].flawless = true
		_add_xp(snapshot, Meta.BADGE_XP)
	snapshot.coins += amount + album_bonus
	return amount if await _commit(snapshot) else -1



func _album_coin_bonus(level_id: String) -> int:
	for level in levels:
		if level.id == level_id:
			var coins := Catalog.album_coins(level.planet)
			return coins if coins > 0 and album_collected(level.planet) == Catalog.PICTURES_PER_ALBUM - 1 else 0
	return 0

func next_bonus_index() -> int:
	var index: int = _save.data.bonus_clears
	return index if index < Bonus.unlocked_clears(badge_count()) else -1


func award_bonus(index: int) -> int:
	await _save.wait_for_pending_writes()
	if index < 0 or index != next_bonus_index():
		return -1
	var amount := Bonus.BASE_COINS * Bonus.multiplier(index)
	if amount > MAX_COINS - balance():
		return -1
	var snapshot: Dictionary = _save.data.duplicate(true)
	snapshot.bonus_clears += 1
	_add_xp(snapshot, Meta.BONUS_XP)
	snapshot.coins += amount
	return amount if await _commit(snapshot) else -1


func double_nonogram_reward(level_id: String) -> int:
	await _save.wait_for_pending_writes()
	var progress: Dictionary = _save.data.nonogram
	if not progress.has(level_id) or progress[level_id].doubled:
		return 0
	var amount: int = progress[level_id].reward
	if amount > MAX_COINS - balance():
		return -1
	var snapshot: Dictionary = _save.data.duplicate(true)
	snapshot.nonogram[level_id].doubled = true
	snapshot.coins += amount
	return amount if await _commit(snapshot) else -1


# Positive values are coins collected. Zero is an already recorded date, -1 a failed write.
func award_daily(day: int) -> int:
	await _save.wait_for_pending_writes()
	var progress := Daily.advance(_save.data.daily, day)
	if progress.is_empty():
		return 0
	var amount := Daily.reward(progress.streak)
	if amount > MAX_COINS - balance():
		return -1
	var snapshot: Dictionary = _save.data.duplicate(true)
	snapshot.daily = progress
	_add_xp(snapshot, Meta.CLEAR_XP)
	snapshot.coins += amount
	return amount if await _commit(snapshot) else -1


static func _add_xp(snapshot: Dictionary, amount: int) -> void:
	snapshot.meta.xp = mini(snapshot.meta.xp + amount, Meta.MAX_XP)


func _set_balance(value: int) -> bool:
	var snapshot: Dictionary = _save.data.duplicate(true)
	snapshot.coins = value
	return await _commit(snapshot)


func _commit(snapshot: Dictionary) -> bool:
	var earned: bool = snapshot.coins > balance()
	if await _save.commit(snapshot) != OK:
		return false
	_events.coins_changed.emit(snapshot.coins)
	if earned:
		_events.coins_earned.emit()
	return true
