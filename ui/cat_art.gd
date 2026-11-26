extends RefCounted

const Art := preload("res://ui/mascot_art.gd")
const Cosmetics := preload("res://scripts/meta/cosmetics.gd")
const BREEDS := {
	"velokity": {"face": Vector2(65, 49), "ear": Vector2(1.0, 1.0), "pivot": Vector2(37, -33), "eyes": 25.0, "tail": Vector2(1.0, 1.0), "thickness": 16.0},
	"british_shorthair": {"face": Vector2(69, 49), "ear": Vector2(0.79, 0.66), "pivot": Vector2(44, -33), "eyes": 28.0, "tail": Vector2(0.88, 0.67), "thickness": 24.0},
	"siamese": {"face": Vector2(52, 49), "ear": Vector2(0.89, 1.20), "pivot": Vector2(36, -31), "eyes": 22.0, "tail": Vector2(1.12, 1.3), "thickness": 10.0},
	"sphynx": {"face": Vector2(51, 42), "ear": Vector2(1.13, 1.24), "pivot": Vector2(38, -28), "eyes": 25.5, "tail": Vector2(1.03, 1.36), "thickness": 7.5},
	"devon_rex": {"face": Vector2(53, 39), "ear": Vector2(1.18, 0.94), "pivot": Vector2(48, -23), "eyes": 24.0, "tail": Vector2(1.15, 0.79), "thickness": 12.0},
	"persian": {"face": Vector2(67, 45), "ear": Vector2(0.69, 0.65), "pivot": Vector2(41, -34), "eyes": 23.0, "tail": Vector2(0.85, 0.75), "thickness": 33.0},
	"ragdoll": {"face": Vector2(59, 46), "ear": Vector2(0.85, 0.83), "pivot": Vector2(42, -36), "eyes": 25.5, "tail": Vector2(1.0, 1.13), "thickness": 27.0},
	"bengal": {"face": Vector2(62, 42), "ear": Vector2(0.82, 0.78), "pivot": Vector2(43, -31), "eyes": 25.0, "tail": Vector2(1.08, 1.06), "thickness": 19.0},
	"maine_coon": {"face": Vector2(64, 49), "ear": Vector2(0.98, 1.08), "pivot": Vector2(41, -36), "eyes": 27.0, "tail": Vector2(1.05, 1.19), "thickness": 33.0},
	"savannah": {"face": Vector2(52, 44), "ear": Vector2(1.0, 1.24), "pivot": Vector2(36, -34), "eyes": 22.0, "tail": Vector2(1.10, 1.35), "thickness": 13.0},
}
const ROUND_EAR := [Vector2(-23, 25), Vector2(-20, -8), Vector2(-16, -20), Vector2(-8, -25), Vector2(3, -25), Vector2(15, -20), Vector2(25, -8), Vector2(29, 24)]
const POINTED_EAR := [Vector2(-22, 25), Vector2(-18, 0), Vector2(-12, -29), Vector2(-7, -28), Vector2(15, -12), Vector2(29, 3), Vector2(30, 25)]
const BAT_EAR := [Vector2(-24, 23), Vector2(-30, 2), Vector2(-28, -22), Vector2(-18, -25), Vector2(3, -21), Vector2(22, -11), Vector2(34, 7), Vector2(31, 25)]

static var _galaxy: ImageTexture


static func palette(breed: String, skin: String) -> Array[Color]:
	var base: Color = Cosmetics.CATS[breed].color if skin == Cosmetics.DEFAULT_SKIN else Cosmetics.SKINS[skin].color
	var markings := base.darkened(0.27)
	var muzzle := base.lightened(0.45)
	if skin == Cosmetics.DEFAULT_SKIN:
		match breed:
			"velokity":
				markings = Art.CARAMEL
				muzzle = Art.CREAM
			"siamese":
				markings = Color("#6b454c")
			"ragdoll":
				markings = Color("#927b8e")
			"sphynx":
				muzzle = base.lightened(0.12)
	elif skin in ["calico", "tuxedo"]:
		markings = Color("#583e51")
		muzzle = Color("#fff5df")
	elif skin == "black":
		markings = base.lightened(0.19)
	elif skin == "galaxy":
		markings = Color("#54416e")
		muzzle = Color("#c8b1e8")
	return [base, markings, muzzle]


