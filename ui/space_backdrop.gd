extends Control


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#0c1224"))
	for index in range(160):
		var position_on_screen := Vector2(
			fmod(index * 0.6180339887, 1.0) * size.x,
			fmod(index * 0.4142135624 + 0.1, 1.0) * size.y
		)
		draw_circle(position_on_screen, 1.0 + index % 3 * 0.6, Color("#64759c"), true, -1.0, true)
