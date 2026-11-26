extends Control

const Art := preload("res://ui/mascot_art.gd")

const STAR_COUNTS := [96, 54, 24]
const DEPTH := [0.26, 0.61, 1.0]
const SHADES := [Color("#364a75"), Color("#6a80ae"), Color("#adcaea")]
const FRAME_LIMIT := 0.020
const SAMPLE_SECONDS := 0.5
const SLOW_SECONDS := 3.0
const PARTICLES := 10
const DURATIONS := [1.15, 3.8, 2.15]

enum Event { SHOOTING_STAR, COMET, COLLISION }

@onready var _settings := get_node("/root/Settings")
@onready var _events := get_node("/root/Events")

var _layers: Array[Node2D] = []
var _twinkles: Array[Node2D] = []
var _sky: Node2D
var _planets: Node2D
var _effects: Node2D
var _violet: GradientTexture2D
var _teal: GradientTexture2D
var _glow: GradientTexture2D
var _timer: Array[float] = [0.0, 0.0, 0.0]
var _active: Array[Dictionary] = [{}, {}, {}]
var _time := 0.0
var _aim := Vector2.ZERO
var _calm := false
var _reduced := false
var _frozen := false
var _last_frame_usec := 0
var _frame_samples := 0
var _sample_time := 0.0
var _slow_time := 0.0


func _ready() -> void:
	_violet = _nebula(Color("#51376980"))
	_teal = _nebula(Color("#24666e57"))
	_glow = _nebula(Color("#b9baff72"))
	_sky = _layer(_draw_nebulae)
	for depth in range(DEPTH.size()):
		var layer := Node2D.new()
		add_child(layer)
		_layers.append(layer)
		layer.draw.connect(_draw_stars.bind(layer, depth))
	for group in range(3):
		var layer := Node2D.new()
		_layers.back().add_child(layer)
		_twinkles.append(layer)
		layer.draw.connect(_draw_twinkles.bind(layer, group))
	_planets = _layer(_draw_planets)
	_effects = _layer(_draw_events)
	resized.connect(_redraw)
	_events.settings_changed.connect(_refresh_motion)
	for kind in range(DURATIONS.size()):
		_schedule(kind)
	_refresh_motion()


func _layer(paint: Callable) -> Node2D:
	var layer := Node2D.new()
	add_child(layer)
	layer.draw.connect(paint)
	return layer


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
	for layer: Node2D in _layers + _twinkles + [_sky, _planets, _effects]:
		layer.queue_redraw()


func _refresh_motion() -> void:
	_calm = _settings.get_value("calm_mode")
	if _calm:
		_aim = Vector2.ZERO
		for layer in _layers:
			layer.position = Vector2.ZERO
		_sky.position = Vector2.ZERO
		_planets.position = Vector2.ZERO
		_clear_events()


func _clear_events() -> void:
	for kind in range(_active.size()):
		_active[kind].clear()
		_schedule(kind)
	_effects.queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		_last_frame_usec = 0
		_frame_samples = 0
		_sample_time = 0.0
		_slow_time = 0.0


func _process(delta: float) -> void:
	if _frozen:
		return
	if not _reduced:
		var now := Time.get_ticks_usec()
		if _last_frame_usec > 0:
			_watch_frame_time(float(now - _last_frame_usec) / 1000000.0)
		_last_frame_usec = now
	_time += delta
	for group in range(_twinkles.size()):
		var rate := 0.56 + group * 0.10 if _calm or _reduced else 1.1 + group * 0.22
		_twinkles[group].modulate.a = 0.55 + sin(_time * rate + group * 2.1) * 0.31
	if _calm or _reduced:
		return
	var pointer := ((get_local_mouse_position() - size * 0.5) / size.max(Vector2.ONE)).limit_length(0.7)
	_aim = _aim.lerp(pointer, 1.0 - exp(-delta * 3.0))
	for depth in range(_layers.size()):
		var drift := Vector2(sin(_time * 0.23 + depth), sin(_time * 0.32 + depth)) * 7.0
		_layers[depth].position = (drift - _aim * 38.0) * DEPTH[depth]
	_sky.position = Vector2(sin(_time * 0.035), cos(_time * 0.041)) * Vector2(45, 29)
	_planets.position = Vector2(cos(_time * 0.074), sin(_time * 0.053)) * Vector2(14, 22)
	_update_events(delta)


