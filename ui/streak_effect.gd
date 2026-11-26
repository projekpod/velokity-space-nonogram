extends Node2D

const Mascot := preload("res://ui/mascot.gd")
const Portrait := preload("res://ui/mission_art.gd")
const Board := preload("res://ui/board.gd")
const HOLD := 7
const FIRST_CRACK := 3
const MAX_CRACKS := 12
const HOLD_SIZE := Vector2(155, 155)

var current := 0
var peak := 0
var shown := 0
var last_effect_frame := -1
var last_combo_frame := -1
var _queued_frame := -1
var _cracks: Array[PackedVector2Array] = []
var _last_bounds := Rect2()
var _board: Board
var _intro: Portrait
var _room: Control
var _mascot: Mascot
var _pose := 0.0
var _dip := 0.0
var _alpha := 0.0
var _pulse := 0.0
var _panic := 0.0
var _seal := 0.0
var _holding := false
var _repairing := false
var _calm := false
var _reduced := false
var _motion: Tween

@onready var _audio := get_node("/root/Audio")


func attach(board: Board, intro: Portrait, room: Control) -> void:
	_board = board
	_intro = intro
	_room = room
	_mascot = intro.mascot
	_refresh_motion()
	var events := get_node("/root/Events")
	events.settings_changed.connect(_refresh_motion)
	events.reduced_effects_enabled.connect(_redraw_layout_after_reduction)
	_board.item_rect_changed.connect(_redraw_layout)
	set_process(false)


func _redraw_layout_after_reduction() -> void:
	_refresh_motion()
	_redraw_layout()


func _redraw_layout() -> void:
	if _holding:
		_place_mascot()
	queue_redraw()


func _refresh_motion() -> void:
	if not is_inside_tree():
		return
	_calm = get_node("/root/Settings").get_value("calm_mode")
	_reduced = get_viewport().get_meta(&"reduced_effects", false)
	if _holding and (_calm or _reduced):
		_dip = 0.0


func fill() -> void:
	current += 1
	if current <= peak:
		return
	peak = current
	if peak >= FIRST_CRACK:
		_queued_frame = Engine.get_process_frames()
		set_process(true)


func mistake() -> void:
	current = 0
	if peak >= FIRST_CRACK and shown < peak:
		_reveal(peak, false)


func _process(delta: float) -> void:
	var frame := Engine.get_process_frames()
	_refresh_motion()
	if peak > shown and frame > maxi(_queued_frame, last_combo_frame):
		_reveal(maxi(FIRST_CRACK, shown + 1))
	var panic := _panic > 0.0
	_panic = move_toward(_panic, 0.0, delta)
	if panic and _panic == 0.0 and not _holding:
		_mascot.set_streak_pose(0)
	_pulse = move_toward(_pulse, 0.0, delta * (1.45 if _calm else 2.5))
	_alpha = move_toward(_alpha, 1.0, delta * (1.8 if _calm else 5.0))
	if _holding:
		_place_mascot()
	queue_redraw()
	if not _repairing and shown >= peak and _pulse == 0.0 and _alpha == 1.0 and _panic == 0.0:
		set_process(false)


func _reveal(record: int, transient := true) -> void:
	shown = record
	if transient:
		last_effect_frame = Engine.get_process_frames()
		_pulse = 1.0
		_audio.play_effect(&"crackle" if record < 5 else &"rumble")
		if record >= 4 and not _calm and not _reduced:
			_board.streak_shake(mini(record, HOLD) * 2.0 - 4.0)
		if record >= 4 and record < HOLD:
			_panic = 0.54
			_mascot.set_streak_pose(1)
	if record >= HOLD and not _holding:
		_start_hold(transient)


func _start_hold(animate: bool) -> void:
	_holding = true
	_room.show()
	_mascot.reparent(self, false)
	_mascot.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_mascot.size = HOLD_SIZE
	_mascot.set_streak_pose(2)
	_pose = 1.0 if not animate or _calm or _reduced else 0.0
	if _pose < 1.0:
		_motion = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_motion.tween_property(self, "_pose", 1.0, 0.29)
	_dip = 0.0 if _calm or _reduced else 8.0
	_place_mascot()


