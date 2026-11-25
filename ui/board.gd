extends Control

const Puzzle := preload("res://scripts/nonogram/puzzle.gd")
const OUTSIDE := Vector2i(-1, -1)
const EMPTY_COLOR := Color("#263851")
const CLUE_COLOR := Color("#d6e4fa")
const DONE_COLOR := Color("#79dccc")
const MARK_COLOR := Color("#8ee8db")

var puzzle: Puzzle
var cross_mode := false
var _anchor := OUTSIDE
var _last := OUTSIDE
var _axis := Vector2i.ZERO
var _drag_cross := false
var _drag_cells: Dictionary = {}
var _cursor := OUTSIDE
var _mistake := OUTSIDE


func _ready() -> void:
	custom_minimum_size = Vector2(608, 618)
	focus_mode = Control.FOCUS_ALL
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	mouse_exited.connect(cancel_drag)
	get_window().focus_exited.connect(cancel_drag)
	puzzle.cell_changed.connect(_redraw_cell)
	puzzle.line_completed.connect(_redraw_line)
	puzzle.mistake.connect(_show_mistake)
	puzzle.finished.connect(_redraw_result)


func _grid() -> Rect2:
	var edge := minf(size.x, size.y) - 172.0
	return Rect2(size.x - edge - 12.0, size.y - edge - 12.0, edge, edge)


func _gui_input(event: InputEvent) -> void:
	if puzzle.state != Puzzle.State.PLAYING:
		return
	if event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		if not event.pressed:
			cancel_drag()
			return
		var cell := cell_at(event.position)
		if cell == OUTSIDE:
			return
		grab_focus()
		_cursor = cell
		_anchor = cell
		_last = cell
		_drag_cross = cross_mode
		_drag_cells[cell] = true
		puzzle.mark(cell, _drag_cross)
		queue_redraw()
		accept_event()
	elif event is InputEventMouseMotion and _anchor != OUTSIDE:
		if not event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			cancel_drag()
			return
		drag_to(cell_at(event.position))
		accept_event()
	elif event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event)


func _handle_key(event: InputEventKey) -> void:
	var direction := Input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down")
	if direction != Vector2.ZERO:
		var limit := Vector2i.ONE * (puzzle.size - 1)
		_cursor = (_cursor + Vector2i(direction.round())).clamp(Vector2i.ZERO, limit)
		queue_redraw()
		accept_event()
	elif event.is_action_pressed(&"ui_accept"):
		if _cursor == OUTSIDE:
			_cursor = Vector2i.ZERO
		puzzle.mark(_cursor, cross_mode)
		accept_event()


func cell_at(position_in_board: Vector2) -> Vector2i:
	var grid := _grid()
	if not grid.has_point(position_in_board):
		return OUTSIDE
	return Vector2i(((position_in_board - grid.position) / grid.size * puzzle.size).floor())


func drag_to(cell: Vector2i) -> void:
	if _anchor == OUTSIDE or cell == OUTSIDE or cell == _last:
		return
	if _axis == Vector2i.ZERO:
		var delta := cell - _anchor
		_axis = Vector2i.RIGHT if absi(delta.x) >= absi(delta.y) else Vector2i.DOWN
	var target := Vector2i(cell.x, _anchor.y) if _axis.x else Vector2i(_anchor.x, cell.y)
	var step := (target - _last).sign()
	if step == Vector2i.ZERO:
		return
	# Ignore cells already traversed in this stroke, even after reversing direction.
	while _last != target:
		_last += step
		if _last in _drag_cells:
			continue
		_drag_cells[_last] = true
		puzzle.mark(_last, _drag_cross)
		if puzzle.state != Puzzle.State.PLAYING:
			cancel_drag()
			break


func cancel_drag() -> void:
	_drag_cells.clear()
	_anchor = OUTSIDE
	_last = OUTSIDE
	_axis = Vector2i.ZERO


func _redraw_cell(_cell: Vector2i) -> void:
	_mistake = OUTSIDE
	queue_redraw()


func _redraw_line(_is_row: bool, _index: int) -> void:
	queue_redraw()


func _redraw_result(_won: bool) -> void:
	queue_redraw()


func _show_mistake(cell: Vector2i) -> void:
	_mistake = cell
	queue_redraw()


func _draw() -> void:
	if puzzle == null:
		return
	var grid := _grid()
	var edge := grid.size.x / puzzle.size
	var block := Vector2.ONE * (edge - 2.0)
	for y in range(puzzle.size):
		for x in range(puzzle.size):
			var cell := Vector2i(x, y)
			var position_on_board := grid.position + Vector2(cell) * edge
			var mark := puzzle.at(cell)
			var color := EMPTY_COLOR
			if puzzle.state == Puzzle.State.WON:
				color = puzzle.reveal(cell)
			elif mark == Puzzle.Cell.FILLED:
				color = MARK_COLOR
			draw_rect(Rect2(position_on_board, block), color)
			if mark == Puzzle.Cell.CROSSED and puzzle.state != Puzzle.State.WON:
				_draw_cross(position_on_board + block * 0.5, edge * 0.14)
			if cell == _mistake:
				draw_rect(Rect2(position_on_board + Vector2.ONE, block - Vector2.ONE * 2.0), Color("#ff8f99"), false, 2.0)
			if cell == _cursor and has_focus() and puzzle.state == Puzzle.State.PLAYING:
				draw_rect(Rect2(position_on_board + Vector2.ONE * 2.0, block - Vector2.ONE * 4.0), Color("#f8de9e"), false, 2.0)
	if puzzle.size == 10:
		var middle := grid.get_center()
		draw_line(Vector2(middle.x - 1.0, grid.position.y), Vector2(middle.x - 1.0, grid.end.y), CLUE_COLOR, 2.0)
		draw_line(Vector2(grid.position.x, middle.y - 1.0), Vector2(grid.end.x, middle.y - 1.0), CLUE_COLOR, 2.0)
	for index in range(puzzle.size):
		_draw_clues(grid.position, edge, index, true, puzzle.row_clues[index], puzzle.rows_done[index] == 1)
		_draw_clues(grid.position, edge, index, false, puzzle.column_clues[index], puzzle.columns_done[index] == 1)


func _draw_cross(midpoint: Vector2, radius: float) -> void:
	var down := Vector2(radius, radius)
	var up := Vector2(radius, -radius)
	draw_line(midpoint - down, midpoint + down, CLUE_COLOR, 2.0, true)
	draw_line(midpoint - up, midpoint + up, CLUE_COLOR, 2.0, true)


func _draw_clues(origin: Vector2, edge: float, index: int, is_row: bool, numbers: PackedInt32Array, done: bool) -> void:
	var values := numbers if not numbers.is_empty() else PackedInt32Array([0])
	var font := get_theme_default_font()
	var font_size := clampi(roundi(edge * 0.47), 18, 27)
	var gap := font_size + 4.0
	var color := DONE_COLOR if done else CLUE_COLOR
	for i in range(values.size()):
		var distance := (values.size() - i - 0.5) * gap + 6.0
		var line_center := (index + 0.5) * edge
		var center := origin + (Vector2(-distance, line_center) if is_row else Vector2(line_center, -distance))
		var number := str(values[i])
		var width := font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var baseline := (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
		draw_string(font, center + Vector2(-width * 0.5, baseline), number, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
