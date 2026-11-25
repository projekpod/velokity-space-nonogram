extends VBoxContainer

signal back_requested

const Daily := preload("res://scripts/daily/calendar.gd")
const Puzzle := preload("res://scripts/daily/puzzle.gd")
const Board := preload("res://ui/daily_board.gd")
const UI := preload("res://ui/controls.gd")

const WEEKDAYS := [&"DAY_MON", &"DAY_TUE", &"DAY_WED", &"DAY_THU", &"DAY_FRI", &"DAY_SAT", &"DAY_SUN"]

@onready var _save := get_node("/root/Save")
@onready var _economy := get_node("/root/Economy")
@onready var _analytics := get_node("/root/Analytics")
@onready var _settings := get_node("/root/Settings")
@onready var _ads := get_node("/root/Ads")

var _day: int
var _date: Dictionary
var _puzzle: Puzzle
var _board: Board
var _lives: Label
var _status: Label
var _streak: Label
var _slots: Array[PanelContainer] = []
var _place: Button
var _note: Button
var _retry: Button


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	_start()


func _exit_tree() -> void:
	_ads.set_gameplay_banner(false)


func _start() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_slots.clear()
	_date = Time.get_date_dict_from_system()
	_day = Daily.day_number(_date)
	var level := Daily.puzzle_for(_day)

	var top := HBoxContainer.new()
	add_child(top)
	UI.button(top, "GAME_BACK").pressed.connect(back_requested.emit)
	_lives = UI.label(top, "", 26, UI.GOLD)
	_lives.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.label(self, "DAILY_TITLE", 43, UI.MINT)
	if level.is_empty():
		UI.label(self, "DAILY_UNAVAILABLE", 24, UI.MUTED)
		return

	_puzzle = Puzzle.new(level)
	_analytics.record(&"puzzle_started")
	_ads.set_gameplay_banner(true)
	_update_lives()
	var day_label := tr(WEEKDAYS[Daily.weekday(_day)])
	var date_label := UI.label(self, "", 22, UI.MUTED)
	date_label.text = tr("DAILY_DATE") % [day_label, _date.day, _date.month, _date.year, level.difficulty]
	_status = UI.label(self, "DAILY_PLAYED" if _save.data.daily.last_day == _day else "DAILY_READY", 24)
	var rules := UI.label(self, "DAILY_RULES", 21, UI.MUTED)
	rules.custom_minimum_size.x = 600
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_board = Board.new()
	_board.puzzle = _puzzle
	add_child(_board)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 12)
	add_child(tools)
	_place = UI.button(tools, "DAILY_PLACE", true)
	_note = UI.button(tools, "DAILY_NOTE")
	var modes := ButtonGroup.new()
	for button in [_place, _note]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.button_group = modes
	_place.button_pressed = true
	_place.pressed.connect(_choose_mode.bind(false))
	_note.pressed.connect(_choose_mode.bind(true))

	_streak = UI.label(self, "", 22, UI.MUTED)
	var calendar := HBoxContainer.new()
	calendar.add_theme_constant_override("separation", 7)
	add_child(calendar)
	for index in range(Daily.REWARDS.size()):
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.custom_minimum_size.y = 60
		calendar.add_child(panel)
		_slots.append(panel)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 0)
		panel.add_child(column)
		UI.label(column, tr("DAILY_REWARD_DAY") % (index + 1), 17, UI.MUTED)
		UI.label(column, "+%d" % Daily.REWARDS[index], 22, UI.GOLD)
	_update_calendar()

	_retry = UI.button(self, "GAME_RETRY")
	_retry.pressed.connect(_start)
	_puzzle.mistake.connect(_on_mistake)
	_puzzle.finished.connect(_on_finished)
	_board.grab_focus()


func _choose_mode(note: bool) -> void:
	_board.note_mode = note
	UI.style_button(_place, not note)
	UI.style_button(_note, note)
	_board.grab_focus()


func _on_mistake(_cell: Vector2i) -> void:
	_update_lives()
	_status.text = "GAME_MISTAKE"
	_settings.vibrate_for_mistake()


func _on_finished(won: bool) -> void:
	_ads.set_gameplay_banner(false)
	_place.disabled = true
	_note.disabled = true
	_analytics.record(&"puzzle_won" if won else &"puzzle_lost")
	_status.add_theme_color_override("font_color", UI.MINT if won else Board.MISTAKE)
	if not won:
		_status.text = "GAME_LOST"
	elif Daily.today() != _day:
		_status.text = "DAILY_ROLLOVER"
		_retry.text = "DAILY_OPEN_TODAY"
	else:
		var coins: int = _economy.award_daily(_day)
		if coins > 0:
			_status.text = tr("DAILY_WON") % coins
			_update_calendar()
		else:
			_status.text = "DAILY_PLAYED" if coins == 0 else "DAILY_SAVE_FAILED"


func _update_lives() -> void:
	_lives.text = tr("GAME_LIVES") % _puzzle.lives


func _update_calendar() -> void:
	var progress: Dictionary = _save.data.daily
	_streak.text = tr("DAILY_STREAK") % Daily.active_streak(progress, _day)
	var filled := Daily.collected_slots(progress, _day)
	for index in range(_slots.size()):
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(8)
		style.bg_color = Color("#274b48") if index < filled else Color("#1c2b45")
		if index == filled and progress.last_day < _day:
			style.set_border_width_all(2)
			style.border_color = UI.GOLD
		_slots[index].add_theme_stylebox_override("panel", style)
