extends VBoxContainer

signal exit_requested(action: StringName, result_closed: bool)

const Puzzle := preload("res://scripts/nonogram/puzzle.gd")
const StreakEffect := preload("res://ui/streak_effect.gd")
const Board := preload("res://ui/board.gd")
const UI := preload("res://ui/controls.gd")
const EconomyRules := preload("res://scripts/autoload/economy.gd")
const Portrait := preload("res://ui/mission_art.gd")
const Mascot := preload("res://ui/mascot.gd")
const Celebration := preload("res://ui/celebration.gd")
const Combo := preload("res://scripts/nonogram/combo.gd")
const Bonus := preload("res://scripts/nonogram/bonus.gd")
const TwistTip := preload("res://ui/twist_tip.gd")
const BOARD_WIDTH := Board.WIDTH
const TUTORIAL_STEPS := ["TUTORIAL_FILL", "TUTORIAL_CROSS", "TUTORIAL_CLUES"]

@onready var _economy := get_node("/root/Economy")
@onready var _events := get_node("/root/Events")
@onready var _settings := get_node("/root/Settings")
@onready var _analytics := get_node("/root/Analytics")
@onready var _audio := get_node("/root/Audio")
@onready var _ads := get_node("/root/Ads")
@onready var _save := get_node("/root/Save")

var level: Dictionary
var can_play_next: Callable
var album_complete: Callable
var bonus_index := -1
var first_puzzle := false
var tutorial_step := 0
var _tutorial: VBoxContainer
var _tutorial_text: Label
var _tutorial_next: Button
var _intro: HBoxContainer
var _twist_tip: VBoxContainer
var _twist_label: Label
var _played_msec := 0
var _clock_started_msec := -1
var _clock_seconds := -1
var _puzzle: Puzzle
var _board: Board
var _lives: Label
var _coins: Label
var _status: Label
var _feedback: Label
var _tools: VBoxContainer
var _result: VBoxContainer
var _portrait: Portrait
var _celebration: Celebration
var _streak: StreakEffect
var _queued_combo_lines := 0
var _correct_lines := 0
var _peak_lines := 0
var _combo_theme := -1
var _new_badge := false
var _fill: Button
var _cross: Button
var _hint: Button
var _continue: Button
var _pending_ad: StringName
var _win_coins := 0
var _bonus_coins := 0
var _bonus_granted := false
var _saving := false


func _ready() -> void:
	set_process(false)
	add_theme_constant_override("separation", 10)
	_puzzle = Puzzle.new(level)
	_analytics.record(&"puzzle_started")

	var header := UI.row(self)
	if not first_puzzle:
		UI.button(header, "LEVEL_BACK" if bonus_index >= 0 else "GAME_BACK_LEVELS").pressed.connect(_leave.bind(&"levels"))
	_lives = UI.label(header, "", 25, UI.GOLD)
	_lives.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_coins = UI.label(header, "", 25, UI.GOLD)

	_intro = UI.row(self)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	_intro.add_child(text)
	UI.label(text, "BONUS_TITLE" if bonus_index >= 0 else UI.level_title(level), 42)
	if bonus_index >= 0:
		var stage := Bonus.multiplier(bonus_index)
		UI.label(text, tr("BONUS_STAGE") % [stage, Bonus.STAGES, stage], 24, UI.GOLD)
	_status = UI.label(text, "GAME_READY", 23, UI.MUTED)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not _puzzle.twist_kind.is_empty():
		var key := TwistTip.title_key(_puzzle.twist_kind)
		_twist_label = UI.label(text, key, 20, TwistTip.COLORS[_puzzle.twist_kind])
	_portrait = Portrait.new()
	_portrait.compact = true
	_portrait.idle_expression = Mascot.Face.THINKING
	_intro.add_child(_portrait)
	if first_puzzle and tutorial_step < TUTORIAL_STEPS.size():
		_build_tutorial()
	_board = Board.new()
	_board.puzzle = _puzzle
	add_child(_board)
	var hold_space := Control.new()
	hold_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hold_space.custom_minimum_size.y = 99.0
	hold_space.hide()
	add_child(hold_space)
	_streak = StreakEffect.new()
	add_child(_streak)
	move_child(_streak, 0)
	_streak.attach(_board, _portrait, hold_space)
	_feedback = UI.label(self, "", 23, UI.ERROR_COLOR)
	_feedback.hide()
	_build_tools()
	_result = VBoxContainer.new()
	_result.add_theme_constant_override("separation", 10)
	add_child(_result)
	_result.hide()
	_celebration = Celebration.new()
	_celebration.attach(self)

	_update_lives()
	_update_balance(_economy.balance())
	_events.coins_changed.connect(_update_balance)
	_ads.rewarded_finished.connect(_on_rewarded_finished)
	_puzzle.correct_fill.connect(_on_correct_fill)
	_puzzle.correct_cross.connect(_audio.play_effect.bind(&"cross"))
	_puzzle.mistake.connect(_on_mistake)
	_puzzle.finished.connect(_on_finished)
	if _puzzle.twist_kind.is_empty() or _save.data.twist_tips.has(_puzzle.twist_kind):
		_start_board()
	else:
		_show_twist_tip()


