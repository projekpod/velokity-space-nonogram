extends RefCounted

signal changed
signal star_placed(cell: Vector2i)
signal note_changed
signal mistake(cell: Vector2i)
signal finished(won: bool)

enum State { PLAYING, WON, LOST }

const MAX_LIVES := 3

var size: int
var regions: Array
var lives := MAX_LIVES
var state := State.PLAYING
var stars := PackedInt32Array()
var _solution: Array
var _notes: Dictionary = {}
var _eliminated: Dictionary = {}
var _placed := 0


func _init(level: Dictionary) -> void:
	size = int(level.size)
	regions = level.regions
	_solution = level.solution
	stars.resize(size)
	stars.fill(-1)


func is_star(cell: Vector2i) -> bool:
	return stars[cell.y] == cell.x


func has_note(cell: Vector2i) -> bool:
	return _notes.has(cell)


func is_eliminated(cell: Vector2i) -> bool:
	return _eliminated.has(cell)


func region_at(cell: Vector2i) -> int:
	return int(regions[cell.y][cell.x])


func place(cell: Vector2i, note: bool) -> void:
	if state != State.PLAYING or not Rect2i(0, 0, size, size).has_point(cell) or is_star(cell) or is_eliminated(cell):
		return
	if note:
		if not _notes.erase(cell):
			_notes[cell] = true
		changed.emit()
		note_changed.emit()
		return
	if cell.x != int(_solution[cell.y]):
		_notes.erase(cell)
		_eliminated[cell] = true
		lives -= 1
		if lives == 0:
			state = State.LOST
		mistake.emit(cell)
		if state == State.LOST:
			finished.emit(false)
		return
	_notes.erase(cell)
	stars[cell.y] = cell.x
	_placed += 1
	if _placed == size:
		state = State.WON
	changed.emit()
	star_placed.emit(cell)
	if state == State.WON:
		finished.emit(true)
