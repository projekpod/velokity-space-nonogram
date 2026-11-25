extends Control

const Puzzle := preload("res://scripts/daily/puzzle.gd")
const UI := preload("res://ui/controls.gd")

const REGIONS := [
	Color("#305472"), Color("#504268"), Color("#2a5a53"),
	Color("#69434a"), Color("#645239"), Color("#344773"),
	Color("#5b3b5c"), Color("#436244"), Color("#3d5262"),
]
const BORDER := Color("#e0eeff")
const MISTAKE := Color("#ff9a9f")

var puzzle: Puzzle
var note_mode := false
var _cursor := Vector2i.ZERO
var _mistake := Vector2i(-1, -1)


func _ready() -> void:
	custom_minimum_size = Vector2(572, 562)
	focus_mode = Control.FOCUS_ALL
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	puzzle.changed.connect(_on_changed)
	puzzle.mistake.connect(_on_mistake)


func _gui_input(event: InputEvent) -> void:
	if puzzle.state != Puzzle.State.PLAYING:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var board := _rect()
		if not board.has_point(event.position):
			return
		_cursor = Vector2i(((event.position - board.position) / board.size * puzzle.size).floor())
		grab_focus()
		puzzle.place(_cursor, note_mode)
		accept_event()
	elif event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event)


func _handle_key(event: InputEventKey) -> void:
	for action: StringName in [&"ui_left", &"ui_right", &"ui_up", &"ui_down"]:
		if event.is_action_pressed(action):
			var direction := Vector2i(Input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down").round())
			_cursor = (_cursor + direction).clamp(Vector2i.ZERO, Vector2i.ONE * (puzzle.size - 1))
			queue_redraw()
			accept_event()
			return
	if event.is_action_pressed(&"ui_accept"):
		puzzle.place(_cursor, note_mode)
		accept_event()


func _rect() -> Rect2:
	var edge := minf(size.x, size.y) - 8.0
	return Rect2((size - Vector2.ONE * edge) * 0.5, Vector2.ONE * edge)


func _on_changed() -> void:
	_mistake = Vector2i(-1, -1)
	queue_redraw()


func _on_mistake(cell: Vector2i) -> void:
	_mistake = cell
	queue_redraw()


func _draw() -> void:
	if puzzle == null:
		return
	var board := _rect()
	var edge := board.size.x / puzzle.size
	for y in range(puzzle.size):
		for x in range(puzzle.size):
			var cell := Vector2i(x, y)
			var origin := board.position + Vector2(cell) * edge
			var tile := Rect2(origin, Vector2.ONE * edge)
			draw_rect(tile, REGIONS[puzzle.region_at(cell)])
			if cell == _mistake:
				draw_rect(tile.grow(-3), MISTAKE, false, 3.0)
			elif cell == _cursor and has_focus() and puzzle.state == Puzzle.State.PLAYING:
				draw_rect(tile.grow(-4), UI.GOLD, false, 2.0)
			if puzzle.is_star(cell):
				_draw_star(tile.get_center(), edge * 0.30)
			elif puzzle.is_eliminated(cell):
				_draw_cross(tile.get_center(), edge * 0.23, MISTAKE, 4.0)
			elif puzzle.has_note(cell):
				_draw_cross(tile.get_center(), edge * 0.15, BORDER, 2.0)
	for index in range(1, puzzle.size):
		var offset := edge * index
		draw_line(board.position + Vector2(offset, 0), Vector2(board.position.x + offset, board.end.y), Color("#19263b"), 2.0)
		draw_line(board.position + Vector2(0, offset), Vector2(board.end.x, board.position.y + offset), Color("#19263b"), 2.0)
	for y in range(puzzle.size):
		for x in range(puzzle.size):
			var cell := Vector2i(x, y)
			var origin := board.position + Vector2(cell) * edge
			var region := puzzle.region_at(cell)
			if x + 1 < puzzle.size and region != puzzle.region_at(cell + Vector2i.RIGHT):
				draw_line(origin + Vector2(edge, 0), origin + Vector2.ONE * edge, BORDER, 3.0)
			if y + 1 < puzzle.size and region != puzzle.region_at(cell + Vector2i.DOWN):
				draw_line(origin + Vector2(0, edge), origin + Vector2.ONE * edge, BORDER, 3.0)
	draw_rect(board, BORDER, false, 3.0)


func _draw_cross(midpoint: Vector2, radius: float, color: Color, width: float) -> void:
	var arm := Vector2.ONE * radius
	draw_line(midpoint - arm, midpoint + arm, color, width, true)
	arm.x = -arm.x
	draw_line(midpoint - arm, midpoint + arm, color, width, true)


func _draw_star(midpoint: Vector2, radius: float) -> void:
	var points := PackedVector2Array()
	for corner in range(10):
		var distance := radius if corner % 2 == 0 else radius * 0.48
		points.append(midpoint + Vector2.UP.rotated(corner * TAU / 10.0) * distance)
	draw_colored_polygon(points, UI.GOLD)