func _exit_tree() -> void:
	_ads.set_gameplay_active(false)


func _show_twist_tip() -> void:
	_intro.hide()
	_board.hide()
	_tools.hide()
	_twist_tip = VBoxContainer.new()
	_twist_tip.add_theme_constant_override("separation", 14)
	add_child(_twist_tip)
	_twist_tip.add_child(TwistTip.card(_puzzle.twist_kind, _puzzle.target_seconds))
	var begin := UI.button(_twist_tip, "TWIST_START", true)
	begin.pressed.connect(_dismiss_twist_tip)
	begin.grab_focus()


func _dismiss_twist_tip() -> void:
	if _saving or not is_instance_valid(_twist_tip):
		return
	_saving = true
	var saved: bool = await _save.mark_twist_seen(_puzzle.twist_kind)
	_saving = false
	_twist_tip.hide()
	_twist_tip.queue_free()
	_twist_tip = null
	_start_board()
	if not saved:
		_show_feedback("SAVE_FAILED")


func _start_board() -> void:
	_intro.show()
	_board.show()
	_tools.show()
	_ads.set_gameplay_active(true, bonus_index < 0 and not first_puzzle)
	_board.grab_focus()
	_start_clock()


func _notification(what: int) -> void:
	if not is_node_ready():
		return
	if what == NOTIFICATION_PAUSED:
		_stop_clock()
	elif what == NOTIFICATION_UNPAUSED:
		_start_clock()


func _start_clock() -> void:
	if _puzzle.target_seconds <= 0 or not _board.visible or _saving or get_tree().paused:
		return
	if _clock_started_msec >= 0 or _puzzle.state != Puzzle.State.PLAYING:
		return
	_clock_started_msec = Time.get_ticks_msec()
	set_process(true)
	_update_clock()


func _stop_clock() -> void:
	if _clock_started_msec >= 0:
		_played_msec += Time.get_ticks_msec() - _clock_started_msec
		_clock_started_msec = -1
		set_process(false)


func _elapsed_seconds() -> float:
	var active_msec := Time.get_ticks_msec() - _clock_started_msec if _clock_started_msec >= 0 else 0
	return (_played_msec + active_msec) / 1000.0


func _process(_delta: float) -> void:
	_update_clock()


func _update_clock() -> void:
	var remaining := maxi(0, ceili(_puzzle.target_seconds - _elapsed_seconds()))
	if remaining == _clock_seconds:
		return
	_clock_seconds = remaining
	_twist_label.text = tr("TWIST_COMET_CLOCK") % remaining if remaining > 0 else "TWIST_COMET_EXPIRED"


func _build_tutorial() -> void:
	_tutorial = VBoxContainer.new()
	add_child(_tutorial)
	_tutorial_text = UI.label(_tutorial, "", 23, UI.MINT)
	_tutorial_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var actions := UI.row(_tutorial)
	UI.action(actions, "TUTORIAL_SKIP").pressed.connect(_show_tutorial_step.bind(TUTORIAL_STEPS.size()))
	_tutorial_next = UI.action(actions, "TUTORIAL_NEXT", true)
	_tutorial_next.pressed.connect(func() -> void: _show_tutorial_step(tutorial_step + 1))
	_show_tutorial_step(tutorial_step)


