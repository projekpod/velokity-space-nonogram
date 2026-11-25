extends Control

const UI := preload("res://ui/controls.gd")
const Mascot := preload("res://ui/mascot.gd")
const Combo := preload("res://scripts/nonogram/combo.gd")

# Tier one is the board's 0.30 s line glow.
const SECONDS := [0.0, 0.30, 1.0, 2.0, 3.5]
const CALM_SECONDS := [0.0, 0.0, 0.55, 0.85, 1.1]
const SKIP_AFTER := 1.0
const MASCOT_SIZE := Vector2(450, 450)

@onready var _settings := get_node("/root/Settings")

var tier := 0
var _duration := 0.0
var _elapsed := 0.0
var _theme := 0
var _calm := false
var _combo_box := StyleBoxFlat.new()
var _title: Label
var _detail: Label
var _skip: Button
var _mascot: Mascot
var _focus_before: Control


func attach(parent: Node) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	parent.add_child(layer)
	layer.add_child(self)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title = UI.label(self, "", 34)
	_detail = UI.label(self, "", 23, UI.MUTED)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skip = UI.button(self, "CELEBRATION_SKIP")
	_skip.pressed.connect(dismiss)
	_combo_box.bg_color = Color("#16253c")
	_combo_box.set_border_width_all(2)
	_combo_box.set_corner_radius_all(19)
	resized.connect(_sync_frame)
	hide()
	set_process(false)


func play_combo(theme: int, lines: int) -> void:
	_theme = theme
	_combo_box.border_color = Color(Combo.COLORS[theme], 0.8)
	play(2, Combo.THEMES[theme], tr("COMBO_DETAILS") % [lines, Combo.multiplier(lines)])


func play(new_tier: int, title: String, detail := "") -> void:
	dismiss()
	tier = new_tier
	_calm = _settings.get_value("calm_mode")
	_duration = CALM_SECONDS[tier] if _calm else SECONDS[tier]
	_elapsed = 0.0
	_title.text = title
	_detail.text = detail
	_title.add_theme_font_size_override("font_size", 28 if tier == 2 else 34)
	_detail.add_theme_font_size_override("font_size", 19 if tier == 2 else 23)
	_skip.hide()
	mouse_filter = Control.MOUSE_FILTER_STOP if tier >= 3 else Control.MOUSE_FILTER_IGNORE
	if tier >= 3:
		_focus_before = get_viewport().gui_get_focus_owner()
		if _focus_before != null:
			_focus_before.release_focus()
		if _mascot == null:
			_mascot = Mascot.new()
			add_child(_mascot)
			_mascot.size = MASCOT_SIZE
		_mascot.hold_pose(Mascot.Face.CHEERING if tier == 4 else Mascot.Face.PROUD)
		_mascot.show()
	show()
	_sync_frame()
	set_process(true)


func dismiss() -> void:
	if tier == 0:
		return
	tier = 0
	hide()
	set_process(false)
	if _mascot != null:
		_mascot.hide()
	if is_instance_valid(_focus_before) and _focus_before.is_visible_in_tree():
		_focus_before.grab_focus()
	_focus_before = null


func freeze_at(elapsed: float) -> void:
	if tier == 0:
		return
	_elapsed = elapsed
	_sync_frame()
	set_process(false)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= _duration:
		dismiss()
		return
	if tier >= 3 and _duration >= 2.0 and _elapsed >= SKIP_AFTER and not _skip.visible:
		_skip.show()
		_skip.grab_focus()
	_sync_frame()


func _input(event: InputEvent) -> void:
	if tier >= 3 and event is InputEventKey:
		if not _skip.visible or not event.is_action(&"ui_accept"):
			get_viewport().set_input_as_handled()


func _sync_frame() -> void:
	if tier == 0:
		return
	var center := size * 0.5
	if tier == 2:
		var card := _combo_card()
		_title.position = card.position + Vector2(78, 5)
		_title.size = Vector2(card.size.x - 96, 35)
		_detail.position = _title.position + Vector2(0, 34)
		_detail.size = Vector2(_title.size.x, 27)
	else:
		var travel := 1.0 if _calm else ease(clampf(_elapsed / 0.75, 0.0, 1.0), 0.3)
		_mascot.position = center - MASCOT_SIZE * 0.5 + Vector2(-size.x * (1.0 - travel), 120.0 * (1.0 - travel))
		_title.position = center + Vector2(-310, 193)
		_title.size = Vector2(620, 54)
		_detail.position = _title.position + Vector2(0, 56)
		_detail.size = Vector2(620, 39)
		_skip.size = Vector2(192, 65)
		_skip.position = center + Vector2(-96, 307)
	queue_redraw()


