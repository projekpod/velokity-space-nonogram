extends VBoxContainer

signal exit_requested(action: StringName, result_closed: bool)

const Puzzle := preload("res://scripts/nonogram/puzzle.gd")
const Board := preload("res://ui/board.gd")
const UI := preload("res://ui/controls.gd")
const EconomyRules := preload("res://scripts/autoload/economy.gd")
const BOARD_WIDTH := Board.WIDTH

@onready var _economy := get_node("/root/Economy")
@onready var _events := get_node("/root/Events")
@onready var _settings := get_node("/root/Settings")
@onready var _analytics := get_node("/root/Analytics")
@onready var _ads := get_node("/root/Ads")

var level: Dictionary
var has_next := false
var _puzzle: Puzzle
var _board: Board
var _lives: Label
var _coins: Label
var _status: Label
var _feedback: Label
var _tools: VBoxContainer
var _result: VBoxContainer
var _fill: Button
var _cross: Button
var _hint: Button
var _continue: Button
var _pending_ad: StringName
var _win_coins := 0
var _bonus_coins := 0
var _bonus_granted := false


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	_puzzle = Puzzle.new(level)
	_analytics.record(&"puzzle_started")

	var header := UI.row(self)
	UI.button(header, "GAME_BACK_LEVELS").pressed.connect(_leave.bind(&"levels"))
	_lives = UI.label(header, "", 25, UI.GOLD)
	_lives.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_coins = UI.label(header, "", 25, UI.GOLD)

	UI.label(self, UI.level_title(level), 42)
	_status = UI.label(self, "GAME_READY", 25, UI.MUTED)
	_board = Board.new()
	_board.puzzle = _puzzle
	add_child(_board)
	_feedback = UI.label(self, "", 23, UI.ERROR_COLOR)
	_feedback.hide()
	_build_tools()
	_result = VBoxContainer.new()
	_result.add_theme_constant_override("separation", 10)
	add_child(_result)
	_result.hide()

	_update_lives()
	_update_balance(_economy.balance())
	_events.coins_changed.connect(_update_balance)
	_ads.rewarded_finished.connect(_on_rewarded_finished)
	_ads.set_gameplay_banner(true)
	_puzzle.mistake.connect(_on_mistake)
	_puzzle.finished.connect(_on_finished)
	_board.grab_focus()


func _exit_tree() -> void:
	_ads.set_gameplay_banner(false)


func _build_tools() -> void:
	_tools = VBoxContainer.new()
	_tools.add_theme_constant_override("separation", 10)
	add_child(_tools)
	UI.label(_tools, "GAME_CONTROLS", 21, UI.MUTED)
	var marks := UI.row(_tools)
	_fill = UI.action(marks, "GAME_FILL", true)
	_cross = UI.action(marks, "GAME_CROSS")
	var modes := ButtonGroup.new()
	for button in [_fill, _cross]:
		button.toggle_mode = true
		button.button_group = modes
	_fill.button_pressed = true
	_fill.pressed.connect(_choose_mark.bind(false))
	_cross.pressed.connect(_choose_mark.bind(true))
	UI.action(marks, "GAME_RETRY").pressed.connect(_leave.bind(&"retry"))
	var hints := UI.row(_tools)
	_hint = UI.action(hints, tr("GAME_HINT_COINS") % EconomyRules.HINT_COST)
	_hint.pressed.connect(_use_paid_hint)
	UI.action(hints, "GAME_HINT_AD").pressed.connect(_request_ad.bind(&"hint"))


func _choose_mark(crossed: bool) -> void:
	_board.cross_mode = crossed
	UI.style_button(_fill, not crossed)
	UI.style_button(_cross, crossed)
	_board.grab_focus()


func _use_paid_hint() -> void:
	var cell := _puzzle.hint_cell()
	if cell.x < 0:
		return
	if _economy.spend(EconomyRules.HINT_COST):
		_apply_hint(cell)
	else:
		_show_feedback("SAVE_FAILED")


func _apply_hint(cell: Vector2i) -> void:
	_board.cancel_drag()
	_feedback.hide()
	_status.text = "GAME_READY"
	_board.grab_focus()
	_puzzle.mark(cell, false)


func _use_paid_continue() -> void:
	if not _puzzle.can_continue():
		return
	if _economy.spend(EconomyRules.CONTINUE_COST):
		_resume_game()
	else:
		_show_feedback("SAVE_FAILED")


