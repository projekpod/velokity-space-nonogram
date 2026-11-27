extends Node

const Daily := preload("res://scripts/daily/calendar.gd")
const DailyScreen := preload("res://ui/daily_screen.gd")
const Main := preload("res://ui/main.gd")
const MetaScreen := preload("res://ui/meta_screen.gd")
const NonogramScreen := preload("res://ui/nonogram_screen.gd")

var main: Main
var _document: JavaScriptObject
var _elapsed := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_document = JavaScriptBridge.get_interface("document")


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < 0.08 or main._column == null or main._column.get_child_count() == 0:
		return
	_elapsed = 0.0
	var save: Dictionary = main._save.data
	var state := {
		"scene": "navigation", "buttons": {}, "frames": Engine.get_process_frames(),
		"locale": TranslationServer.get_locale(), "paused": get_tree().paused, "muted": AudioServer.is_bus_mute(0),
		"visibleButtons": [],
		"coins": save.coins, "clears": save.nonogram.size(), "bonusClears": save.bonus_clears,
		"dailyClears": save.daily.clears, "owned": save.meta.purchased, "equipped": save.meta.equipped,
		"bottom": _normalized_rect(main._column).end.y,
	}
	var screen := main._column.get_child(0)
	if screen is NonogramScreen:
		state.scene = screen.level.id
		state.state = screen._puzzle.state
		state.result = screen._result.is_visible_in_tree()
		state.lives = screen._puzzle.lives
		state.marks = screen._puzzle._remaining
		state.boardSize = screen._puzzle.size
		state.twistTip = is_instance_valid(screen._twist_tip) and screen._twist_tip.is_visible_in_tree()
		state.holdingBoard = screen._streak._holding
		state.first = screen.first_puzzle
		state.step = screen.tutorial_step
		state.combo = screen._peak_lines
		state.tier = screen._celebration.tier
		state.bonus = screen.bonus_index
		var board_rect: Rect2 = screen._board._grid()
		board_rect.position.y += screen._board._streak_dip
		var grid: Rect2 = screen._board.get_global_transform() * board_rect
		state.grid = _pack_rect(grid)
		if screen._board.supports_zoom():
			var frame: Rect2 = screen._board._grid()
			var content: Rect2 = screen._board._camera.grid(frame, screen._puzzle.size)
			content.position += screen._board._motion_offset()
			state.zoom = _pack_rect(screen._board.get_global_transform() * content)
			state.zoomed = screen._board._camera.edge > 0.0
	elif screen is DailyScreen:
		state.scene = "daily"
		state.state = screen._puzzle.state
		state.lives = screen._puzzle.lives
		state.tier = screen._celebration.tier
		state.dailySolution = Daily.puzzle_for(screen._day).solution
		state.grid = _pack_rect(screen._board.get_global_transform() * screen._board._rect())
	elif screen is MetaScreen:
		state.scene = MetaScreen.Page.keys()[screen.page].to_lower()
		state.preview = screen._preview_id
		state.album = main._economy.album_collected(screen.planet)
	var grid_nodes := main._column.find_children("*", "GridContainer", false, false)
	if not grid_nodes.is_empty():
		for index in range(grid_nodes[0].get_child_count()):
			_add_button(state.buttons, grid_nodes[0].get_child(index), "level%d" % (index + 1))
	for button: Button in main._column.find_children("*", "Button", true, false):
		_add_button(state.buttons, button, button.text)
		if button.is_visible_in_tree():
			state.visibleButtons.append(button.text)
	if is_instance_valid(main._support_button) and main._support_button.is_visible_in_tree():
		_add_button(state.buttons, main._support_button, "MENU_SUPPORT")
		state.visibleButtons.append("MENU_SUPPORT")
	_document.documentElement.setAttribute("data-velokity-playthrough", JSON.stringify(state))


func _add_button(buttons: Dictionary, button: Button, key: String) -> void:
	if button.is_visible_in_tree() and not button.disabled:
		buttons[key] = _pack_rect(_normalized_rect(button), false)


func _normalized_rect(control: Control) -> Rect2:
	var rect := control.get_global_transform() * Rect2(Vector2.ZERO, control.size)
	return Rect2(rect.position / main.size, rect.size / main.size)


func _pack_rect(rect: Rect2, normalize := true) -> Array[float]:
	if normalize:
		rect = Rect2(rect.position / main.size, rect.size / main.size)
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
