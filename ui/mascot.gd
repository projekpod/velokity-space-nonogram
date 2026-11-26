extends Control

const CatArt := preload("res://ui/cat_art.gd")
const Cosmetics := preload("res://scripts/meta/cosmetics.gd")
const Art := preload("res://ui/mascot_art.gd")
const Face := Art.Face
const Meta := preload("res://scripts/meta/progression.gd")

enum Reaction { NONE, FILL, MISTAKE, COMBO, WIN }

const POSES := [
	Vector4(0.10, 0.24, 0.01, 0.02),
	Vector4(0.05, 0.58, -0.04, -0.12),
	Vector4(0.76, 0.72, 0.01, 0.00),
	Vector4(-0.16, -0.16, -0.05, 0.15),
	Vector4(0.75, -0.05, 0.04, -0.12),
	Vector4(-0.08, -0.08, 0.11, 0.20),
	Vector4(1.48, 0.50, -0.16, -0.09),
	Vector4(1.55, 1.55, 0.01, 0.00),
]
const REACTION_EXPRESSIONS := [
	Face.HAPPY, Face.HAPPY, Face.SURPRISED, Face.DANCING, Face.CHEERING,
]
const REACTION_SECONDS := [0.0, 0.38, 0.62, 1.0, 1.35]

@onready var _settings := get_node("/root/Settings")

var idle_expression := Face.HAPPY
var preview_outfit: Variant = null
var preview_cat := ""
var preview_skin := ""
var _cat_id: String
var _skin_id: String
var _aura: Node2D
var _legendary := false
var _reduced := false
var _coat: Node2D
var _coat_frame := 0
static var _aura_texture: GradientTexture2D
var _streak_pose := 0
var _reaction := Reaction.NONE
var _expression := Face.HAPPY
var _preview := false
var _calm := false
var _time := 0.0
var _blink_wait := 3.0
var _blink_time := 0.0
var _gaze := Vector2.ZERO
var _eyelid := 1.0
var _spring := Vector3.ZERO
var _spring_speed := Vector3.ZERO
var _progress := 0.0
var _reaction_tween: Tween

var _rig: Node2D
var _body: Node2D
var _head: Node2D
var _tail: Node2D
var _left_arm: Node2D
var _right_arm: Node2D
var _holding_arms: Node2D
var _left_boot: Node2D
var _right_boot: Node2D
var _left_ear: Node2D
var _right_ear: Node2D
var _antenna: Node2D
var _face: Node2D
var _accents: Node2D
var _sparks: CPUParticles2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var economy := get_node("/root/Economy")
	var outfit: Dictionary = economy.equipped_costumes() if preview_outfit == null else preview_outfit
	_cat_id = economy.equipped_cosmetic("cat") if preview_cat.is_empty() else preview_cat
	_skin_id = economy.equipped_cosmetic("skin") if preview_skin.is_empty() else preview_skin
	var breed: Dictionary = CatArt.BREEDS[_cat_id]
	_legendary = Cosmetics.CATS[_cat_id].rarity == Cosmetics.Rarity.LEGENDARY or _skin_id == "gold"
	for id: String in outfit.values():
		_legendary = _legendary or Meta.COSTUMES.get(id, {}).get("rarity") == Cosmetics.Rarity.LEGENDARY
	var suit_color := _outfit_color(outfit, "suit")
	_rig = Node2D.new()
	add_child(_rig)
	if _legendary:
		_aura = _part(_rig, Vector2.ZERO, _draw_aura)
	_body = Node2D.new()
	_rig.add_child(_body)
	_tail = _part(_body, Vector2(45, 75), _draw_tail)
	_part(_body, Vector2.ZERO, Art.backpack, false, _outfit_color(outfit, "jetpack"))
	_left_boot = _part(_body, Vector2(-26, 97), Art.boot, true, suit_color)
	_right_boot = _part(_body, Vector2(23, 97), Art.boot, false, suit_color)
	_left_arm = _part(_body, Vector2(-43, 48), Art.arm, true, suit_color)
	_right_arm = _part(_body, Vector2(43, 48), Art.arm, false, suit_color)
	_part(_body, Vector2.ZERO, Art.suit, false, suit_color)
	_head = _part(_body, Vector2(0, -20), Art.helmet, false, _outfit_color(outfit, "helmet"))
	var ear_pivot: Vector2 = breed.pivot
	_left_ear = _part(_head, Vector2(-ear_pivot.x, ear_pivot.y), _draw_ear)
	_right_ear = _part(_head, ear_pivot, _draw_ear, true)
	_coat = _part(_head, Vector2.ZERO, _draw_coat)
	_face = _part(_head, Vector2.ZERO, _draw_face)
	_part(_head, Vector2.ZERO, Art.visor)
	_antenna = _part(_head, Vector2(-55, -82), Art.antenna, false, _outfit_color(outfit, "accessory"))
	_holding_arms = _part(_body, Vector2.ZERO, Art.holding_arms, false, suit_color)
	_holding_arms.hide()
	_accents = _part(_rig, Vector2.ZERO, _draw_accents)
	_create_sparks()
	resized.connect(_fit)
	var events := get_node("/root/Events")
	events.settings_changed.connect(_refresh_motion)
	events.reduced_effects_enabled.connect(_refresh_motion)
	_refresh_motion()
	_fit()
	set_idle(idle_expression)