func _watch_frame_time(delta: float) -> void:
	if _reduced:
		return
	_sample_time += delta
	_frame_samples += 1
	if _sample_time < SAMPLE_SECONDS:
		return
	if _sample_time / float(_frame_samples) > FRAME_LIMIT:
		_slow_time += _sample_time
	else:
		_slow_time = 0.0
	_sample_time = 0.0
	_frame_samples = 0
	if _slow_time >= SLOW_SECONDS:
		_reduced = true
		get_viewport().set_meta(&"reduced_effects", true)
		_clear_events()
		_events.reduced_effects_enabled.emit()


func _schedule(kind: int) -> void:
	match kind:
		Event.SHOOTING_STAR:
			_timer[kind] = randf_range(6.0, 15.0)
		Event.COMET:
			_timer[kind] = randf_range(25.0, 47.0)
		Event.COLLISION:
			_timer[kind] = randf_range(32.0, 62.0)


func _update_events(delta: float) -> void:
	var redraw := false
	for kind in range(_active.size()):
		if not _active[kind].is_empty():
			_active[kind].age += delta
			if _active[kind].age >= DURATIONS[kind]:
				_active[kind].clear()
			redraw = true
		_timer[kind] -= delta
		if _timer[kind] <= 0.0:
			_active[kind] = _new_event()
			_schedule(kind)
			redraw = true
	if redraw:
		_effects.queue_redraw()


func _new_event() -> Dictionary:
	# Horizontal bands keep the whole path, including trails, away from the central board.
	var top := randf() < 0.5
	var start := Vector2(randf_range(0.12, 0.30), randf_range(0.05, 0.13) if top else randf_range(0.83, 0.91))
	var travel := Vector2(randf_range(0.35, 0.54), randf_range(0.018, 0.045))
	if randf() < 0.5:
		start.x = 1.0 - start.x
		travel.x = -travel.x
	return {"start": start, "travel": travel, "age": 0.0, "angle": randf_range(0.0, TAU)}


func freeze_at_events() -> void:
	_frozen = true
	_active[Event.SHOOTING_STAR] = {"start": Vector2(0.12, 0.065), "travel": Vector2(0.56, 0.075), "age": 0.64, "angle": 0.0}
	_active[Event.COMET] = {"start": Vector2(0.12, 0.80), "travel": Vector2(0.65, 0.108), "age": 2.25, "angle": 0.0}
	_active[Event.COLLISION] = {"start": Vector2(0.69, 0.28), "travel": Vector2(0.24, 0.04), "age": 1.23, "angle": 0.57}
	_effects.queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#0c1224"))


func _draw_nebulae() -> void:
	_sky.draw_texture_rect(_violet, Rect2(size * Vector2(-0.46, -0.21), size * Vector2(1.43, 1.08)), false)
	_sky.draw_texture_rect(_teal, Rect2(size * Vector2(0.17, 0.26), size * Vector2(1.00, 0.96)), false)
	_sky.draw_texture_rect(_violet, Rect2(size * Vector2(0.61, 0.64), size * Vector2(0.66, 0.47)), false)


func _draw_stars(layer: Node2D, depth: int) -> void:
	var bounds := size + Vector2.ONE * 76.0
	var color: Color = SHADES[depth]
	for index in range(STAR_COUNTS[depth]):
		var seed := index + depth * 139
		var fraction := Vector2(fposmod(seed * 0.6180339887, 1.0), fposmod(seed * 0.4142135624 + 0.1, 1.0))
		var point := fraction * bounds - Vector2.ONE * 38.0
		var radius := (0.85 + (index % 4) * 0.29) * (0.72 + depth * 0.29)
		layer.draw_circle(point, radius, color)


func _draw_twinkles(layer: Node2D, group: int) -> void:
	for index in range(6):
		var seed := float(group * 6 + index + 17)
		var point := size * Vector2(fposmod(seed * 0.64421, 1.0), fposmod(seed * 0.36261, 1.0))
		Art.spark(layer, point, 3.0 + float(index % 3) * 1.35, Color("#d6ddfa"))


