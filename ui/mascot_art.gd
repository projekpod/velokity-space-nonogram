extends RefCounted

const INK := Color("#1b2440")
const SEAM := Color("#435975")
const WHITE := Color("#f2fbff")
const MINT := Color("#a5f4df")
const TEAL := Color("#275e72")
const GOLD := Color("#ffd479")
const FUR := Color("#ed9960")
const CARAMEL := Color("#a64d35")
const CREAM := Color("#fff0d4")
const PINK := Color("#f78a91")
const EYE := Color("#252238")

const ENAMEL := [Color("#f8fdff"), Color("#d0e9f4"), Color("#718ab1")]
const GLASS := [Color("#225168"), Color("#203951"), Color("#10253b")]
const COAT := [Color("#ffcf8b"), FUR, Color("#bf6451")]
const CONTOUR := [Color("#96e1e3"), Color("#3b8ea0"), Color("#284960")]

enum Face { HAPPY, PROUD, SURPRISED, SAD, THINKING, SLEEPING, DANCING, CHEERING }

static var _gradients: Dictionary = {}
static var _spark_texture: ImageTexture


static func ellipse(part: CanvasItem, center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(48):
		points.append(center + Vector2.from_angle(index * TAU / 48.0) * radii)
	part.draw_colored_polygon(points, color)
	points.append(points[0])
	part.draw_polyline(points, color, 1.0, true)


static func _lit(part: CanvasItem, center: Vector2, radii: Vector2, palette: Array) -> void:
	var texture: GradientTexture2D = _gradients.get(palette[0])
	if texture == null:
		texture = GradientTexture2D.new()
		texture.width = 64
		texture.height = 64
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.30, 0.25)
		texture.fill_to = Vector2(0.91, 0.95)
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
		gradient.colors = PackedColorArray(palette)
		texture.gradient = gradient
		_gradients[palette[0]] = texture
	var points := PackedVector2Array()
	var uv := PackedVector2Array()
	for index in range(64):
		var normal := Vector2.from_angle(index * TAU / 64.0)
		points.append(center + normal * radii)
		uv.append((normal + Vector2.ONE) * 0.5)
	part.draw_polygon(points, PackedColorArray([Color.WHITE]), uv, texture)


static func _stroke(part: CanvasItem, points: Array, color: Color, width: float) -> void:
	part.draw_polyline(PackedVector2Array(points), color, width, true)
	part.draw_circle(points.front(), width * 0.5, color, true)
	part.draw_circle(points.back(), width * 0.5, color, true)


static func _arc(part: CanvasItem, center: Vector2, radii: Vector2, start: float, end: float, color: Color, width: float) -> void:
	var points := []
	for index in range(25):
		points.append(center + Vector2.from_angle(lerpf(start, end, index / 24.0)) * radii)
	_stroke(part, points, color, width)