func _show_tutorial_step(step: int) -> void:
	tutorial_step = step
	if step >= TUTORIAL_STEPS.size():
		_tutorial.hide()
		_board.grab_focus()
		return
	_tutorial_text.text = tr("TUTORIAL_STEP") % [step + 1, tr(TUTORIAL_STEPS[step])]
	_tutorial_next.text = "TUTORIAL_DONE" if step == TUTORIAL_STEPS.size() - 1 else "TUTORIAL_NEXT"


func _build_tools() -> void:
	_tools = VBoxContainer.new()
	_tools.add_theme_constant_override("separation", 10)
	add_child(_tools)
	UI.label(_tools, "GAME_ZOOM_CONTROLS" if _board.supports_zoom() else "GAME_CONTROLS", 21, UI.MUTED)
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
	if _board.supports_zoom():
		UI.action(marks, "GAME_BOARD_FIT").pressed.connect(_board.fit_zoom)
	if bonus_index >= 0:
		return
	var hints := UI.row(_tools)
	_hint = UI.action(hints, tr("GAME_HINT_COINS") % EconomyRules.HINT_COST)
	_hint.pressed.connect(_use_paid_hint)
	if _ads.supports_rewarded():
		UI.action(hints, "GAME_HINT_AD").pressed.connect(_request_ad.bind(&"hint"))


func _choose_mark(crossed: bool) -> void:
	_board.cross_mode = crossed
	UI.style_button(_fill, not crossed)
	UI.style_button(_cross, crossed)
	_board.grab_focus()


func _use_paid_hint() -> void:
	var cell := _puzzle.hint_cell()
	if cell.x < 0 or _saving:
		return
	_saving = true
	_stop_clock()
	_board.cancel_drag()
	_board.process_mode = Node.PROCESS_MODE_DISABLED
	var paid: bool = await _economy.spend(EconomyRules.HINT_COST)
	_board.process_mode = Node.PROCESS_MODE_INHERIT
	_saving = false
	_start_clock()
	if paid:
		_apply_hint(cell)
	else:
		_show_feedback("SAVE_FAILED")


func _apply_hint(cell: Vector2i) -> void:
	_board.cancel_drag()
	_feedback.hide()
	_status.text = "GAME_READY"
	_board.grab_focus()
	_puzzle.apply_hint(cell)


func _use_paid_continue() -> void:
	if _saving or not _puzzle.can_continue():
		return
	_saving = true
	var paid: bool = await _economy.spend(EconomyRules.CONTINUE_COST)
	_saving = false
	if paid:
		_resume_game()
	else:
		_show_feedback("SAVE_FAILED")


func _resume_game() -> void:
	_status.text = "GAME_READY"
	_status.add_theme_color_override("font_color", UI.MUTED)
	_feedback.hide()
	_result.hide()
	_tools.show()
	_ads.request_interstitial_after_result(0)
	if is_instance_valid(_tutorial) and tutorial_step < TUTORIAL_STEPS.size():
		_tutorial.show()
	_ads.set_gameplay_active(true, bonus_index < 0 and not first_puzzle)
	_portrait.mascot.set_idle(Mascot.Face.THINKING)
	_puzzle.continue_game()
	_start_clock()
	_update_lives()
	_board.queue_redraw()
	if _puzzle.state == Puzzle.State.PLAYING:
		_board.grab_focus()


func _request_ad(placement: StringName) -> void:
	if _saving:
		return
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
	_audio.play_effect(&"mistake")
	_correct_lines = 0
	_queued_combo_lines = 0
	_streak.mistake()
	_combo_theme = -1
	_celebration.dismiss()
	_portrait.mascot.react(Mascot.Reaction.MISTAKE)
	_update_lives()
	if _puzzle.shield_used and _puzzle.lives == Puzzle.MAX_LIVES:
		_status.text = "TWIST_SHIELD_USED"
		_twist_label.text = "TWIST_SHIELD_SPENT"
	else:
		_status.text = "GAME_MISTAKE"
	_settings.vibrate_for_mistake()