func _combo_card() -> Rect2:
	var slide := 0.0 if _calm else 8.0 * (1.0 - ease(clampf(_elapsed / 0.26, 0.0, 1.0), 0.35))
	return Rect2(size.x * 0.5 - 218.0, 10.0 - slide, 436.0, 72.0)


func _draw() -> void:
	if tier == 2:
		var card := _combo_card()
		var color: Color = Combo.COLORS[_theme]
		draw_style_box(_combo_box, card)
		draw_set_transform(card.position + Vector2(54, 36), 0.0, Vector2.ONE * 0.82)
		_draw_theme(Vector2.ZERO, color)
	elif tier >= 3:
		var center := size * 0.5
		draw_rect(Rect2(Vector2.ZERO, size), Color("#080f20df"))
		var glow_color := UI.GOLD if tier == 4 else UI.MINT
		var spread := 225.0 if _calm else lerpf(188.0, 238.0, clampf(_elapsed / 0.9, 0.0, 1.0))
		for ring in range(3):
			draw_arc(center, spread + ring * 14.0, 0.0, TAU, 96, Color(glow_color, 0.20 - ring * 0.05), 2.0, true)
		for index in range(12):
			var ray := Vector2.from_angle(index * TAU / 12.0 + 0.17)
			var point := center + ray * (spread + 43.0 + (index % 2) * 23.0)
			_draw_star(point, 10.0 if index % 3 == 0 else 5.0, Color(glow_color, 0.72))


func _draw_theme(center: Vector2, color: Color) -> void:
	var sweep := 0.0 if _calm else clampf(_elapsed, 0.0, 1.0) * 0.62
	match _theme:
		0, 1, 3:
			var count := 3 if _theme == 3 else 1
			for index in range(count):
				var tip := center + Vector2(11, -12) + Vector2(index * 12 - 12, index * 9 - 9) * int(count > 1)
				var direction := Vector2(-1, 0.57).rotated(sweep - 0.28)
				for trail in range(3):
					var offset := Vector2(0, trail * 6 - 6)
					draw_line(tip + direction * 8.0 + offset, tip + direction * (39.0 - trail * 7) + offset, Color(color, 0.3), 3.0, true)
				if _theme == 1:
					draw_circle(tip, 11.0, Color(color, 0.25), true, -1, true)
					draw_circle(tip, 6.0, color, true, -1, true)
				else:
					_draw_star(tip, 12.0 if count == 1 else 7.0, color)
		2:
			for index in range(8):
				var ray := Vector2.from_angle(index * TAU / 8.0 + sweep)
				draw_line(center + ray * 17.0, center + ray * 36.0, Color(color, 0.55), 2.0, true)
			_draw_star(center, 24.0, color)
		4:
			for index in range(3):
				var radius := 16.0 + index * 10.0
				draw_arc(center, radius, sweep + index, sweep + index + PI * 1.45, 36, Color(color, 0.90 - index * 0.18), 3.0, true)
			_draw_star(center, 9.0, color)
		5:
			for band in range(3):
				var ribbon := PackedVector2Array()
				for x in range(-33, 34, 3):
					ribbon.append(center + Vector2(x, sin(x * 0.075 + sweep + band * 0.4) * 11.0 + band * 9.0 - 7.0))
				draw_polyline(ribbon, Color(color, 0.88 - band * 0.2), 4.0, true)
		6:
			for index in range(2):
				draw_arc(center, 25.0 + index * 10.0, sweep + index, sweep + index + 5.2, 42, Color(color, 0.86 - index * 0.22), 3.0, true)
			draw_circle(center, 17.0, Color("#090b1d"), true, -1, true)


func _draw_star(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(8):
		var length := radius if index % 2 == 0 else radius * 0.30
		points.append(center + Vector2.from_angle(index * TAU / 8.0) * length)
	draw_colored_polygon(points, color)
