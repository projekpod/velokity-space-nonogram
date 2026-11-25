extends Control

const Catalog := preload("res://scripts/nonogram/catalog.gd")
const MissionArt := preload("res://ui/mission_art.gd")
const UI := preload("res://ui/controls.gd")
const DailyScreen := preload("res://ui/daily_screen.gd")
const NonogramScreen := preload("res://ui/nonogram_screen.gd")
const Bonus := preload("res://scripts/nonogram/bonus.gd")

@onready var center: CenterContainer = $Center
@onready var _economy := get_node("/root/Economy")
@onready var _settings := get_node("/root/Settings")
@onready var _ads := get_node("/root/Ads")

var _levels := Catalog.read()
var _column: VBoxContainer


func _ready() -> void:
	if OS.has_feature("web") and OS.has_feature("qa"):
		if load("res://scripts/qa/web_preview.gd").open(self):
			return
	show_menu()


func show_menu() -> void:
	_reset_column()
	_column.add_child(MissionArt.new())
	UI.label(_column, "GAME_NAME", 98, UI.MINT)
	UI.label(_column, "GAME_SUBTITLE", 38)
	UI.label(_column, tr("COIN_BALANCE") % _economy.balance(), 25, UI.GOLD)
	var play := UI.button(_column, "MENU_PLAY", true)
	play.pressed.connect(_show_planets)
	UI.button(_column, "MENU_DAILY").pressed.connect(_open_daily)
	UI.button(_column, "MENU_SETTINGS").pressed.connect(_show_settings)
	play.grab_focus()


func _show_planets() -> void:
	_reset_column()
	UI.button(_column, "GAME_BACK").pressed.connect(show_menu)
	UI.label(_column, "PLANETS_TITLE", 44, UI.MINT)
	var first: Button
	for planet: String in Catalog.PLANETS:
		var indices := _planet_levels(planet)
		var cleared := _planet_cleared(planet)
		var unlocked := _is_planet_unlocked(planet)
		var caption := tr("PLANET_PROGRESS") % [_planet_title(planet), cleared, indices.size()]
		if not unlocked:
			caption = (tr("PLANET_LOCKED") % _planet_title(planet)) + "\n" + _planet_unlock_label(planet)
		var card := UI.button(_column, caption)
		card.disabled = not unlocked or indices.is_empty()
		card.pressed.connect(_show_levels.bind(planet))
		if first == null and not card.disabled:
			first = card
		if not unlocked and cleared > 0:
			UI.button(_column, tr("PLANET_REPLAY") % _planet_title(planet)).pressed.connect(_show_levels.bind(planet))
	for planet: String in ["jupiter", "neptune"]:
		var caption := (tr("PLANET_LOCKED") % _planet_title(planet)) + "\n" + tr("PLANET_FUTURE")
		UI.button(_column, caption).disabled = true
	if _economy.next_bonus_index() >= 0:
		UI.button(_column, "BONUS_TITLE", true).pressed.connect(_open_bonus)
	else:
		UI.label(_column, tr("BONUS_BADGES") % [_economy.badge_count() % Bonus.BADGES_PER_ROUND, Bonus.BADGES_PER_ROUND], 22, UI.MUTED)
	if first != null:
		first.grab_focus()


func _show_levels(planet: String) -> void:
	var planet_unlocked := _is_planet_unlocked(planet)
	if not planet_unlocked and _planet_cleared(planet) == 0:
		return
	_reset_column()
	UI.button(_column, "LEVEL_BACK").pressed.connect(_show_planets)
	UI.label(_column, _planet_title(planet), 44, UI.MINT)
	UI.label(_column, "LEVELS_TITLE", 26, UI.MUTED)
	if not planet_unlocked:
		UI.label(_column, _planet_unlock_label(planet), 21, UI.MUTED)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 9)
	grid.add_theme_constant_override("v_separation", 9)
	_column.add_child(grid)
	var indices := _planet_levels(planet)
	var first_uncleared: Button
	for position in range(indices.size()):
		var index := indices[position]
		var cleared: bool = _economy.is_nonogram_cleared(_levels[index].id)
		var unlocked := _is_level_unlocked(index)
		var number := "%02d" % (position + 1)
		var caption := number
		if cleared:
			caption = tr("LEVEL_CLEARED") % number
		elif not unlocked:
			var requirement := tr("LEVEL_REQUIRES_PREVIOUS") % ("%02d" % position) if planet_unlocked else tr("LEVEL_REQUIRES_PLANET")
			caption = (tr("LEVEL_LOCKED") % number) + "\n" + requirement
		var button := UI.button(grid, caption, cleared)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = UI.level_title(_levels[index])
		button.disabled = not unlocked
		if button.disabled:
			button.add_theme_font_size_override("font_size", 18)
		button.pressed.connect(_play.bind(index))
		if first_uncleared == null and not cleared and unlocked:
			first_uncleared = button
	if first_uncleared != null:
		first_uncleared.grab_focus()
	else:
		for button: Button in grid.get_children():
			if not button.disabled:
				button.grab_focus()
				break


func _planet_levels(planet: String) -> Array[int]:
	var indices: Array[int] = []
	for index in range(_levels.size()):
		if _levels[index].planet == planet:
			indices.append(index)
	return indices


func _planet_title(planet: String) -> String:
	return tr("PLANET_" + planet.to_upper())