static func _outfit_color(outfit: Dictionary, slot: String) -> Color:
	return Meta.COSTUMES.get(outfit.get(slot, ""), {}).get("color", Color.TRANSPARENT)


func _part(parent: Node2D, pivot: Vector2, paint: Callable, mirror := false, color: Variant = null) -> Node2D:
	var part := Node2D.new()
	part.position = pivot
	if mirror:
		part.scale.x = -1.0
	parent.add_child(part)
	if color == null:
		part.draw.connect(paint.bind(part))
	else:
		part.draw.connect(paint.bind(part, color))
	return part


func _fit() -> void:
	_rig.position = size * 0.5
	var ratio := maxf(0.001, minf(size.x / 290.0, size.y / 291.0))
	_rig.scale = Vector2.ONE * ratio


func _create_sparks() -> void:
	_sparks = CPUParticles2D.new()
	_sparks.position = Vector2(0, -39)
	_sparks.texture = Art.spark_texture()
	_sparks.amount = 9
	_sparks.lifetime = 0.55
	_sparks.one_shot = true
	_sparks.explosiveness = 0.85
	_sparks.direction = Vector2.UP
	_sparks.spread = 86
	_sparks.initial_velocity_min = 74.0
	_sparks.initial_velocity_max = 145.0
	_sparks.gravity = Vector2(0, 155)
	_sparks.scale_amount_min = 0.45
	_sparks.scale_amount_max = 0.9
	_sparks.color_ramp = Gradient.new()
	_sparks.color_ramp.colors = PackedColorArray([Art.GOLD, Color(Art.MINT, 0.0)])
	_sparks.emitting = false
	_rig.add_child(_sparks)


func set_idle(expression: Art.Face) -> void:
	idle_expression = expression
	_clear_reaction()
	_apply_pose()


func react(reaction: Reaction) -> void:
	if reaction == Reaction.NONE or _preview:
		return
	if reaction == Reaction.FILL and _reaction != Reaction.NONE:
		return
	_stop_tween()
	_reaction = reaction
	_expression = REACTION_EXPRESSIONS[reaction]
	_progress = 0.0
	_eyelid = 1.0
	_blink_time = 0.0
	_face.queue_redraw()
	var duration: float = REACTION_SECONDS[reaction]
	_reaction_tween = create_tween()
	_reaction_tween.tween_method(_set_progress, 0.0, 1.0, minf(duration, 0.26) if _calm else duration)
	_reaction_tween.finished.connect(_finish_reaction)
	if reaction in [Reaction.COMBO, Reaction.WIN] and not _calm:
		_sparks.restart()
		_sparks.emitting = true


func hold_pose(expression: Art.Face, reaction := Reaction.NONE) -> void:
	_stop_tween()
	_preview = true
	_reaction = reaction
	_expression = expression if reaction == Reaction.NONE else REACTION_EXPRESSIONS[reaction]
	_progress = 0.48
	_gaze = Vector2.ZERO
	_eyelid = 1.0
	_spring = Vector3.ZERO
	_apply_pose()
	_face.queue_redraw()
	_accents.queue_redraw()
	set_process(false)


