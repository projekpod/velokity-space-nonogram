extends RefCounted

signal cell_changed(cell: Vector2i)
signal line_completed(is_row: bool, index: int)
signal mistake(cell: Vector2i)
signal finished(won: bool)

enum Cell { UNKNOWN, FILLED, CROSSED }
enum State { PLAYING, WON, LOST }

const MAX_LIVES := 3

var size: int
var lives := MAX_LIVES
var state := State.PLAYING
var row_clues: Array[PackedInt32Array] = []
var column_clues: Array[PackedInt32Array] = []
var rows_done := PackedByteArray()
var columns_done := PackedByteArray()
var palette: Dictionary
var _solution: Array
var _cells := PackedByteArray()
var _remaining := 0
var _continued := false


func _init(level: Dictionary) -> void:
	_solution = level.solution
	palette = level.palette
	size = int(level.size)
	_cells.resize(size * size)
	rows_done.resize(size)
	columns_done.resize(size)
	for index in range(size):
		var row := PackedByteArray()
		var column := PackedByteArray()
		for offset in range(size):
			row.append(int(_solution[index][offset] != "."))
			column.append(int(_solution[offset][index] != "."))
		var horizontal := clues(row)
		var vertical := clues(column)
		row_clues.append(horizontal)
		column_clues.append(vertical)
		for number in horizontal:
			_remaining += number
	for index in range(size):
		_check_line(true, index)
		_check_line(false, index)


static func clues(line: PackedByteArray) -> PackedInt32Array:
	var result := PackedInt32Array()
	var run := 0
	for filled in line:
		if filled:
			run += 1
		elif run > 0:
			result.append(run)
			run = 0
	if run > 0:
		result.append(run)
	return result


func at(cell: Vector2i) -> int:
	return _cells[cell.y * size + cell.x]


func reveal(cell: Vector2i) -> Color:
	return Color(palette.get(_solution[cell.y][cell.x], "#192638"))


func mark(cell: Vector2i, crossed: bool) -> void:
	if state != State.PLAYING or not Rect2i(0, 0, size, size).has_point(cell):
		return
	if at(cell) != Cell.UNKNOWN:
		return
	var filled: bool = _solution[cell.y][cell.x] != "."
	var wrong := filled == crossed
	if wrong:
		lives -= 1
		if lives == 0:
			state = State.LOST
	_apply_mark(cell, filled)
	if wrong:
		mistake.emit(cell)
	if state == State.LOST:
		finished.emit(false)
	elif _remaining == 0:
		state = State.WON
		finished.emit(true)


func _apply_mark(cell: Vector2i, filled: bool) -> void:
	if not filled:
		_set_cell(cell, Cell.CROSSED)
		return
	_remaining -= 1
	_set_cell(cell, Cell.FILLED)
	_check_line(true, cell.y)
	_check_line(false, cell.x)


func hint() -> bool:
	var cell := hint_cell()
	if cell.x < 0:
		return false
	mark(cell, false)
	return true


func hint_cell() -> Vector2i:
	var next_cell := Vector2i(-1, -1)
	if state != State.PLAYING:
		return next_cell
	var fewest := size + 1
	for is_row: bool in [true, false]:
		var completed := rows_done if is_row else columns_done
		for index in range(size):
			if completed[index]:
				continue
			var unknown := 0
			var first_fill := Vector2i(-1, -1)
			for offset in range(size):
				var cell := _line_cell(is_row, index, offset)
				if at(cell) != Cell.UNKNOWN:
					continue
				unknown += 1
				if first_fill.x < 0 and _solution[cell.y][cell.x] != ".":
					first_fill = cell
			if first_fill.x >= 0 and unknown < fewest:
				fewest = unknown
				next_cell = first_fill
	return next_cell


func can_continue() -> bool:
	return state == State.LOST and not _continued


func continue_game() -> bool:
	if not can_continue():
		return false
	_continued = true
	lives = 1
	state = State.PLAYING if _remaining > 0 else State.WON
	if state == State.WON:
		finished.emit(true)
	return true


func _check_line(is_row: bool, index: int) -> void:
	if (rows_done[index] if is_row else columns_done[index]):
		return
	for offset in range(size):
		var cell := _line_cell(is_row, index, offset)
		if _solution[cell.y][cell.x] != "." and at(cell) != Cell.FILLED:
			return
	if is_row:
		rows_done[index] = 1
	else:
		columns_done[index] = 1
	for offset in range(size):
		var cell := _line_cell(is_row, index, offset)
		if at(cell) == Cell.UNKNOWN:
			_set_cell(cell, Cell.CROSSED)
	line_completed.emit(is_row, index)


func _set_cell(cell: Vector2i, value: Cell) -> void:
	_cells[cell.y * size + cell.x] = value
	cell_changed.emit(cell)


static func _line_cell(is_row: bool, index: int, offset: int) -> Vector2i:
	return Vector2i(offset, index) if is_row else Vector2i(index, offset)
