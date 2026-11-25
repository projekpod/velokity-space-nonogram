extends Control

const Catalog := preload("res://scripts/nonogram/catalog.gd")
const Puzzle := preload("res://scripts/nonogram/puzzle.gd")
const Board := preload("res://ui/board.gd")
const MissionArt := preload("res://ui/mission_art.gd")

const INK := Color("#edf5ff")
const MUTED := Color("#a3b7d4")
const MINT := Color("#93f2e4")
const GOLD := Color("#ffcf82")

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
	_label(_column, "GAME_NAME", 98, MINT)
	_label(_column, "GAME_SUBTITLE", 38)
	_label(_column, "MENU_TAGLINE", 25, MUTED)
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
	var play := _button(_column, "MENU_PLAY", true)
	play.disabled = _levels.is_empty()
	play.pressed.connect(_play)
	_button(_column, "MENU_DAILY").disabled = true
	if not play.disabled:
		play.grab_focus()


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
	_button(header, "GAME_BACK").pressed.connect(show_menu)
	_lives = _label(header, "", 28, GOLD)
	_lives.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_update_lives()

	var title := _label(_column, "", 42)
	title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	title.text = _localized_title(_levels[_level_index])
	_status = _label(_column, "GAME_READY", 24, MUTED)
	_board = Board.new()
	_board.puzzle = _puzzle
	_column.add_child(_board)
	_label(_column, "GAME_CONTROLS", 21, MUTED)

	var marks := HBoxContainer.new()
	marks.add_theme_constant_override("separation", 12)
	_column.add_child(marks)
	_fill = _button(marks, "GAME_FILL", true)
	_cross = _button(marks, "GAME_CROSS")
	var modes := ButtonGroup.new()
	for button in [_fill, _cross]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.button_group = modes
	_fill.button_pressed = true
	_fill.pressed.connect(_choose_mark.bind(false))
	_cross.pressed.connect(_choose_mark.bind(true))
	_hint = _button(marks, "GAME_HINT")
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.pressed.connect(_use_hint)

	var retry := _button(_column, "GAME_RETRY")
	retry.pressed.connect(_play)
	_next = _button(_column, "GAME_NEXT", true)
	_next.pressed.connect(_next_puzzle)
	_next.hide()
	_puzzle.mistake.connect(_on_mistake)
	_puzzle.finished.connect(_on_finished)
	_board.grab_focus()


func _choose_mark(crossed: bool) -> void:
	_board.cross_mode = crossed
	_style_button(_fill, not crossed)
	_style_button(_cross, crossed)
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
	_status.add_theme_color_override("font_color", MINT if won else Color("#ff8f99"))
	analytics.record(&"puzzle_won" if won else &"puzzle_lost")
	_hint.disabled = true
	_fill.disabled = true
	_cross.disabled = true
	if won and _level_index + 1 < _levels.size():
		_next.show()
	elif won:
		_label(_column, "GAME_FINAL", 22, MUTED)


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


func _label(parent: Control, text: String, font_size: int, color := INK) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _picker(parent: Control, caption: String) -> OptionButton:
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(stack)
	_label(stack, caption, 21, MUTED)
	var picker := OptionButton.new()
	picker.add_theme_font_size_override("font_size", 24)
	picker.get_popup().add_theme_font_size_override("font_size", 24)
	picker.fit_to_longest_item = false
	picker.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	picker.custom_minimum_size.y = 60
	stack.add_child(picker)
	return picker


func _button(parent: Control, key: String, primary := false) -> Button:
	var button := Button.new()
	button.text = key
	button.custom_minimum_size = Vector2(124, 65)
	button.add_theme_font_size_override("font_size", 25)
	_style_button(button, primary)
	parent.add_child(button)
	return button


func _style_button(button: Button, primary: bool) -> void:
	var base := MINT if primary else Color("#1c2b45")
	var foreground := Color("#10222d") if primary else INK
	button.add_theme_stylebox_override("normal", _box(base))
	button.add_theme_stylebox_override("hover", _box(base.lightened(0.1)))
	button.add_theme_stylebox_override("pressed", _box(base.darkened(0.08)))
	button.add_theme_stylebox_override("hover_pressed", _box(base.darkened(0.08)))
	button.add_theme_stylebox_override("disabled", _box(Color("#161f33")))
	var outline := _box(Color.TRANSPARENT)
	outline.set_border_width_all(2)
	outline.border_color = GOLD
	button.add_theme_stylebox_override("focus", outline)
	for property in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(property, foreground)
	button.add_theme_color_override("font_disabled_color", MUTED)


func _box(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(13)
	style.content_margin_left = 18
	style.content_margin_right = 18
	return style