func set_streak_pose(pose: int) -> void:
	_streak_pose = pose
	_holding_arms.visible = pose == 2
	_left_arm.visible = pose != 2
	_right_arm.visible = pose != 2
	_apply_pose()
	_face.queue_redraw()


func _stop_tween() -> void:
	if _reaction_tween != null:
		_reaction_tween.kill()
		_reaction_tween = null


func _finish_reaction() -> void:
	_reaction_tween = null
	_reaction = Reaction.NONE
	_expression = idle_expression
	_face.queue_redraw()


func _clear_reaction() -> void:
	_stop_tween()
	_finish_reaction()
	_progress = 0.0


func _set_progress(progress: float) -> void:
	_progress = progress


func _refresh_motion() -> void:
	if not is_inside_tree():
		return
	_reduced = get_viewport().get_meta(&"reduced_effects", false)
	_calm = _settings.get_value("calm_mode")
	_sparks.visible = not _calm
	if _calm:
		_sparks.emitting = false
		_spring = Vector3.ZERO
		_spring_speed = Vector3.ZERO
		_gaze = Vector2.ZERO
		_eyelid = 1.0
		_blink_time = 0.0
		_face.queue_redraw()
		if _reaction_tween != null:
			_reaction_tween.set_speed_scale(5.0)


func _process(delta: float) -> void:
	_time += delta
	if not _calm and not _reduced:
		var coat_frame := int(_time * 8.0)
		if _skin_id == "galaxy" and _coat_frame != coat_frame:
			_coat_frame = coat_frame
			_coat.queue_redraw()
		if _legendary:
			_aura.modulate.a = 0.76 + sin(_time * 1.45) * 0.22
	if not _calm:
		_animate_blink(delta)
		var aim := (_rig.get_local_mouse_position() - _head.position).limit_length(160.0) * 0.027
		var gaze := _gaze.lerp(aim, 1.0 - exp(-delta * 12.0))
		if gaze.distance_squared_to(_gaze) > 0.0004:
			_gaze = gaze
			_face.queue_redraw()
		_update_springs(minf(delta, 1.0 / 30.0))
	_apply_pose()


func _animate_blink(delta: float) -> void:
	if _blink_time > 0.0:
		_blink_time = maxf(0.0, _blink_time - delta)
		_eyelid = maxf(0.08, 1.0 - sin(_blink_time / 0.17 * PI))
		_face.queue_redraw()
		return
	_blink_wait -= delta
	if _blink_wait <= 0.0:
		_blink_wait = randf_range(3.2, 6.4)
		_blink_time = 0.17


func _update_springs(step: float) -> void:
	var impulse := sin(_progress * TAU) if _reaction != Reaction.NONE else 0.0
	var target := Vector3(sin(_time * 2.55) * 0.25, sin(_time * 3.25) * 0.065, sin(_time * 2.4) * 0.12)
	target += Vector3(0.24, 0.12, -0.20) * impulse
	_spring_speed += ((target - _spring) * 44.0 - _spring_speed * 8.0) * step
	_spring += _spring_speed * step