static func ear(part: CanvasItem, breed: String, skin: String) -> void:
	if breed == Cosmetics.DEFAULT_CAT and skin == Cosmetics.DEFAULT_SKIN:
		Art.ear(part)
		return
	var coat := palette(breed, skin)
	var shape := POINTED_EAR
	if breed in ["british_shorthair", "persian", "bengal", "savannah"]:
		shape = ROUND_EAR
	elif breed in ["devon_rex", "sphynx"]:
		shape = BAT_EAR
	var scale_factor: Vector2 = BREEDS[breed].ear
	var points := PackedVector2Array()
	var inside := PackedVector2Array()
	for point: Vector2 in shape:
		points.append(point * scale_factor)
		inside.append(point * scale_factor * Vector2(0.72, 0.74) + Vector2(2, 3))
	part.draw_colored_polygon(points, coat[0].darkened(0.13))
	part.draw_colored_polygon(inside, coat[0].lerp(Color("#dc919d"), 0.68))
	if breed == "maine_coon":
		part.draw_colored_polygon(PackedVector2Array([Vector2(-16, -18), Vector2(-17, -42), Vector2(-5, -27), Vector2(8, -20)]), coat[1])


static func tail(part: CanvasItem, breed: String, skin: String) -> void:
	if breed == Cosmetics.DEFAULT_CAT and skin == Cosmetics.DEFAULT_SKIN:
		Art.tail(part)
		return
	var coat := palette(breed, skin)
	var shape := PackedVector2Array([
		Vector2.ZERO, Vector2(25, 13), Vector2(41, 11), Vector2(56, 3),
		Vector2(62, -12), Vector2(58, -27), Vector2(48, -32),
	])
	var variation: Vector2 = BREEDS[breed].tail
	for index in range(shape.size()):
		shape[index] *= variation
	if breed in ["persian", "maine_coon", "ragdoll"]:
		shape[6] += Vector2(7, -10)
	elif breed in ["savannah", "siamese", "sphynx"]:
		shape[6] += Vector2(-8, -7)
	var width: float = BREEDS[breed].thickness
	Art._stroke(part, Array(shape), Art.INK, width + 5.0)
	Art._stroke(part, Array(shape), coat[0], width)
	if breed in ["velokity", "bengal", "savannah", "maine_coon"]:
		Art._stroke(part, Array(shape.slice(2, 3)) + [shape[2].lerp(shape[3], 0.5)], coat[1], width * 0.95)
	Art._stroke(part, Array(shape.slice(5)), coat[1], width * (0.7 if width > 22.0 else 1.0))


static func fur(part: CanvasItem, breed: String, skin: String, time: float) -> void:
	if breed == Cosmetics.DEFAULT_CAT and skin == Cosmetics.DEFAULT_SKIN:
		Art.fur(part)
		return
	var coat := palette(breed, skin)
	var radii: Vector2 = BREEDS[breed].face
	var center := Vector2(0, 5)
	if breed in ["persian", "ragdoll", "maine_coon"]:
		_mane(part, breed, radii, coat[0])
	Art.ellipse(part, center, radii + Vector2.ONE, coat[0].darkened(0.39))
	Art._lit(part, center, radii, [coat[0].lightened(0.37), coat[0], coat[0].darkened(0.31)])
	if skin == "galaxy":
		_galaxy_fur(part, center, radii, time)
	if skin == "calico":
		Art.ellipse(part, Vector2(-radii.x * 0.56, -10), Vector2(18, 16), Color("#bd764d"))
		Art.ellipse(part, Vector2(radii.x * 0.70, 9), Vector2(12, 16), Color("#584755"))
	var muzzle := Vector2(32, 13) if breed in ["siamese", "sphynx", "savannah"] else Vector2(43, 14)
	Art.ellipse(part, Vector2(0, 28), muzzle, coat[2])
	_markings(part, breed, coat[1], radii)