func _on_correct_fill(cell: Vector2i, completed_lines: int) -> void:
	if _puzzle.has_collected_star(cell):
		_twist_label.text = "TWIST_STAR_FOUND"
	_streak.fill()
	var previous_multiplier := Combo.multiplier(_correct_lines)
	_correct_lines += completed_lines
	_peak_lines = maxi(_peak_lines, _correct_lines)
	var multiplier := Combo.multiplier(_correct_lines)
	if bonus_index < 0 and multiplier > previous_multiplier:
		if _streak.last_effect_frame == Engine.get_process_frames():
			_queued_combo_lines = _correct_lines
			_streak.last_combo_frame = Engine.get_process_frames() + 1
			_play_queued_combo()
		else:
			_play_combo(_correct_lines)
	else:
		_audio.play_effect(&"line" if completed_lines > 0 else &"fill")
		_portrait.mascot.react(Mascot.Reaction.FILL)


func _play_queued_combo() -> void:
	await get_tree().process_frame
	if _queued_combo_lines > 0:
		var lines := _queued_combo_lines
		_queued_combo_lines = 0
		_play_combo(lines)


func _play_combo(lines: int) -> void:
	_streak.last_combo_frame = Engine.get_process_frames()
	if _combo_theme < 0:
		_combo_theme = randi_range(0, Combo.theme_count(_economy.player_level()) - 1)
	_celebration.play_combo(_combo_theme, lines)
	_portrait.mascot.react(Mascot.Reaction.COMBO)


func _on_finished(won: bool) -> void:
	_stop_clock()
	if is_instance_valid(_tutorial):
		_tutorial.hide()
	_tools.hide()
	_ads.set_gameplay_active(false)
	_analytics.record(&"puzzle_won" if won else &"puzzle_lost")
	if won:
		_queued_combo_lines = 0
		if _streak.peak >= StreakEffect.FIRST_CRACK:
			_saving = true
			await _streak.finish()
			_saving = false
		_audio.play_effect(&"win")
		_portrait.mascot.set_idle(Mascot.Face.PROUD)
		_portrait.mascot.react(Mascot.Reaction.WIN)
		_record_win()
	else:
		_portrait.mascot.idle_expression = Mascot.Face.SAD
		_show_result(false)


func _record_win() -> void:
	if _saving:
		return
	_saving = true
	var previous_level: int = _economy.player_level()
	if bonus_index >= 0:
		_win_coins = await _economy.award_bonus(bonus_index)
		_saving = false
		_show_result(true)
		if _win_coins > 0:
			var player_level: int = _economy.player_level()
			if Bonus.multiplier(bonus_index) == Bonus.STAGES:
				_celebration.play(4, "CELEBRATION_BONUS", tr("BONUS_TOTAL") % Bonus.ROUND_COINS)
			elif player_level > previous_level:
				_celebration.play(4, tr("CELEBRATION_LEVEL") % player_level)
		return

	var had_badge: bool = _economy.has_flawless_badge(level.id)
	var was_album_complete := album_complete.is_valid() and bool(album_complete.call())
	var earned := _puzzle.earned_twist_bonus(_elapsed_seconds())
	_win_coins = await _economy.award_nonogram(
		level.id, _puzzle.lives, _peak_lines, _puzzle.twist_kind, earned, _puzzle.made_mistake
	)
	_saving = false
	_new_badge = not had_badge and _economy.has_flawless_badge(level.id)
	_show_result(true)
	if _win_coins < 0:
		return

	var round_unlocked: bool = _new_badge and _economy.badge_count() % Bonus.BADGES_PER_ROUND == 0
	var detail := tr("BONUS_UNLOCKED") if round_unlocked else ""
	var player_level: int = _economy.player_level()
	if album_complete.is_valid() and not was_album_complete and album_complete.call():
		if detail.is_empty():
			detail = tr("ALBUM_REWARD") % _economy.album_reward_title(level.planet)
		_celebration.play(4, "CELEBRATION_ALBUM", detail)
	elif player_level > previous_level:
		_celebration.play(4, tr("CELEBRATION_LEVEL") % player_level, detail)
	elif _puzzle.lives == Puzzle.MAX_LIVES and not _puzzle.made_mistake:
		_celebration.play(3, "CELEBRATION_FLAWLESS", detail)


