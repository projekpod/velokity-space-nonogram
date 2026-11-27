extends Control

@onready var _settings := get_node("/root/Settings")

var _calm := false
var _fills: Dictionary = {}
var _rows: Dictionary = {}
var _columns: Dictionary = {}
var _shake_time := 0.0
var _shake_strength := 5.0

const FILL_SECONDS := 0.24
const GLOW_SECONDS := 0.30
const SHAKE_SECONDS := 0.19


func _ready() -> void:
	get_node("/root/Events").settings_changed.connect(_refresh_motion)
	_refresh_motion()
	set_process(false)


func _refresh_motion() -> void:
	_calm = _settings.get_value("calm_mode")
	if _calm:
		_fills.clear()
		_rows.clear()
		_columns.clear()
		_shake_time = 0.0
		set_process(false)
		queue_redraw()


func _process(delta: float) -> void:
	_shake_time = maxf(0.0, _shake_time - delta)
	for pulses in [_fills, _rows, _columns]:
		for key: Variant in pulses.keys():
			pulses[key] -= delta
			if pulses[key] <= 0.0:
				pulses.erase(key)
	queue_redraw()
	set_process(_shake_time > 0.0 or not _fills.is_empty() or not _rows.is_empty() or not _columns.is_empty())


func _bounce(cell: Vector2i) -> void:
	if not _calm:
		_fills[cell] = FILL_SECONDS
		set_process(true)


func _glow(is_row: bool, index: int) -> void:
	if _calm:
		return
	var pulses := _rows if is_row else _columns
	pulses[index] = GLOW_SECONDS
	set_process(true)


func _shake() -> void:
	if not _calm:
		_shake_strength = 5.0
		_rows.clear()
		_columns.clear()
		_shake_time = SHAKE_SECONDS
		set_process(true)


func streak_shake(strength: float) -> void:
	if not _calm:
		_shake_strength = strength
		_shake_time = SHAKE_SECONDS
		set_process(true)


func _shake_offset() -> Vector2:
	var fraction := _shake_time / SHAKE_SECONDS
	return Vector2(sin(fraction * TAU * 2.0) * fraction * _shake_strength, 0.0)


func _bounced(tile: Rect2, cell: Vector2i) -> Rect2:
	var fraction := float(_fills.get(cell, 0.0)) / FILL_SECONDS
	if fraction <= 0.0:
		return tile
	var inset := tile.size.x * 0.12 * fraction * cos((1.0 - fraction) * TAU)
	return tile.grow(-inset)


func _paint_glow(grid: Rect2, edge: float, painter: CanvasItem = null) -> void:
	var canvas: CanvasItem = self if painter == null else painter
	for index: int in _rows:
		var row := Rect2(grid.position + Vector2(0, index * edge), Vector2(grid.size.x, edge))
		canvas.draw_rect(row, Color(Color("#93f2e4"), 0.20 * _rows[index] / GLOW_SECONDS))
	for index: int in _columns:
		var column := Rect2(grid.position + Vector2(index * edge, 0), Vector2(edge, grid.size.y))
		canvas.draw_rect(column, Color(Color("#93f2e4"), 0.20 * _columns[index] / GLOW_SECONDS))