static func spark(part: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(8):
		var length := radius if i % 2 == 0 else radius * 0.26
		points.append(center + Vector2.UP.rotated(i * TAU / 8.0) * length)
	part.draw_colored_polygon(points, color)


static func _costume_palette(color: Color, standard: Array) -> Array:
	if color == Color.TRANSPARENT:
		return standard
	return [color.lightened(0.58), color, color.darkened(0.45)]


static func backpack(part: CanvasItem, color := Color.TRANSPARENT) -> void:
	var palette := _costume_palette(color, CONTOUR)
	for side in [-1, 1]:
		var x: float = side * 44.0
		ellipse(part, Vector2(x, 69), Vector2(24, 44), INK)
		_lit(part, Vector2(x, 67), Vector2(20, 37), palette)
		ellipse(part, Vector2(x + side * 3.0, 82), Vector2(17, 24), TEAL)
		_stroke(part, [Vector2(x - 6, 61), Vector2(x + 6, 59)], MINT, 3)
		if color != Color.TRANSPARENT:
			ellipse(part, Vector2(x + side * 16.0, 92), Vector2(9, 19), INK)
			_lit(part, Vector2(x + side * 16.0, 92), Vector2(6, 15), palette)


static func tail(part: CanvasItem, fur_color := FUR, markings := CARAMEL, tip := CREAM) -> void:
	var curve := [
		Vector2.ZERO, Vector2(27, 15), Vector2(48, 11), Vector2(64, -1),
		Vector2(70, -19), Vector2(65, -33), Vector2(54, -34), Vector2(48, -25),
	]
	_stroke(part, curve, INK, 23)
	_stroke(part, curve, fur_color, 16)
	_stroke(part, [Vector2(35, 14), Vector2(44, 12)], markings, 16)
	_stroke(part, [Vector2(64, -3), Vector2(67, -10)], markings, 16)
	_stroke(part, [Vector2(63, -33), Vector2(55, -34), Vector2(48, -25)], tip, 14)


static func arm(part: CanvasItem, color := Color.TRANSPARENT) -> void:
	_stroke(part, [Vector2.ZERO, Vector2(14, 14), Vector2(24, 31)], INK, 29)
	_stroke(part, [Vector2.ZERO, Vector2(14, 14), Vector2(24, 31)], Color("#bccfe9") if color == Color.TRANSPARENT else color, 23)
	_stroke(part, [Vector2(3, 0), Vector2(14, 12), Vector2(20, 23)], WHITE, 14)
	ellipse(part, Vector2(23, 28), Vector2(15, 12), TEAL)
	ellipse(part, Vector2(27, 38), Vector2(17, 15), INK)
	_lit(part, Vector2(27, 36), Vector2(14, 12), _costume_palette(color, ENAMEL))
	ellipse(part, Vector2(16, 31), Vector2(7, 8), Color("#d7eaf3"))


static func holding_arms(part: CanvasItem, color := Color.TRANSPARENT) -> void:
	var palette := _costume_palette(color, ENAMEL)
	for side in [-1, 1]:
		var shoulder := Vector2(side * 43.0, 50)
		var elbow := Vector2(side * 105.0, 29)
		var cuff := Vector2(side * 123.0, -42)
		var paw := Vector2(side * 123.0, -65)
		_stroke(part, [shoulder, elbow, cuff], INK, 29)
		_stroke(part, [shoulder, elbow, cuff], palette[1], 22)
		_stroke(part, [elbow, Vector2(side * 119.0, -33)], palette[0], 9)
		ellipse(part, cuff, Vector2(15, 11), TEAL)
		ellipse(part, paw, Vector2(20, 15), INK)
		_lit(part, paw, Vector2(17, 13), palette)
		for offset in [-7, 0, 7]:
			_stroke(part, [paw + Vector2(offset, -9), paw + Vector2(offset, -4)], Color("#7794ab"), 1.6)


static func boot(part: CanvasItem, color := Color.TRANSPARENT) -> void:
	ellipse(part, Vector2(4, 13), Vector2(27, 23), INK)
	ellipse(part, Vector2(4, 16), Vector2(24, 17), TEAL)
	_lit(part, Vector2(5, 10), Vector2(22, 16), _costume_palette(color, ENAMEL))
	_stroke(part, [Vector2(-4, 10), Vector2(12, 8)], MINT, 4)


static func suit(part: CanvasItem, color := Color.TRANSPARENT) -> void:
	ellipse(part, Vector2(0, 63), Vector2(59, 53), INK)
	_lit(part, Vector2(0, 61), Vector2(55, 49), _costume_palette(color, ENAMEL))
	ellipse(part, Vector2(0, 89), Vector2(51, 18), Color("#9ab2cd"))
	ellipse(part, Vector2(0, 85), Vector2(48, 11), Color("#c7dcec"))
	ellipse(part, Vector2(3, 66), Vector2(27, 20), SEAM)
	_lit(part, Vector2(3, 65), Vector2(24, 17), GLASS)
	spark(part, Vector2(-3, 65), 12, GOLD)
	ellipse(part, Vector2(16, 60), Vector2(3, 3), MINT)
	ellipse(part, Vector2(16, 70), Vector2(3, 3), Color("#86a8ee"))
	ellipse(part, Vector2(0, 32), Vector2(47, 15), TEAL)
	_arc(part, Vector2(0, 32), Vector2(44, 12), 0.15, PI - 0.15, MINT, 3)


static func helmet(part: CanvasItem, color := Color.TRANSPARENT) -> void:
	ellipse(part, Vector2(0, -10), Vector2(101, 88), INK)
	_lit(part, Vector2(0, -12), Vector2(97, 84), _costume_palette(color, ENAMEL))
	ellipse(part, Vector2(1, -6), Vector2(85, 69), SEAM)
	_lit(part, Vector2(0, -9), Vector2(83, 67), CONTOUR)
	_lit(part, Vector2(0, -7), Vector2(77, 62), GLASS)
	for side in [-1, 1]:
		var x: float = side * 95.0
		ellipse(part, Vector2(x, -5), Vector2(12, 24), INK)
		_lit(part, Vector2(x, -5), Vector2(9, 21), CONTOUR)
		_stroke(part, [Vector2(x, -11), Vector2(x, 4)], MINT, 3)
	_arc(part, Vector2(0, -12), Vector2(92, 79), 3.50, 4.18, WHITE, 4)
	_arc(part, Vector2(0, -6), Vector2(82, 66), 0.62, 2.20, MINT, 2)


static func ear(part: CanvasItem, fur_color := FUR, outline := CARAMEL) -> void:
	var shape := [
		Vector2(-21, 27), Vector2(-16, -4), Vector2(-9, -24),
		Vector2(-3, -27), Vector2(6, -24), Vector2(28, 0), Vector2(30, 23),
	]
	part.draw_colored_polygon(PackedVector2Array(shape), outline)
	part.draw_colored_polygon(PackedVector2Array([
		Vector2(-15, 24), Vector2(-11, -2), Vector2(-4, -21),
		Vector2(3, -21), Vector2(23, 2), Vector2(27, 22),
	]), fur_color)
	part.draw_colored_polygon(PackedVector2Array([
		Vector2(-9, 19), Vector2(-5, -4), Vector2(0, -14), Vector2(14, 4), Vector2(21, 19),
	]), Color("#ef9a9b"))


static func fur(part: CanvasItem) -> void:
	ellipse(part, Vector2(0, 5), Vector2(65, 49), CARAMEL)
	_lit(part, Vector2(0, 4), Vector2(63, 47), COAT)
	tabby_muzzle(part, CREAM)
	tabby_markings(part, CARAMEL, Color("#f6af9c"))


static func tabby_muzzle(part: CanvasItem, color: Color) -> void:
	ellipse(part, Vector2(0, 29), Vector2(50, 18), color)
	ellipse(part, Vector2(-26, 24), Vector2(24, 15), color)
	ellipse(part, Vector2(26, 24), Vector2(24, 15), color)


static func tabby_markings(part: CanvasItem, color: Color, blush: Color) -> void:
	for side in [-1, 1]:
		_stroke(part, [Vector2(side * 9, -40), Vector2(side * 5, -29)], color, 4)
		_stroke(part, [Vector2(side * 22, -38), Vector2(side * 17, -32)], color, 3)
		_stroke(part, [Vector2(side * 59, 13), Vector2(side * 50, 16)], color, 3)
		_stroke(part, [Vector2(side * 53, 28), Vector2(side * 45, 27)], color, 2)
		ellipse(part, Vector2(side * 42, 22), Vector2(10, 4), blush)


static func face(part: CanvasItem, expression: Face, gaze: Vector2, eyelid: float, eye_spacing := 25.0, straining := false) -> void:
	for side in [-1, 1]:
		var eye := Vector2(side * eye_spacing, 1)
		_draw_eye(part, eye, side, expression, gaze, eyelid)
	part.draw_colored_polygon(PackedVector2Array([
		Vector2(-7, 21), Vector2(-4, 18), Vector2(4, 18), Vector2(7, 21), Vector2(0, 27),
	]), CARAMEL)
	_stroke(part, [Vector2(-2, 20), Vector2(2, 20)], Color("#f09088"), 2)
	if straining:
		ellipse(part, Vector2(0, 34), Vector2(12, 6), CARAMEL)
		_stroke(part, [Vector2(-7, 33), Vector2(7, 33)], CREAM, 3)
	else:
		_mouth(part, expression)


static func _draw_eye(part: CanvasItem, eye: Vector2, side: int, expression: Face, gaze: Vector2, eyelid: float) -> void:
	if expression == Face.SAD:
		_stroke(part, [eye + Vector2(-8, -14 - side * 3), eye + Vector2(7, -14 + side * 3)], CARAMEL, 3)
	elif expression == Face.SURPRISED:
		_arc(part, eye + Vector2(0, -11), Vector2(9, 6), 3.45, 5.97, CARAMEL, 3)
	elif expression == Face.THINKING:
		_stroke(part, [eye + Vector2(-7, -12 + side * 2), eye + Vector2(7, -15 + side * 2)], CARAMEL, 3)

	if expression == Face.SLEEPING or eyelid < 0.18:
		_arc(part, eye + Vector2(0, 1), Vector2(11, 5), 0.18, PI - 0.18, EYE, 3)
		return
	if expression == Face.CHEERING or (expression == Face.DANCING and side == -1):
		_arc(part, eye + Vector2(0, 5), Vector2(11, 10), 3.30, 6.12, EYE, 4)
		return

	var height := 14.0
	if expression == Face.SURPRISED:
		height = 17.0
	elif expression == Face.PROUD or expression == Face.SAD:
		height = 9.5
	var peek := Vector2(2.5, -2) if expression == Face.THINKING else Vector2.ZERO
	ellipse(part, eye, Vector2(12.5, (height + 1) * eyelid), CREAM)
	ellipse(part, eye + (gaze + peek) * 0.65, Vector2(9.5, height * eyelid), EYE)
	ellipse(part, eye + Vector2(1, 3) + (gaze + peek) * 0.65, Vector2(6.5, 5.0 * eyelid), Color("#326875"))
	ellipse(part, eye + Vector2(-3.5, -4.0 * eyelid) + (gaze + peek) * 0.65, Vector2(3.3, 3.6 * eyelid), WHITE)
	ellipse(part, eye + Vector2(3, 2) + (gaze + peek) * 0.65, Vector2(1.6, 1.6 * eyelid), MINT)


static func _mouth(part: CanvasItem, expression: Face) -> void:
	match expression:
		Face.SURPRISED:
			ellipse(part, Vector2(0, 34), Vector2(7, 9), CARAMEL)
			ellipse(part, Vector2(0, 37), Vector2(4, 3), PINK)
		Face.SAD:
			_arc(part, Vector2(0, 38), Vector2(10, 6), 3.43, 5.99, CARAMEL, 3)
		Face.SLEEPING:
			ellipse(part, Vector2(0, 33), Vector2(4.5, 3.5), CARAMEL)
		Face.THINKING:
			_stroke(part, [Vector2(0, 29), Vector2(6, 32), Vector2(11, 30)], CARAMEL, 3)
		Face.PROUD:
			_arc(part, Vector2(3, 28), Vector2(13, 7), 0.02, 2.65, CARAMEL, 3)
		_:
			part.draw_colored_polygon(PackedVector2Array([
				Vector2(-19, 26), Vector2(-9, 29), Vector2(0, 30), Vector2(9, 29),
				Vector2(19, 26), Vector2(15, 35), Vector2(8, 41), Vector2(0, 43),
				Vector2(-8, 41), Vector2(-15, 35),
			]), CARAMEL)
			ellipse(part, Vector2(0, 38), Vector2(9, 3.6), PINK)
			_stroke(part, [Vector2(-9, 31), Vector2(0, 32), Vector2(9, 31)], CREAM, 2.5)


static func sweat(part: CanvasItem) -> void:
	part.draw_colored_polygon(PackedVector2Array([
		Vector2(50, -27), Vector2(57, -11), Vector2(55, -5),
		Vector2(49, -3), Vector2(44, -8), Vector2(44, -13),
	]), Color("#78d9f7"))
	part.draw_circle(Vector2(49, -10), 2.0, WHITE, true)


static func visor(part: CanvasItem) -> void:
	_arc(part, Vector2(0, -7), Vector2(75, 60), 3.63, 4.18, Color("#b7f2f2a6"), 4)
	_arc(part, Vector2(0, -7), Vector2(75, 60), 4.31, 4.48, Color("#e6fbffb3"), 3)
	_arc(part, Vector2(0, -7), Vector2(75, 60), 0.25, 0.71, Color("#79beca94"), 2)
	ellipse(part, Vector2(62, -34), Vector2(3, 3), Color("#f3fbffb3"))
	_stroke(part, [Vector2(-18, 63), Vector2(15, 63)], WHITE, 3)


static func antenna(part: CanvasItem, color := Color.TRANSPARENT) -> void:
	_stroke(part, [Vector2.ZERO, Vector2(-6, -18), Vector2(-18, -27)], INK, 9)
	_stroke(part, [Vector2.ZERO, Vector2(-6, -18), Vector2(-18, -27)], Color("#9ec6d9"), 4)
	ellipse(part, Vector2(-18, -27), Vector2(11, 11), INK)
	if color == Color.TRANSPARENT:
		ellipse(part, Vector2(-18, -27), Vector2(8, 8), GOLD)
		ellipse(part, Vector2(-21, -30), Vector2(3, 3), CREAM)
	else:
		spark(part, Vector2(-18, -27), 11, color)
		ellipse(part, Vector2(-18, -27), Vector2(3, 3), CREAM)


static func spark_texture() -> ImageTexture:
	if _spark_texture == null:
		var image := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
		for y in range(16):
			for x in range(16):
				var distance := Vector2(absf(x - 7.5), absf(y - 7.5))
				var shape := distance.x * 0.22 + distance.y * 0.22 + minf(distance.x, distance.y) * 0.78
				image.set_pixel(x, y, Color(1, 1, 1, clampf(2.0 - shape, 0.0, 1.0)))
		_spark_texture = ImageTexture.create_from_image(image)
	return _spark_texture
