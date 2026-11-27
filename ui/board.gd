extends "res://ui/board_feedback.gd"

const Puzzle := preload("res://scripts/nonogram/puzzle.gd")
const Camera := preload("res://ui/board_camera.gd")
const Art := preload("res://ui/mascot_art.gd")
const WIDTH := 696.0
const EDGE_PADDING := 4.0
const CLUE_PADDING := 8.0
const CLUE_FONT_SIZE := 20
const CLUE_STEP := 24.0

const OUTSIDE := Vector2i(-1, -1)
const EMPTY_COLOR := Color("#263851")
const CLUE_COLOR := Color("#d6e4fa")
const DONE_COLOR := Color("#79dccc")
const MARK_COLOR := Color("#8ee8db")

var puzzle: Puzzle
var cross_mode := false
var _streak_dip := 0.0
var _anchor := OUTSIDE
var _last := OUTSIDE
var _axis := Vector2i.ZERO
var _drag_cross := false
var _drag_cells: Dictionary = {}
var _cursor := OUTSIDE
var _mistake := OUTSIDE
var _gutter := Vector2.ZERO
var _camera := Camera.new()
var _clips: Array[Control] = []
var _layers: Array[Node2D] = []
var _pixels_per_unit := 1.0
var _touches: Dictionary = {}
var _touch_start := Vector2.ZERO
var _touch_moved := false
var _pinch_distance := 0.0
var _pinch_edge := 0.0
var _mouse_pan_button := MOUSE_BUTTON_NONE


func _ready() -> void:
	super()
	_gutter = Vector2(_clue_depth(puzzle.row_clues), _clue_depth(puzzle.column_clues))
	if supports_zoom():
		_add_layer(_paint_zoom_cells)
		_add_layer(_paint_zoom_rows)
		_add_layer(_paint_zoom_columns)
		get_viewport().size_changed.connect(_schedule_resize)
		resized.connect(_schedule_resize)
		set_notify_transform(true)
		_schedule_resize()
	else:
		set_process_input(false)
	update_minimum_size()
	focus_mode = Control.FOCUS_ALL
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	mouse_exited.connect(cancel_drag)
	get_window().focus_exited.connect(_cancel_input)
	puzzle.cell_changed.connect(_redraw_cell)
	puzzle.correct_fill.connect(_on_fill)
	puzzle.line_completed.connect(_redraw_line)
	puzzle.mistake.connect(_show_mistake)
	puzzle.finished.connect(_redraw_result)


func _get_minimum_size() -> Vector2:
	return Vector2(WIDTH, WIDTH - _gutter.x + _gutter.y)


func _clue_depth(lines: Array[PackedInt32Array]) -> float:
	var longest := 1
	for line in lines:
		longest = maxi(longest, line.size())
	return CLUE_PADDING + longest * CLUE_STEP


func _grid() -> Rect2:
	var available := size - _gutter - Vector2.ONE * EDGE_PADDING
	var edge := maxf(0.0, minf(available.x, available.y))
	return Rect2(_gutter, Vector2.ONE * edge)


func supports_zoom() -> bool:
	return puzzle != null and puzzle.size > 10


func fit_zoom() -> void:
	_camera.fit()
	queue_redraw()


func _add_layer(paint: Callable) -> void:
	var clip := Control.new()
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.clip_contents = true
	add_child(clip)
	var layer := Node2D.new()
	clip.add_child(layer)
	layer.draw.connect(paint.bind(layer))
	_clips.append(clip)
	_layers.append(layer)


func _schedule_resize() -> void:
	_resize_camera.call_deferred()


func _resize_camera() -> void:
	if not is_inside_tree():
		return
	var scale_factor := get_screen_transform().get_scale().abs()
	_pixels_per_unit = minf(scale_factor.x, scale_factor.y)
	if OS.has_feature("web"):
		var ratio: Variant = JavaScriptBridge.eval("window.devicePixelRatio", true)
		if ratio is float or ratio is int:
			_pixels_per_unit /= maxf(float(ratio), 0.01)
	var frame := _grid()
	if _camera.edge > 0.0 and frame.has_area():
		var minimum := _camera.minimum_edge(frame, puzzle.size, _pixels_per_unit)
		_zoom_at(maxf(_camera.edge, minimum), frame.get_center(), frame.get_center())
	queue_redraw()


