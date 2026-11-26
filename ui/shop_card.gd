extends PanelContainer

const Art := preload("res://ui/mascot_art.gd")
const Cosmetics := preload("res://scripts/meta/cosmetics.gd")
const Rarity := Cosmetics.Rarity

var rarity: int = Rarity.COMMON
var padding := 10.0
var _shine: Control
var _phase := 0.0
var _step := -1
var _calm := false


func _ready() -> void:
	var border: Color = Cosmetics.FRAME_COLORS[rarity]
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#152239").lerp(border, 0.11 if rarity >= Rarity.EPIC else 0.03)
	style.border_color = border
	style.set_border_width_all(2 if rarity >= Rarity.RARE else 1)
	style.set_corner_radius_all(13)
	style.set_content_margin_all(padding)
	if rarity == Rarity.LEGENDARY:
		style.shadow_color = Color(border, 0.20)
		style.shadow_size = 7
	add_theme_stylebox_override("panel", style)
	if rarity >= Rarity.EPIC:
		_shine = Control.new()
		_shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shine.draw.connect(_draw_shine)
		_shine.resized.connect(_shine.queue_redraw)
		add_child(_shine, false, Node.INTERNAL_MODE_BACK)
		var events := get_node("/root/Events")
		events.settings_changed.connect(_refresh_motion)
		events.reduced_effects_enabled.connect(_refresh_motion)
		_refresh_motion()
	else:
		set_process(false)


func _refresh_motion() -> void:
	if not is_inside_tree():
		return
	_calm = get_node("/root/Settings").get_value("calm_mode") or get_viewport().get_meta(&"reduced_effects", false)
	if _calm:
		_phase = 3.0
	set_process(not _calm)
	_shine.queue_redraw()


func _process(delta: float) -> void:
	_phase = fmod(_phase + delta, 5.7)
	var step := int(_phase * 12.0)
	if step != _step:
		_step = step
		_shine.queue_redraw()


func _draw_shine() -> void:
	var edge := _shine.size
	if edge.x < 40.0 or edge.y < 20.0:
		return
	var color: Color = Cosmetics.FRAME_COLORS[rarity]
	var progress := clampf(_phase / 2.4, 0.0, 1.0)
	if progress < 1.0:
		var left := edge.x * lerpf(0.08, 0.82, progress)
		var width := minf(46.0, edge.x * 0.16)
		_shine.draw_colored_polygon(PackedVector2Array([
			Vector2(left, 1), Vector2(left + width, 1),
			Vector2(left + width * 0.40, edge.y - 1), Vector2(maxf(1, left - width * 0.60), edge.y - 1),
		]), Color(color, sin(progress * PI) * 0.18))
	if rarity == Rarity.LEGENDARY:
		var intensity := 0.6 + sin(_phase * TAU / 5.7) * 0.38
		Art.spark(_shine, Vector2(edge.x - 16, 13), 5.5, Color(color, intensity))
		Art.spark(_shine, Vector2(11, edge.y - 12), 4.0, Color(color, intensity * 0.77))