func _apply_pose() -> void:
	var pose: Vector4 = POSES[_expression]
	var motion := 0.03 if _calm else 1.0
	var breath := sin(_time * 2.65) * motion
	var bounce := sin(_progress * PI) * motion if _reaction != Reaction.NONE else 0.0
	var dance := sin(_progress * TAU * 1.5) * bounce if _expression == Face.DANCING else 0.0
	var hop := 14.0 if _reaction in [Reaction.COMBO, Reaction.WIN] else 5.0
	if _preview:
		breath = 0.0
		bounce = sin(_progress * PI) if _reaction != Reaction.NONE else 0.0
	_body.position.y = sin(_time * 2.1) * 3.8 * motion - bounce * hop
	_body.rotation = pose.z + motion * sin(_time * 1.8) * 0.018 + dance * 0.16
	_body.position.x = dance * 8.0
	_body.scale = Vector2(1.0 + breath * 0.011 - bounce * 0.076, 1.0 + breath * 0.016 + bounce * 0.092)
	_head.rotation = pose.w + _spring.y - bounce * 0.045
	_left_arm.rotation = pose.x + breath * 0.05 + bounce * 0.22 + dance * 0.24
	_right_arm.rotation = -pose.y - breath * 0.04 - bounce * 0.21 + dance * 0.24
	_left_arm.position = Vector2(-43.0 - maxf(0.0, pose.x - 0.48) * 11.0, 48)
	_right_arm.position = Vector2(43.0 + maxf(0.0, pose.y - 0.48) * 11.0, 48)
	_left_boot.rotation = pose.z * 1.5 - bounce * 0.11
	_right_boot.rotation = -pose.z + bounce * 0.13
	_tail.rotation = _spring.x - pose.z * 1.5
	_left_ear.rotation = _spring.y * 1.6
	_right_ear.rotation = -_spring.y * 1.7
	_antenna.rotation = _spring.z

	if _streak_pose == 1 and not _calm:
		_body.position.x += sin(_time * 25.0) * 1.5
	if _streak_pose == 2:
		_body.position = Vector2.ZERO
		_body.rotation = 0.0
		_body.scale = Vector2.ONE
		_head.rotation = 0.0



func _draw_tail(part: CanvasItem) -> void:
	CatArt.tail(part, _cat_id, _skin_id)


func _draw_ear(part: CanvasItem) -> void:
	CatArt.ear(part, _cat_id, _skin_id)


func _draw_coat(part: CanvasItem) -> void:
	CatArt.fur(part, _cat_id, _skin_id, _coat_frame / 8.0)


func _draw_aura(part: CanvasItem) -> void:
	if _aura_texture == null:
		_aura_texture = GradientTexture2D.new()
		_aura_texture.width = 128
		_aura_texture.height = 128
		_aura_texture.fill = GradientTexture2D.FILL_RADIAL
		_aura_texture.fill_from = Vector2.ONE * 0.5
		_aura_texture.fill_to = Vector2(1, 0.5)
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.60, 0.85, 1.0])
		gradient.colors = PackedColorArray([Color("#ffda7540"), Color("#f1af5270"), Color("#e0a45425"), Color("#ffd88b00")])
		_aura_texture.gradient = gradient
	part.draw_texture_rect(_aura_texture, Rect2(-145, -143, 290, 290), false)
	Art.spark(part, Vector2(-111, -62), 9.0, Art.GOLD)
	Art.spark(part, Vector2(120, 28), 7.0, Art.GOLD)
	Art.spark(part, Vector2(89, 91), 5.0, Art.GOLD)


func _draw_face(part: CanvasItem) -> void:
	var expression := Face.SURPRISED if _streak_pose != 0 and not _calm else _expression
	if _streak_pose == 2 and _calm:
		expression = Face.THINKING
	Art.face(part, expression, _gaze, _eyelid if _streak_pose == 0 else 1.0, CatArt.BREEDS[_cat_id].eyes, _streak_pose == 2 and not _calm)
	if _streak_pose != 0 and not _calm:
		Art.sweat(part)


func _draw_accents(part: CanvasItem) -> void:
	if not _preview or _reaction == Reaction.NONE:
		return
	var points := [Vector2(-112, -61), Vector2(115, -42), Vector2(99, 26)]
	match _reaction:
		Reaction.FILL:
			Art.spark(part, points[1], 15, Art.MINT)
		Reaction.MISTAKE:
			Art.spark(part, points[0], 13, Art.PINK)
			Art.spark(part, points[1], 8, Art.PINK)
		Reaction.COMBO:
			Art.spark(part, points[0], 15, Art.MINT)
			Art.spark(part, points[1], 20, Art.GOLD)
			Art.spark(part, points[2], 9, Art.MINT)
		Reaction.WIN:
			Art.spark(part, points[0], 18, Art.GOLD)
			Art.spark(part, points[1], 21, Art.GOLD)
			Art.spark(part, points[2], 10, Art.MINT)