func _place_mascot() -> void:
	var portrait := to_local(_intro.get_global_rect().get_center()) - HOLD_SIZE * 0.5
	var bottom := _board.position + Vector2((_board._grid().position.x + _board._grid().end.x) * 0.5, _board._grid().end.y)
	var hold := bottom - Vector2(HOLD_SIZE.x / 2.0, 36.0 - _dip) + _board._shake_offset()
	_mascot.position = portrait.lerp(hold, _pose)
	_board.set_streak_dip(_dip * _pose)


func finish() -> void:
	if peak < FIRST_CRACK:
		return
	_reveal(peak, false)
	_repairing = true
	set_process(true)
	_panic = 0.0
	if not _holding:
		_mascot.set_streak_pose(0)
	if _motion != null:
		_motion.kill()
	_pose = 1.0
	_alpha = 1.0
	var duration := 0.25 if _calm or _reduced else 0.49
	var repair := create_tween().set_parallel()
	repair.tween_property(self, "_seal", 1.0, duration)
	repair.tween_property(self, "_dip", 0.0, duration * 0.7)
	await repair.finished
	if _holding:
		_mascot.set_streak_pose(0)
		_mascot.react(Mascot.Reaction.WIN)
		await get_tree().create_timer(0.18 if _calm or _reduced else 0.28, false).timeout
		_mascot.reparent(_intro, false)
		_mascot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_room.hide()
		_holding = false
		_board.set_streak_dip(0.0)
	shown = 0
	_repairing = false
	set_process(false)
	queue_redraw()


func freeze_at(record: int) -> void:
	current = record
	peak = record
	_reveal(record, false)
	_alpha = 1.0
	_pulse = 0.22
	if _holding:
		_mascot.hold_pose(Mascot.Face.SURPRISED)
		_place_mascot()
	set_process(false)
	queue_redraw()


func _draw() -> void:
	if shown < FIRST_CRACK:
		return
	var bounds := _board.get_rect()
	if bounds != _last_bounds:
		_last_bounds = bounds
		_build_cracks(bounds)
	var count := mini(MAX_CRACKS, 2 + (shown - FIRST_CRACK) * 2)
	if _reduced:
		count = mini(count, 6)
	var intensity := clampf((shown - 4) * 0.28, 0.0, 1.0)
	var opacity := _alpha * (1.0 - _seal)
	var light := Color("#91e8ff").lerp(Color("#bdfbe5"), sin(_seal * PI))
	for index in range(count):
		var path := _cracks[index]
		var core := Color("#748db3").lerp(light, intensity)
		draw_polyline(path, Color(core, opacity * (0.48 + 0.3 * intensity)), 1.2 + intensity * 1.7, true)
		if not _reduced and (intensity > 0.0 or _seal > 0.0):
			var glow := opacity * (0.09 + 0.14 * _pulse + sin(_seal * PI) * 0.28)
			draw_polyline(path, Color(light, glow), 6.0 + intensity * 5.0, true)


func _build_cracks(bounds: Rect2) -> void:
	_cracks.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 71207
	for index in range(MAX_CRACKS):
		var top := index % 2 == 0
		var side := -1.0 if index % 4 < 2 else 1.0
		var direction := -1.0 if top else 1.0
		var corner := Vector2(bounds.get_center().x + side * bounds.size.x * rng.randf_range(0.25, 0.48), bounds.position.y if top else bounds.end.y)
		var points := PackedVector2Array([corner + Vector2(0, direction * 9.0)])
		for step in range(1, 7):
			var spread := step * rng.randf_range(14.0, 34.0) * (side if index < 4 else -side)
			points.append(corner + Vector2(spread + rng.randf_range(-34, 34), direction * (10 + step * rng.randf_range(18.0, 25.0))))
		_cracks.append(points)
