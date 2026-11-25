extends Control


var level: Dictionary


func _ready() -> void:
	custom_minimum_size.y = 88
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var field := Rect2(size * 0.5 - Vector2(42, 42), Vector2(84, 84))
	var border := StyleBoxFlat.new()
	border.bg_color = Color("#101a30")
	border.set_corner_radius_all(10)
	border.set_border_width_all(1)
	border.border_color = Color("#3b536d") if not level.is_empty() else Color("#263650")
	draw_style_box(border, field)
	if level.is_empty():
		var center := field.get_center()
		var lock := Color("#7187a5")
		draw_arc(center + Vector2(0, -4), 8, PI, TAU, 16, lock, 2, true)
		draw_rect(Rect2(center + Vector2(-12, -3), Vector2(24, 17)), lock, false, 2)
		draw_circle(center + Vector2(0, 5), 2, lock, true)
		return

	var cells: int = int(level.size)
	var edge := floorf(70.0 / cells)
	var start := field.get_center() - Vector2.ONE * edge * cells * 0.5
	for y in range(cells):
		for x in range(cells):
			var pixel: String = level.solution[y][x]
			var color := Color(level.palette.get(pixel, "#1b2b46"))
			draw_rect(Rect2(start + Vector2(x, y) * edge, Vector2.ONE * (edge - 1.0)), color)