func _motion_offset() -> Vector2:
	return _shake_offset() + Vector2(0, _streak_dip)


func _zoom_at(edge: float, source: Vector2, destination: Vector2) -> void:
	var frame := _grid()
	if frame.has_area():
		_camera.zoom(frame, puzzle.size, _pixels_per_unit, edge, source, destination)
		queue_redraw()


func _pan(offset: Vector2) -> void:
	_camera.move(_grid(), puzzle.size, offset)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or puzzle.state != Puzzle.State.PLAYING:
		_touches.clear()
		return
	if event is InputEventScreenTouch:
		var touch := make_input_local(event) as InputEventScreenTouch
		if touch.pressed and not _grid().has_point(touch.position - _motion_offset()):
			return
		if touch.pressed or _touches.has(touch.index):
			_touch(touch)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and _touches.has(event.index):
		_touch_drag(make_input_local(event) as InputEventScreenDrag)
		get_viewport().set_input_as_handled()


func _touch(event: InputEventScreenTouch) -> void:
	var point := event.position - _motion_offset()
	if event.pressed:
		_touches[event.index] = point
		match _touches.size():
			1:
				_touch_start = point
				_touch_moved = false
				grab_focus()
			2:
				_pinch_distance = _touch_span().length()
				_pinch_edge = _camera.cell_edge(_grid(), puzzle.size)
				_touch_moved = true
		return
	_touches.erase(event.index)
	if _touches.is_empty() and not _touch_moved and not event.canceled and point.distance_to(_touch_start) * _pixels_per_unit < 8.0:
		var cell := cell_at(event.position)
		if cell != OUTSIDE:
			_cursor = cell
			puzzle.mark(cell, cross_mode)
			queue_redraw()
	elif _touches.size() == 2:
		_pinch_distance = _touch_span().length()
		_pinch_edge = _camera.cell_edge(_grid(), puzzle.size)


func _touch_span() -> Vector2:
	var points := _touches.values()
	return Vector2(points[0]) - Vector2(points[1])


func _touch_drag(event: InputEventScreenDrag) -> void:
	var point := event.position - _motion_offset()
	var previous: Vector2 = _touches[event.index]
	var old_span := _touch_span() if _touches.size() == 2 else Vector2.ZERO
	_touches[event.index] = point
	if _touches.size() == 2:
		var first: Vector2 = _touches.values()[0]
		var second: Vector2 = _touches.values()[1]
		var midpoint := (first + second) * 0.5
		if _pinch_distance > 0.001 and old_span.length_squared() > 0.001:
			_zoom_at(_pinch_edge * first.distance_to(second) / _pinch_distance, midpoint - (point - previous) * 0.5, midpoint)
	elif _touches.size() == 1:
		if _touch_moved:
			_pan(point - previous)
		elif point.distance_to(_touch_start) * _pixels_per_unit >= 8.0:
			_touch_moved = true
			_pan(point - _touch_start)


func _cancel_input() -> void:
	cancel_drag()
	_touches.clear()
	_mouse_pan_button = MOUSE_BUTTON_NONE


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		_cancel_input()
	elif what == NOTIFICATION_TRANSFORM_CHANGED and is_inside_tree() and supports_zoom():
		_schedule_resize()


func _zoom_mouse(event: InputEvent) -> bool:
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return true
	if event is InputEventMouseMotion and _mouse_pan_button != MOUSE_BUTTON_NONE:
		if event.button_mask & (1 << (_mouse_pan_button - 1)):
			_pan(event.relative)
			return true
		_mouse_pan_button = MOUSE_BUTTON_NONE
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			if event.pressed:
				var point: Vector2 = event.position - _motion_offset()
				var frame := _grid()
				var direction := 1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0
				var edge := _camera.cell_edge(frame, puzzle.size) * pow(1.22, direction * maxf(1.0, event.factor))
				if direction < 0.0 and edge < _camera.minimum_edge(frame, puzzle.size, _pixels_per_unit):
					fit_zoom()
				else:
					_zoom_at(edge, point, point)
			return true
		if not event.pressed and event.button_index == _mouse_pan_button:
			_mouse_pan_button = MOUSE_BUTTON_NONE
			return true
		if event.pressed and (event.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT] or (event.button_index == MOUSE_BUTTON_LEFT and event.shift_pressed)):
			cancel_drag()
			_mouse_pan_button = event.button_index
			return true
	return false