func _planet_cleared(planet: String) -> int:
	var count := 0
	for index in _planet_levels(planet):
		count += int(_economy.is_nonogram_cleared(_levels[index].id))
	return count


func _is_planet_unlocked(planet: String) -> bool:
	var previous := Catalog.previous_planet(planet)
	return planet == Catalog.PLANETS[0] or (not previous.is_empty() and _planet_cleared(previous) >= Catalog.PLANET_CLEAR_REQUIREMENT)


func _album_complete(planet: String) -> bool:
	return _planet_cleared(planet) == _planet_levels(planet).size()


func _planet_unlock_label(planet: String) -> String:
	var previous := Catalog.previous_planet(planet)
	return tr("PLANET_REQUIRES_CLEARS") % [Catalog.PLANET_CLEAR_REQUIREMENT, _planet_title(previous)]


func _is_level_unlocked(index: int) -> bool:
	if index < 0 or index >= _levels.size():
		return false
	var level := _levels[index]
	if _economy.is_nonogram_cleared(level.id):
		return true
	if not _is_planet_unlocked(level.planet):
		return false
	return index == 0 or level.planet != _levels[index - 1].planet or _economy.is_nonogram_cleared(_levels[index - 1].id)


func _play(level_index: int) -> NonogramScreen:
	if not _is_level_unlocked(level_index):
		return null
	_reset_column(NonogramScreen.BOARD_WIDTH, 0)
	var screen := NonogramScreen.new()
	screen.level = _levels[level_index]
	screen.can_play_next = _is_level_unlocked.bind(level_index + 1)
	screen.album_complete = _album_complete.bind(screen.level.planet)
	screen.exit_requested.connect(_leave_game.bind(level_index))
	_column.add_child(screen)
	return screen


func _leave_game(action: StringName, result_closed: bool, level_index: int) -> void:
	match action:
		&"bonus":
			_open_bonus()
			return
		&"next":
			if _play(level_index + 1) == null:
				return
		&"retry":
			_play(level_index)
		_:
			_show_levels(_levels[level_index].planet)
	if result_closed:
		_ads.request_interstitial_after_result(level_index + 1)


func _open_bonus() -> NonogramScreen:
	var index: int = _economy.next_bonus_index()
	var level := Bonus.puzzle_for(index)
	if level.is_empty():
		return null
	_reset_column(NonogramScreen.BOARD_WIDTH, 0)
	var screen := NonogramScreen.new()
	screen.level = level
	screen.bonus_index = index
	screen.can_play_next = func() -> bool:
		return Bonus.multiplier(index) < Bonus.STAGES and _economy.next_bonus_index() == index + 1
	screen.exit_requested.connect(_leave_bonus)
	_column.add_child(screen)
	return screen


func _leave_bonus(action: StringName, _result_closed: bool) -> void:
	if action == &"levels" or _open_bonus() == null:
		_show_planets()


func _open_daily() -> DailyScreen:
	_reset_column(608, 0)
	var screen := DailyScreen.new()
	screen.back_requested.connect(show_menu)
	_column.add_child(screen)
	return screen


func _show_settings() -> void:
	_reset_column()
	UI.button(_column, "GAME_BACK").pressed.connect(show_menu)
	UI.label(_column, "MENU_SETTINGS", 44, UI.MINT)
	var status := Label.new()
	for key: String in ["sound", "music", "vibration", "calm_mode"]:
		var toggle := CheckButton.new()
		toggle.text = "SETTING_" + key.to_upper()
		toggle.custom_minimum_size.y = 60
		toggle.add_theme_font_size_override("font_size", 26)
		UI.style_button(toggle, false)
		toggle.button_pressed = _settings.get_value(key)
		toggle.toggled.connect(_change_toggle.bind(key, toggle, status))
		_column.add_child(toggle)
	UI.label(_column, "SETTING_LANGUAGE", 26, UI.MUTED)
	var language := OptionButton.new()
	language.add_theme_font_size_override("font_size", 25)
	language.get_popup().add_theme_font_size_override("font_size", 25)
	language.custom_minimum_size.y = 65
	UI.style_button(language, false)
	var locales := ["", "en", "id"]
	var language_labels := ["LANGUAGE_DEVICE", "LANGUAGE_ENGLISH", "LANGUAGE_INDONESIAN"]
	for key: String in language_labels:
		language.add_item(tr(key))
	language.select(locales.find(_settings.get_value("language")))
	language.item_selected.connect(func(index: int) -> void:
		status.visible = not _settings.set_value("language", locales[index])
		if status.visible:
			language.select(locales.find(_settings.get_value("language")))
		else:
			for item in range(language_labels.size()):
				language.set_item_text(item, tr(language_labels[item]))
	)
	_column.add_child(language)
	status.text = "SAVE_FAILED"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_color_override("font_color", UI.ERROR_COLOR)
	status.hide()
	_column.add_child(status)


func _change_toggle(enabled: bool, key: String, toggle: CheckButton, status: Label) -> void:
	status.visible = not _settings.set_value(key, enabled)
	if status.visible:
		toggle.set_pressed_no_signal(_settings.get_value(key))


func _reset_column(width := 568.0, gap := 14) -> void:
	if is_instance_valid(_column):
		center.remove_child(_column)
		_column.queue_free()
	_column = VBoxContainer.new()
	_column.custom_minimum_size.x = width
	_column.add_theme_constant_override("separation", gap)
	center.add_child(_column)
