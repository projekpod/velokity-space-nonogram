extends VBoxContainer

signal back_requested(result_closed: bool)

const Daily := preload("res://scripts/daily/calendar.gd")
const Puzzle := preload("res://scripts/daily/puzzle.gd")
const Board := preload("res://ui/daily_board.gd")
const UI := preload("res://ui/controls.gd")
const Portrait := preload("res://ui/mission_art.gd")
const Mascot := preload("res://ui/mascot.gd")
const Celebration := preload("res://ui/celebration.gd")

const WEEKDAYS := [&"DAY_MON", &"DAY_TUE", &"DAY_WED", &"DAY_THU", &"DAY_FRI", &"DAY_SAT", &"DAY_SUN"]

@onready var _save := get_node("/root/Save")
@onready var _economy := get_node("/root/Economy")
@onready var _analytics := get_node("/root/Analytics")
@onready var _settings := get_node("/root/Settings")
@onready var _audio := get_node("/root/Audio")
@onready var _ads := get_node("/root/Ads")

var _day: int
var _date: Dictionary
var _puzzle: Puzzle
var _board: Board
var _lives: Label
var _status: Label
var _portrait: Portrait
var _celebration: Celebration
var _streak: Label
var _slots: Array[PanelContainer] = []
var _place: Button
var _note: Button
var _retry: Button
var _saving := false


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	_start()


func _exit_tree() -> void:
	_ads.set_gameplay_active(false)


func _start() -> void:
	_ads.set_gameplay_active(false)
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_slots.clear()
	_date = Time.get_date_dict_from_system()
	_day = Daily.day_number(_date)
	var level := Daily.puzzle_for(_day)

	var top := HBoxContainer.new()
	add_child(top)
	UI.button(top, "GAME_BACK").pressed.connect(_go_back)
	_lives = UI.label(top, "", 26, UI.GOLD)
	_lives.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var intro := UI.row(self)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	intro.add_child(text)
	UI.label(text, "DAILY_TITLE", 43, UI.MINT)
	_portrait = Portrait.new()
	_portrait.compact = true
	_portrait.idle_expression = Mascot.Face.THINKING
	intro.add_child(_portrait)
	if level.is_empty():
		UI.label(self, "DAILY_UNAVAILABLE", 24, UI.MUTED)
		return

	_puzzle = Puzzle.new(level)
	_analytics.record(&"puzzle_started")
	_ads.set_gameplay_active(true)
	_update_lives()
	var day_label := tr(WEEKDAYS[Daily.weekday(_day)])
	var date_label := UI.label(text, "", 22, UI.MUTED)
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
	_retry.pressed.connect(_retry_daily)
	_celebration = Celebration.new()
	_celebration.attach(self)
	_puzzle.mistake.connect(_on_mistake)
	_puzzle.star_placed.connect(_on_star_placed)
	_puzzle.note_changed.connect(_audio.play_effect.bind(&"cross"))
	_puzzle.finished.connect(_on_finished)
	_board.grab_focus()


func _go_back() -> void:
	if not _saving:
		back_requested.emit(_has_result())


func _has_result() -> bool:
	return _puzzle != null and _puzzle.state != Puzzle.State.PLAYING


func _retry_daily() -> void:
	if _saving:
		return
	if _has_result():
		_ads.request_interstitial_after_result(0)
	_start()


func _choose_mode(note: bool) -> void:
	_board.note_mode = note
	UI.style_button(_place, not note)
	UI.style_button(_note, note)
	_board.grab_focus()


func _on_mistake(_cell: Vector2i) -> void:
	_audio.play_effect(&"mistake")
	_portrait.mascot.react(Mascot.Reaction.MISTAKE)
	_update_lives()
	_status.text = "GAME_MISTAKE"
	_settings.vibrate_for_mistake()


func _on_star_placed(_cell: Vector2i) -> void:
	_audio.play_effect(&"fill")
	_portrait.mascot.react(Mascot.Reaction.FILL)


func _on_finished(won: bool) -> void:
	_ads.set_gameplay_active(false)
	_place.disabled = true
	_note.disabled = true
	_analytics.record(&"puzzle_won" if won else &"puzzle_lost")
	_status.add_theme_color_override("font_color", UI.MINT if won else Board.MISTAKE)
	if not won:
		_portrait.mascot.idle_expression = Mascot.Face.SAD
		_status.text = "GAME_LOST"
		return
	_audio.play_effect(&"win")
	_portrait.mascot.set_idle(Mascot.Face.PROUD)
	_portrait.mascot.react(Mascot.Reaction.WIN)
	var previous_level: int = _economy.player_level()
	if Daily.today() != _day:
		_status.text = "DAILY_ROLLOVER"
		_retry.text = "DAILY_OPEN_TODAY"
	else:
		_saving = true
		var coins: int = await _economy.award_daily(_day)
		_saving = false
		if coins > 0:
			_status.text = tr("DAILY_WON") % coins
			_update_calendar()
			var player_level: int = _economy.player_level()
			if _save.data.daily.streak % Daily.REWARDS.size() == 0:
				var detail := tr("CELEBRATION_LEVEL") % player_level if player_level > previous_level else ""
				_celebration.play(4, "CELEBRATION_STREAK", detail)
				return
			if player_level > previous_level:
				_celebration.play(4, tr("CELEBRATION_LEVEL") % player_level)
				return
		else:
			_status.text = "DAILY_PLAYED" if coins == 0 else "DAILY_SAVE_FAILED"
	if _puzzle.lives == Puzzle.MAX_LIVES:
		_celebration.play(3, "CELEBRATION_FLAWLESS")


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
