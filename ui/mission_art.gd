extends Control

const Mascot := preload("res://ui/mascot.gd")
const Art := preload("res://ui/mascot_art.gd")

var compact := false
var idle_expression := Mascot.Face.HAPPY
var mascot: Mascot


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(112, 104) if compact else Vector2(0, 358)
	mascot = Mascot.new()
	mascot.idle_expression = idle_expression
	add_child(mascot)
	mascot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not compact:
		mascot.offset_top = 12.0
		mascot.offset_bottom = -12.0
	resized.connect(queue_redraw)


func _draw() -> void:
	var middle := size * 0.5
	if compact:
		draw_circle(middle, minf(size.x, size.y) * 0.47, Color("#182941"), true)
		draw_arc(middle, minf(size.x, size.y) * 0.47, 0, TAU, 48, Color("#43647e"), 1.0, true)
		return
	var accent := Color("#527398")
	draw_set_transform(middle, -0.25, Vector2(1.0, 0.75))
	draw_circle(Vector2.ZERO, 153.0, Color("#182746"), true)
	draw_arc(Vector2.ZERO, 154, 0, TAU, 90, Color("#588da0"), 1.5, true)
	draw_arc(Vector2.ZERO, 179, 0, TAU, 100, accent, 1.0, true)
	draw_arc(Vector2.ZERO, 198, 0.19, 2.71, 60, Color("#385373"), 1.0, true)
	draw_arc(Vector2.ZERO, 198, 3.46, 5.70, 60, Color("#385373"), 1.0, true)
	draw_set_transform(Vector2.ZERO)
	Art.spark(self, middle + Vector2(-153, -69), 13.0, Art.GOLD)
	Art.spark(self, middle + Vector2(167, 44), 9.0, Art.MINT)
	draw_circle(middle + Vector2(142, -112), 4.0, Art.MINT, true)
	draw_circle(middle + Vector2(-170, 77), 3.0, Art.GOLD, true)