func _gui_input(event: InputEvent) -> void:
	if puzzle.state != Puzzle.State.PLAYING:
		return
	if supports_zoom() and _zoom_mouse(event):
		accept_event()
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
		if supports_zoom() and _camera.edge > 0.0:
			var frame := _grid()
			var center := _camera.grid(frame, puzzle.size).position + (Vector2(_cursor) + Vector2.ONE * 0.5) * _camera.edge
			var inset := frame.grow(-_camera.edge * 0.5)
			_pan(center.clamp(inset.position, inset.end) - center)
		queue_redraw()
		accept_event()
	elif event.is_action_pressed(&"ui_accept"):
		if _cursor == OUTSIDE:
			_cursor = Vector2i.ZERO
		puzzle.mark(_cursor, cross_mode)
		accept_event()


func set_streak_dip(dip: float) -> void:
	if not is_equal_approx(_streak_dip, dip):
		_streak_dip = dip
		queue_redraw()


func cell_at(position_in_board: Vector2) -> Vector2i:
	position_in_board -= _motion_offset()
	var grid := _grid()
	if supports_zoom():
		return _camera.cell_at(grid, puzzle.size, position_in_board)
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
		if _anchor == OUTSIDE or puzzle.state != Puzzle.State.PLAYING:
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


func _redraw_line(is_row: bool, index: int) -> void:
	_glow(is_row, index)
	queue_redraw()


func _on_fill(cell: Vector2i, _completed_lines: int) -> void:
	_bounce(cell)


func _redraw_result(won: bool) -> void:
	_cancel_input()
	if won and supports_zoom():
		fit_zoom()
	queue_redraw()


func _show_mistake(cell: Vector2i) -> void:
	cancel_drag()
	_shake()
	_mistake = cell
	queue_redraw()


func _draw() -> void:
	if puzzle == null:
		return
	var frame := _grid()
	if supports_zoom():
		var rectangles := [
			frame,
			Rect2(0.0, frame.position.y, frame.position.x, frame.size.y),
			Rect2(frame.position.x, 0.0, frame.size.x, frame.position.y),
		]
		for index in range(_clips.size()):
			_clips[index].position = rectangles[index].position + _motion_offset()
			_clips[index].size = rectangles[index].size
			_layers[index].queue_redraw()
		return
	draw_set_transform(_motion_offset())
	_draw_cells(self, frame)
	_draw_axis(self, frame.position, frame.size.x / puzzle.size, true)
	_draw_axis(self, frame.position, frame.size.x / puzzle.size, false)


func _paint_zoom_cells(painter: Node2D) -> void:
	var frame := _grid()
	painter.draw_set_transform(-frame.position)
	_draw_cells(painter, _camera.grid(frame, puzzle.size), frame)


func _paint_zoom_rows(painter: Node2D) -> void:
	var frame := _grid()
	painter.draw_set_transform(Vector2(0, -frame.position.y))
	var origin := Vector2(frame.position.x, _camera.grid(frame, puzzle.size).position.y)
	_draw_axis(painter, origin, _camera.cell_edge(frame, puzzle.size), true, frame)


func _paint_zoom_columns(painter: Node2D) -> void:
	var frame := _grid()
	painter.draw_set_transform(Vector2(-frame.position.x, 0))
	var origin := Vector2(_camera.grid(frame, puzzle.size).position.x, frame.position.y)
	_draw_axis(painter, origin, _camera.cell_edge(frame, puzzle.size), false, frame)