func _show_result(won: bool) -> void:
	for child in _result.get_children():
		_result.remove_child(child)
		child.queue_free()
	_continue = null
	_feedback.hide()
	_status.text = "GAME_WON" if won else "GAME_LOST"
	if won and bonus_index >= 0 and _win_coins > 0 and Bonus.multiplier(bonus_index) == Bonus.STAGES:
		_status.text = "CELEBRATION_BONUS"
	_status.add_theme_color_override("font_color", UI.MINT if won else UI.ERROR_COLOR)
	if won:
		_show_win_reward()
	elif bonus_index < 0 and _puzzle.can_continue():
		var choices := UI.row(_result)
		_continue = UI.action(choices, tr("GAME_CONTINUE_COINS") % EconomyRules.CONTINUE_COST)
		_continue.disabled = _economy.balance() < EconomyRules.CONTINUE_COST
		_continue.pressed.connect(_use_paid_continue)
		if _ads.supports_rewarded():
			UI.action(choices, "GAME_CONTINUE_AD", _continue.disabled).pressed.connect(_request_ad.bind(&"continue"))
	var nav := UI.row(_result)
	var show_next := won and can_play_next.is_valid() and bool(can_play_next.call())
	var focus: Button
	if won and first_puzzle:
		if _win_coins >= 0:
			focus = UI.action(nav, "GAME_BACK", true)
			focus.pressed.connect(_leave.bind(&"menu"))
	elif won and bonus_index >= 0:
		focus = UI.action(nav, "LEVEL_BACK", not show_next)
		focus.pressed.connect(_leave.bind(&"levels"))
	else:
		focus = UI.action(nav, "GAME_RETRY", not show_next)
		focus.pressed.connect(_leave.bind(&"retry"))
	if show_next and not first_puzzle:
		focus = UI.action(nav, "GAME_NEXT", true)
		focus.pressed.connect(_leave.bind(&"next"))
	if won and not first_puzzle and bonus_index < 0 and _economy.next_bonus_index() >= 0:
		UI.button(_result, "BONUS_TITLE", true).pressed.connect(_leave.bind(&"bonus"))
	_result.show()
	if focus != null:
		focus.grab_focus()


func _show_win_reward() -> void:
	if _win_coins < 0:
		_show_feedback("SAVE_FAILED")
		UI.button(_result, "SAVE_RETRY").pressed.connect(_retry_win)
	elif bonus_index >= 0:
		UI.label(_result, tr("GAME_EARNED") % _win_coins, 25, UI.GOLD)
	elif _win_coins == 0:
		UI.label(_result, "GAME_ALREADY_CLEARED", 23, UI.MUTED)
	else:
		UI.label(_result, tr("GAME_EARNED") % (_win_coins + maxi(0, _bonus_coins)), 25, UI.GOLD)
		var twist_coins := _win_coins - EconomyRules.nonogram_reward(_puzzle.lives, _peak_lines, _puzzle.twist_kind)
		if twist_coins > 0:
			UI.label(_result, tr("TWIST_EXTRA_COINS") % twist_coins, 21, UI.MINT)
		if _bonus_granted and _bonus_coins < 0:
			_show_feedback("SAVE_FAILED")
			UI.button(_result, "SAVE_RETRY").pressed.connect(_save_bonus)
		elif not _bonus_granted and _ads.supports_rewarded():
			UI.button(_result, "GAME_DOUBLE_AD").pressed.connect(_request_ad.bind(&"double_coins"))
	if _new_badge:
		UI.label(_result, "BADGE_EARNED", 23, UI.MINT)


func _retry_win() -> void:
	_record_win()


func _save_bonus() -> void:
	if _saving:
		return
	_saving = true
	_bonus_coins = await _economy.double_nonogram_reward(level.id)
	_saving = false
	_show_result(true)


func _update_lives() -> void:
	_lives.text = tr("GAME_LIVES") % _puzzle.lives


func _show_feedback(key: String) -> void:
	_feedback.text = key
	_feedback.show()


func _update_balance(balance: int) -> void:
	_coins.text = tr("COIN_BALANCE") % balance
	if _hint != null:
		_hint.disabled = balance < EconomyRules.HINT_COST
	if is_instance_valid(_continue):
		_continue.disabled = balance < EconomyRules.CONTINUE_COST


func _leave(action: StringName) -> void:
	if _saving:
		return
	exit_requested.emit(action, _result.visible and _puzzle.state != Puzzle.State.PLAYING)