func _resume_game() -> void:
	_status.text = "GAME_READY"
	_status.add_theme_color_override("font_color", UI.MUTED)
	_feedback.hide()
	_result.hide()
	_tools.show()
	_ads.set_gameplay_banner(true)
	_puzzle.continue_game()
	_update_lives()
	_board.queue_redraw()
	if _puzzle.state == Puzzle.State.PLAYING:
		_board.grab_focus()


func _request_ad(placement: StringName) -> void:
	if not _ads.request_rewarded(placement):
		_show_feedback("AD_UNAVAILABLE")
		return
	_pending_ad = placement


func _on_rewarded_finished(placement: StringName, granted: bool) -> void:
	if _pending_ad != placement or not is_inside_tree():
		return
	_pending_ad = &""
	if not granted:
		_show_feedback("AD_UNAVAILABLE")
		return
	match placement:
		&"hint":
			var cell := _puzzle.hint_cell()
			if cell.x >= 0:
				_apply_hint(cell)
		&"continue":
			if _puzzle.can_continue():
				_resume_game()
		&"double_coins":
			_bonus_granted = true
			_save_bonus()


func _on_mistake(_cell: Vector2i) -> void:
	_update_lives()
	_status.text = "GAME_MISTAKE"
	_settings.vibrate_for_mistake()


func _on_finished(won: bool) -> void:
	_tools.hide()
	_ads.set_gameplay_banner(false)
	_analytics.record(&"puzzle_won" if won else &"puzzle_lost")
	if won:
		_win_coins = _economy.award_nonogram(level.id, _puzzle.lives)
	_show_result(won)


func _show_result(won: bool) -> void:
	for child in _result.get_children():
		_result.remove_child(child)
		child.queue_free()
	_continue = null
	_feedback.hide()
	_status.text = "GAME_WON" if won else "GAME_LOST"
	_status.add_theme_color_override("font_color", UI.MINT if won else UI.ERROR_COLOR)
	if won:
		_show_win_reward()
	elif _puzzle.can_continue():
		var choices := UI.row(_result)
		_continue = UI.action(choices, tr("GAME_CONTINUE_COINS") % EconomyRules.CONTINUE_COST)
		_continue.disabled = _economy.balance() < EconomyRules.CONTINUE_COST
		_continue.pressed.connect(_use_paid_continue)
		UI.action(choices, "GAME_CONTINUE_AD", _continue.disabled).pressed.connect(_request_ad.bind(&"continue"))
	var nav := UI.row(_result)
	var retry := UI.action(nav, "GAME_RETRY", not won or not has_next)
	retry.pressed.connect(_leave.bind(&"retry"))
	var focus := retry
	if won and has_next:
		focus = UI.action(nav, "GAME_NEXT", true)
		focus.pressed.connect(_leave.bind(&"next"))
	_result.show()
	focus.grab_focus()


func _show_win_reward() -> void:
	if _win_coins < 0:
		_show_feedback("SAVE_FAILED")
		UI.button(_result, "SAVE_RETRY").pressed.connect(_retry_win)
	elif _win_coins == 0:
		UI.label(_result, "GAME_ALREADY_CLEARED", 23, UI.MUTED)
	else:
		UI.label(_result, tr("GAME_EARNED") % (_win_coins + maxi(0, _bonus_coins)), 25, UI.GOLD)
		if _bonus_granted and _bonus_coins < 0:
			_show_feedback("SAVE_FAILED")
			UI.button(_result, "SAVE_RETRY").pressed.connect(_save_bonus)
		elif not _bonus_granted:
			UI.button(_result, "GAME_DOUBLE_AD").pressed.connect(_request_ad.bind(&"double_coins"))


func _retry_win() -> void:
	_win_coins = _economy.award_nonogram(level.id, _puzzle.lives)
	_show_result(true)


func _save_bonus() -> void:
	_bonus_coins = _economy.double_nonogram_reward(level.id)
	_show_result(true)


func _update_lives() -> void:
	_lives.text = tr("GAME_LIVES") % _puzzle.lives


func _show_feedback(key: String) -> void:
	_feedback.text = key
	_feedback.show()


func _update_balance(balance: int) -> void:
	_coins.text = tr("COIN_BALANCE") % balance
	_hint.disabled = balance < EconomyRules.HINT_COST
	if is_instance_valid(_continue):
		_continue.disabled = balance < EconomyRules.CONTINUE_COST


func _leave(action: StringName) -> void:
	exit_requested.emit(action, _puzzle.state != Puzzle.State.PLAYING)