func _draw_cells(painter: CanvasItem, grid: Rect2, visible_grid := Rect2()) -> void:
	if grid.size.x < 2.0:
		return
	var edge := grid.size.x / puzzle.size
	var block := Vector2.ONE * (edge - 2.0)
	for y in range(puzzle.size):
		for x in range(puzzle.size):
			var cell := Vector2i(x, y)
			var position_on_board := grid.position + Vector2(cell) * edge
			if visible_grid.has_area() and not visible_grid.intersects(Rect2(position_on_board, Vector2.ONE * edge)):
				continue
			var mark := puzzle.at(cell)
			var color := EMPTY_COLOR
			if puzzle.state == Puzzle.State.WON:
				color = puzzle.reveal(cell)
			elif mark == Puzzle.Cell.FILLED:
				color = MARK_COLOR
			var tile := Rect2(position_on_board, block)
			painter.draw_rect(tile, EMPTY_COLOR)
			if color != EMPTY_COLOR:
				painter.draw_rect(_bounced(tile, cell), color)
			if mark == Puzzle.Cell.CROSSED and puzzle.state != Puzzle.State.WON:
				_draw_cross(painter, position_on_board + block * 0.5, edge * 0.14)
			if puzzle.state != Puzzle.State.WON and puzzle.is_given(cell):
				var accent := Color("#b8a0f3") if mark == Puzzle.Cell.CROSSED else Color("#baf9f1")
				painter.draw_rect(tile.grow(-1.0), accent, false, 2.0)
				painter.draw_circle(position_on_board + block * Vector2(0.80, 0.20), edge * 0.052, Color("#10222d") if mark == Puzzle.Cell.FILLED else accent)
			if puzzle.has_collected_star(cell):
				var pulse := float(_fills.get(cell, 0.0)) / FILL_SECONDS
				Art.spark(painter, tile.get_center(), edge * (0.29 + 0.09 * pulse), Color("#553b56"))
				Art.spark(painter, tile.get_center(), edge * (0.23 + 0.09 * pulse), Color("#ffdf8e"))
			if cell == _mistake:
				painter.draw_rect(Rect2(position_on_board + Vector2.ONE, block - Vector2.ONE * 2.0), Color("#ff8f99"), false, 2.0)
			if cell == _cursor and has_focus() and puzzle.state == Puzzle.State.PLAYING:
				painter.draw_rect(Rect2(position_on_board + Vector2.ONE * 2.0, block - Vector2.ONE * 4.0), Color("#f8de9e"), false, 2.0)
	_paint_glow(grid, edge, painter)
	if puzzle.size >= 10:
		for separator in range(5, puzzle.size, 5):
			var offset := edge * separator - 1.0
			painter.draw_line(Vector2(grid.position.x + offset, grid.position.y), Vector2(grid.position.x + offset, grid.end.y), CLUE_COLOR, 3.0)
			painter.draw_line(Vector2(grid.position.x, grid.position.y + offset), Vector2(grid.end.x, grid.position.y + offset), CLUE_COLOR, 3.0)


func _draw_axis(painter: CanvasItem, origin: Vector2, edge: float, is_row: bool, visible_grid := Rect2()) -> void:
	var clues := puzzle.row_clues if is_row else puzzle.column_clues
	var done := puzzle.rows_done if is_row else puzzle.columns_done
	var axis := Vector2.AXIS_Y if is_row else Vector2.AXIS_X
	for index in range(puzzle.size):
		var center: float = origin[axis] + (index + 0.5) * edge
		if not visible_grid.has_area() or (center >= visible_grid.position[axis] - edge * 0.5 and center < visible_grid.end[axis] + edge * 0.5):
			_draw_clues(painter, origin, edge, index, is_row, clues[index], done[index] == 1)

func _draw_cross(painter: CanvasItem, midpoint: Vector2, radius: float) -> void:
	var down := Vector2(radius, radius)
	var up := Vector2(radius, -radius)
	painter.draw_line(midpoint - down, midpoint + down, CLUE_COLOR, 2.0, true)
	painter.draw_line(midpoint - up, midpoint + up, CLUE_COLOR, 2.0, true)


func _draw_clues(painter: CanvasItem, origin: Vector2, edge: float, index: int, is_row: bool, numbers: PackedInt32Array, done: bool) -> void:
	var values := numbers if not numbers.is_empty() else PackedInt32Array([0])
	var font := get_theme_default_font()
	var font_size := CLUE_FONT_SIZE
	var color := DONE_COLOR if done else CLUE_COLOR
	for i in range(values.size()):
		var distance := (values.size() - i - 0.5) * CLUE_STEP + CLUE_PADDING
		var line_center := (index + 0.5) * edge
		var center := origin + (Vector2(-distance, line_center) if is_row else Vector2(line_center, -distance))
		var number := str(values[i])
		var width := font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var baseline := (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
		painter.draw_string(font, center + Vector2(-width * 0.5, baseline), number, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