func _draw_planets() -> void:
	var scale_factor := minf(size.x / 720.0, size.y / 1280.0)
	var large := size * Vector2(0.81, 0.75)
	var radius := 55.0 * scale_factor
	_planets.draw_set_transform(large, -0.32, Vector2(1.0, 0.36))
	_planets.draw_arc(Vector2.ZERO, radius * 1.65, PI, TAU, 34, Color("#797bb078"), 2.8, true)
	_planets.draw_set_transform(Vector2.ZERO)
	_planets.draw_circle(large, radius, Color("#283c61"), true, -1, true)
	_planets.draw_circle(large + Vector2(-radius * 0.12, -radius * 0.05), radius * 0.87, Color("#3e5479"), true, -1, true)
	_planets.draw_circle(large + Vector2(-radius * 0.33, -radius * 0.21), radius * 0.22, Color("#435d80"), true, -1, true)
	_planets.draw_set_transform(large, -0.32, Vector2(1.0, 0.36))
	_planets.draw_arc(Vector2.ZERO, radius * 1.65, 0, PI, 34, Color("#9198c6a0"), 2.8, true)
	_planets.draw_arc(Vector2.ZERO, radius * 1.84, 0, PI, 34, Color("#6179a268"), 1.4, true)
	_planets.draw_set_transform(Vector2.ZERO)
	var small := size * Vector2(0.11, 0.36)
	_planets.draw_circle(small, 24.0 * scale_factor, Color("#493a65"), true, -1, true)
	_planets.draw_circle(small - Vector2.ONE * 3.0 * scale_factor, 19.0 * scale_factor, Color("#635477"), true, -1, true)
	_planets.draw_circle(small + Vector2(31, -26) * scale_factor, 6.0 * scale_factor, Color("#62668c"), true)


func _draw_events() -> void:
	for kind in range(_active.size()):
		var event := _active[kind]
		if event.is_empty():
			continue
		var start: Vector2 = event.start * size
		var travel: Vector2 = event.travel * size
		var progress := clampf(event.age / DURATIONS[kind], 0.0, 1.0)
		if kind == Event.COLLISION:
			_draw_collision(event, start + travel * 0.5, progress)
		else:
			_draw_flyby(kind, start + travel * progress, travel.normalized(), progress)


func _draw_flyby(kind: int, point: Vector2, direction: Vector2, progress: float) -> void:
	var comet := kind == Event.COMET
	var length := 136.0 if comet else 66.0
	var alpha := sin(progress * PI) * (0.82 if comet else 0.74)
	var color := Color("#8ee3de") if comet else Color("#c0d5ff")
	var width := 5.2 if comet else 1.6
	for segment in range(5):
		var section := (point - direction * length * segment / 5.0)
		var tail := point - direction * length * (segment + 1) / 5.0
		_effects.draw_line(section, tail, Color(color, alpha * (5 - segment) / 7.0), width * (5 - segment) / 5.0, true)
		if comet:
			_effects.draw_line(section, tail + Vector2(0, 5 + segment), Color(color, alpha * 0.16), 1.8, true)
	_effects.draw_circle(point, 4.0 if comet else 2.5, Color(color.lightened(0.3), alpha), true, -1, true)


func _draw_collision(event: Dictionary, center: Vector2, progress: float) -> void:
	if progress < 0.42:
		var radius := lerpf(43, 0, progress / 0.42)
		for side in [-1, 1]:
			var point: Vector2 = center + Vector2.from_angle(event.angle) * radius * side
			Art.spark(_effects, point, 5.2, Color("#b9cffa"))
		return
	var age := (progress - 0.42) / 0.58
	var alpha := sin(age * PI) * (1.0 - age * 0.45)
	var glow_size := lerpf(24, 108, age)
	_effects.draw_texture_rect(_glow, Rect2(center - Vector2.ONE * glow_size * 0.5, Vector2.ONE * glow_size), false, Color(1, 1, 1, alpha))
	for index in range(PARTICLES):
		var angle: float = event.angle + index * TAU / PARTICLES
		var point := center + Vector2.from_angle(angle) * age * (26 + (index % 4) * 8)
		_effects.draw_circle(point, 1.0 + float(index % 3) * 0.6, Color(Color("#c9c0ff"), alpha * 0.88), true)
