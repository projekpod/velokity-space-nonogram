extends Control

const Catalog := preload("res://scripts/nonogram/catalog.gd")
const Puzzle := preload("res://scripts/nonogram/puzzle.gd")
const Board := preload("res://ui/board.gd")
const MissionArt := preload("res://ui/mission_art.gd")

const UI := preload("res://ui/controls.gd")
const DailyScreen := preload("res://ui/daily_screen.gd")

@onready var center: CenterContainer = $Center
@onready var analytics := get_node("/root/Analytics")

var _levels := Catalog.read()
var _level_index := 0
var _planet_picker: OptionButton
var _level_picker: OptionButton
var _column: VBoxContainer
var _board: Board
var _puzzle: Puzzle
var _lives: Label
var _status: Label
var _hint: Button
var _next: Button
var _fill: Button
var _cross: Button


func _ready() -> void:
	show_menu()


func show_menu() -> void:
	_reset_column(536, 14)
	var art := MissionArt.new()
	_column.add_child(art)
	UI.label(_column, "GAME_NAME", 98, UI.MINT)
	UI.label(_column, "GAME_SUBTITLE", 38)
	UI.label(_column, "MENU_TAGLINE", 25, UI.MUTED)
	var previous_gap := Control.new()
	previous_gap.custom_minimum_size.y = 18
	_column.add_child(previous_gap)
	var pickers := HBoxContainer.new()
	pickers.add_theme_constant_override("separation", 14)
	_column.add_child(pickers)
	_planet_picker = _picker(pickers, "MENU_PLANET")
	_level_picker = _picker(pickers, "MENU_LEVEL")
	for planet in Catalog.PLANETS:
		_planet_picker.add_item(tr("PLANET_" + planet.to_upper()))
	if not _levels.is_empty():
		_planet_picker.select(Catalog.PLANETS.find(_levels[_level_index].planet))
	_select_planet(_planet_picker.selected)
	_planet_picker.item_selected.connect(_select_planet)
	_level_picker.item_selected.connect(_select_level)
	var play := UI.button(_column, "MENU_PLAY", true)
	play.disabled = _levels.is_empty()
	play.pressed.connect(_play)
	UI.button(_column, "MENU_DAILY").pressed.connect(_open_daily)
	if not play.disabled:
		play.grab_focus()


func _open_daily() -> void:
	_reset_column(608, 0)
	var screen := DailyScreen.new()
	screen.back_requested.connect(show_menu)
	_column.add_child(screen)


func _select_planet(index: int) -> void:
	var current := _level_index
	_level_picker.clear()
	if index < 0:
		return
	for level_index in range(_levels.size()):
		if _levels[level_index].planet == Catalog.PLANETS[index]:
			_level_picker.add_item(_localized_title(_levels[level_index]), level_index)
			if level_index == current:
				_level_picker.select(_level_picker.item_count - 1)
	if _level_picker.item_count > 0:
		_select_level(_level_picker.selected)


func _select_level(index: int) -> void:
	_level_index = _level_picker.get_item_id(index)


func _localized_title(level: Dictionary) -> String:
	return level.title.id if TranslationServer.get_locale().get_slice("_", 0) == "id" else level.title.en


func _play() -> void:
	_reset_column(608, 14)
	_puzzle = Puzzle.new(_levels[_level_index])
	analytics.record(&"puzzle_started")

	var header := HBoxContainer.new()
	_column.add_child(header)
	UI.button(header, "GAME_BACK").pressed.connect(show_menu)
	_lives = UI.label(header, "", 28, UI.GOLD)
	_lives.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_update_lives()

	var title := UI.label(_column, "", 42)
	title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	title.text = _localized_title(_levels[_level_index])
	_status = UI.label(_column, "GAME_READY", 24, UI.MUTED)
	_board = Board.new()
	_board.puzzle = _puzzle
	_column.add_child(_board)
	UI.label(_column, "GAME_CONTROLS", 21, UI.MUTED)

	var marks := HBoxContainer.new()
	marks.add_theme_constant_override("separation", 12)
	_column.add_child(marks)
	_fill = UI.button(marks, "GAME_FILL", true)
	_cross = UI.button(marks, "GAME_CROSS")
	var modes := ButtonGroup.new()
	for button in [_fill, _cross]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.button_group = modes
	_fill.button_pressed = true
	_fill.pressed.connect(_choose_mark.bind(false))
	_cross.pressed.connect(_choose_mark.bind(true))
	_hint = UI.button(marks, "GAME_HINT")
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.pressed.connect(_use_hint)

	var retry := UI.button(_column, "GAME_RETRY")
	retry.pressed.connect(_play)
	_next = UI.button(_column, "GAME_NEXT", true)
	_next.pressed.connect(_next_puzzle)
	_next.hide()
	_puzzle.mistake.connect(_on_mistake)
	_puzzle.finished.connect(_on_finished)
	_board.grab_focus()


func _choose_mark(crossed: bool) -> void:
	_board.cross_mode = crossed
	UI.style_button(_fill, not crossed)
	UI.style_button(_cross, crossed)
	_board.grab_focus()


func _use_hint() -> void:
	if _puzzle.hint() and _puzzle.state == Puzzle.State.PLAYING:
		_status.text = "GAME_READY"
	_board.grab_focus()


func _on_mistake(_cell: Vector2i) -> void:
	_update_lives()
	_status.text = "GAME_MISTAKE"


func _on_finished(won: bool) -> void:
	_status.text = "GAME_WON" if won else "GAME_LOST"
	_status.add_theme_color_override("font_color", UI.MINT if won else Color("#ff8f99"))
	analytics.record(&"puzzle_won" if won else &"puzzle_lost")
	_hint.disabled = true
	_fill.disabled = true
	_cross.disabled = true
	if won and _level_index + 1 < _levels.size():
		_next.show()
	elif won:
		UI.label(_column, "GAME_FINAL", 22, UI.MUTED)


func _next_puzzle() -> void:
	_level_index += 1
	_play()


func _update_lives() -> void:
	_lives.text = tr("GAME_LIVES") % _puzzle.lives


func _reset_column(width: float, gap: int) -> void:
	if is_instance_valid(_column):
		center.remove_child(_column)
		_column.queue_free()
	_column = VBoxContainer.new()
	_column.custom_minimum_size.x = width
	_column.add_theme_constant_override("separation", gap)
	center.add_child(_column)


func _picker(parent: Control, caption: String) -> OptionButton:
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(stack)
	UI.label(stack, caption, 21, UI.MUTED)
	var picker := OptionButton.new()
	picker.add_theme_font_size_override("font_size", 24)
	picker.get_popup().add_theme_font_size_override("font_size", 24)
	picker.fit_to_longest_item = false
	picker.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	picker.custom_minimum_size.y = 60
	stack.add_child(picker)
	return picker