static func _mane(part: CanvasItem, breed: String, radii: Vector2, base: Color) -> void:
	var length := 12.0 if breed == "persian" else 18.0 if breed == "maine_coon" else 8.0
	for side in [-1, 1]:
		var shape := [
			Vector2(26, -25), Vector2(radii.x * 0.91, -16), Vector2(radii.x + 8, -2),
			Vector2(radii.x - 1, 9), Vector2(radii.x + 7, 20), Vector2(radii.x - 7, 23),
			Vector2(radii.x - 2, 39), Vector2(radii.x - 23, 35), Vector2(22, 42 + length),
			Vector2(0, 47 + length * 0.45), Vector2(0, -17),
		]
		var points := PackedVector2Array()
		for point: Vector2 in shape:
			points.append(Vector2(point.x * side, point.y))
		part.draw_colored_polygon(points, base.lightened(0.22 if side == -1 else 0.12))


static func _markings(part: CanvasItem, breed: String, ink: Color, radii: Vector2) -> void:
	match breed:
		"siamese":
			Art.ellipse(part, Vector2(0, 21), Vector2(31, 20), ink)
		"ragdoll":
			for side in [-1, 1]:
				Art.ellipse(part, Vector2(side * 30.0, 0), Vector2(23, 27), Color(ink, 0.72))
		"sphynx":
			for index in range(3):
				Art._arc(part, Vector2(0, -18 + index * 6), Vector2(24 - index * 4, 7), 3.3, 6.1, Color(ink, 0.64), 2)
		"devon_rex":
			for side in [-1, 1]:
				Art._arc(part, Vector2(side * 29.0, -22), Vector2(12, 9), 3.45, 5.65, ink, 3)
				Art._stroke(part, [Vector2(side * 44.0, 20), Vector2(side * 37.0, 17)], ink, 2)
		"bengal", "savannah":
			for side in [-1, 1]:
				for index in range(3):
					var point := Vector2(side * (radii.x - 10 - index * 4), -10 + index * 13)
					var spot := Vector2(4.0 if breed == "savannah" else 6.0, 2.7 + index * 0.7)
					Art.ellipse(part, point, spot, ink)
					if breed == "bengal":
						Art.ellipse(part, point + Vector2(side, -0.6), spot * 0.51, ink.lightened(0.31))
			if breed == "savannah":
				for side in [-1, 1]:
					Art._stroke(part, [Vector2(side * 13.0, 5), Vector2(side * 9.0, 16)], ink, 3.2)
		"british_shorthair", "persian":
			for side in [-1, 1]:
				for index in range(3):
					part.draw_circle(Vector2(side * (32.0 + index * 4.2), 20 + (index % 2) * 4), 1.6, ink)
		_:
			for side in [-1, 1]:
				Art._stroke(part, [Vector2(side * 12.0, -39), Vector2(side * 5.0, -27)], ink, 4)
				Art._stroke(part, [Vector2(side * (radii.x - 4), 10), Vector2(side * (radii.x - 16), 15)], ink, 3)
				if breed == "maine_coon":
					Art._stroke(part, [Vector2(side * 49.0, 24), Vector2(side * 39.0, 26)], ink, 3)


static func _galaxy_fur(part: CanvasItem, center: Vector2, radii: Vector2, time: float) -> void:
	if _galaxy == null:
		var image := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
		for y in range(64):
			for x in range(64):
				var offset := Vector2(x, y) * TAU / 64.0
				var vein := sin(offset.x * 2.0 + sin(offset.y) * 2.2) * cos(offset.y)
				var cloud := Color("#364579").lerp(Color("#ca80bb"), 0.5 + 0.47 * vein)
				if (x * 71 + y * 43 + x * y * 7) % 257 == 0:
					cloud = Color("#e6d2ee")
				image.set_pixel(x, y, cloud)
		_galaxy = ImageTexture.create_from_image(image)
	part.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var points := PackedVector2Array()
	var uv := PackedVector2Array()
	for index in range(40):
		var normal := Vector2.from_angle(index * TAU / 40.0)
		points.append(center + normal * radii)
		uv.append((normal + Vector2.ONE) * 0.5 + Vector2(time * 0.022, time * 0.011))
	part.draw_polygon(points, PackedColorArray([Color(1, 1, 1, 0.92)]), uv, _galaxy)
