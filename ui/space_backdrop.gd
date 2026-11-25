extends Control

const Art := preload("res://ui/mascot_art.gd")

const STAR_COUNTS := [96, 54, 24]
const DEPTH := [0.26, 0.61, 1.0]
const SHADES := [Color("#364a75"), Color("#6a80ae"), Color("#adcaea")]

@onready var _settings := get_node("/root/Settings")

var _layers: Array[Node2D] = []
var _violet: GradientTexture2D
var _teal: GradientTexture2D
var _time := 0.0
var _aim := Vector2.ZERO
var _calm := false


func _ready() -> void:
	_violet = _nebula(Color("#342f596a"))
	_teal = _nebula(Color("#1b596044"))
	for depth in range(DEPTH.size()):
		var layer := Node2D.new()
		add_child(layer)
		_layers.append(layer)
		layer.draw.connect(_draw_stars.bind(layer, depth))
	resized.connect(_redraw)
	get_node("/root/Events").settings_changed.connect(_refresh_motion)
	_refresh_motion()


func _nebula(color: Color) -> GradientTexture2D:
	var texture := GradientTexture2D.new()
	texture.width = 192
	texture.height = 192
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1, 0.5)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.48, 1.0])
	gradient.colors = PackedColorArray([color, Color(color, color.a * 0.56), Color(color, 0.0)])
	texture.gradient = gradient
	return texture


func _redraw() -> void:
	queue_redraw()
	for layer in _layers:
		layer.queue_redraw()


func _refresh_motion() -> void:
	_calm = _settings.get_value("calm_mode")
	if _calm:
		_aim = Vector2.ZERO
		for layer in _layers:
			layer.position = Vector2.ZERO
	set_process(not _calm)


func _process(delta: float) -> void:
	_time += delta
	var pointer := ((get_local_mouse_position() - size * 0.5) / size.max(Vector2.ONE)).limit_length(0.7)
	_aim = _aim.lerp(pointer, 1.0 - exp(-delta * 3.0))
	for depth in range(_layers.size()):
		var drift := Vector2(sin(_time * 0.23 + depth), sin(_time * 0.32 + depth)) * 7.0
		_layers[depth].position = (drift - _aim * 38.0) * DEPTH[depth]


func _draw() -> void:
	if _violet == null or _teal == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("#0c1224"))
	draw_texture_rect(_violet, Rect2(size * Vector2(-0.45, -0.22), size * Vector2(1.42, 1.06)), false)
	draw_texture_rect(_teal, Rect2(size * Vector2(0.17, 0.20), size * Vector2(1.02, 0.96)), false)


func _draw_stars(layer: Node2D, depth: int) -> void:
	var bounds := size + Vector2.ONE * 76.0
	var color: Color = SHADES[depth]
	for index in range(STAR_COUNTS[depth]):
		var seed := index + depth * 139
		var fraction := Vector2(fposmod(seed * 0.6180339887, 1.0), fposmod(seed * 0.4142135624 + 0.1, 1.0))
		var point := fraction * bounds - Vector2.ONE * 38.0
		var radius := (0.85 + (index % 4) * 0.29) * (0.72 + depth * 0.29)
		layer.draw_circle(point, radius, color, true)
		if depth == 2 and index % 6 == 0:
			Art.spark(layer, point, radius * 3.2, Color(color, 0.63))
