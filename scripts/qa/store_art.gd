extends Control

const Mascot := preload("res://ui/mascot.gd")
const Art := preload("res://ui/mascot_art.gd")
const UI := preload("res://ui/controls.gd")

var icon_only := false
var _mascot: Mascot
var _title: Label
var _subtitle: Label
var _center: Vector2
var _radius: float


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mascot = Mascot.new()
	_mascot.preview_outfit = {}
	add_child(_mascot)
	_mascot.hold_pose(Mascot.Face.HAPPY)
	if not icon_only:
		_title = UI.label(self, "GAME_NAME", 120, UI.MINT)
		_subtitle = UI.label(self, "GAME_SUBTITLE", 38)
		for label in [_title, _subtitle]:
			label.add_theme_color_override("font_outline_color", Color("#101a32"))
			label.add_theme_constant_override("outline_size", 8)
	resized.connect(_compose)
	_compose()


func _compose() -> void:
	var side := minf(size.x, size.y)
	var wide := size.x >= size.y * 1.2
	_radius = side * (0.43 if icon_only else (0.305 if wide else 0.29))
	_center = size * (Vector2(0.5, 0.51) if icon_only else (Vector2(0.26, 0.50) if wide else Vector2(0.5, 0.355)))
	_mascot.size = Vector2.ONE * _radius * 2.33
	_mascot.position = _center - _mascot.size * 0.5 + Vector2(0, _radius * 0.045)
	if not icon_only:
		var title_center := size.x * (0.727 if wide else 0.5)
		var title_top := size.y * (0.345 if wide else 0.625)
		var title_scale := clampf(size.x / size.y * 0.10, 0.12, 0.162) if wide else 0.152
		_place_text(_title, title_center, title_top, int(side * title_scale))
		_place_text(_subtitle, title_center, title_top + side * (0.21 if wide else 0.18), int(side * 0.057))
	queue_redraw()


func _place_text(label: Label, center: float, top: float, font_size: int) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.size = label.get_minimum_size()
	label.position = Vector2(center - label.size.x * 0.5, top)


func _draw() -> void:
	if _radius <= 0:
		return
	draw_circle(_center, _radius * 1.13, Color("#192541"), true, -1.0, true)
	draw_circle(_center, _radius * 0.9, Color("#223452"), true, -1.0, true)
	draw_arc(_center, _radius * 0.9, 0.0, TAU, 96, Color("#49728b"), 3, true)
	draw_set_transform(_center, -0.3, Vector2(1, 0.68))
	draw_arc(Vector2.ZERO, _radius * 1.23, 0.04, 2.84, 64, Color("#6e9bb2"), 4, true)
	draw_arc(Vector2.ZERO, _radius * 1.23, 3.2, 6.02, 64, Color("#6e9bb2"), 4, true)
	draw_set_transform(Vector2.ZERO)
	Art.spark(self, _center + Vector2(-0.91, -0.52) * _radius, _radius * 0.14, UI.GOLD)
	Art.spark(self, _center + Vector2(0.96, 0.48) * _radius, _radius * 0.115, UI.MINT)
	Art.spark(self, _center + Vector2(0.73, -0.78) * _radius, _radius * 0.07, UI.INK)
	if not icon_only:
		_draw_tiles()


func _draw_tiles() -> void:
	var wide := size.x >= size.y * 1.2
	var tile := minf(size.x, size.y) * 0.036
	var origin := size * (Vector2(0.727, 0.695) if wide else Vector2(0.5, 0.938)) - Vector2(2.5, 1.0) * tile
	for y in range(2):
		for x in range(5):
			var rect := Rect2(origin + Vector2(x, y) * tile, Vector2.ONE * tile * 0.8)
			var filled := Vector2i(x, y) in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(3, 0), Vector2i(2, 1), Vector2i(4, 1)]
			draw_rect(rect, Color("#529fa4") if filled else Color("#334863"))
