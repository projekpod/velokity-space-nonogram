extends Control

const RINGS := Color("#425776")
const TILE := Color("#263951")
const MINT := Color("#93f2e4")
const GOLD := Color("#ffcf82")
const PIXELS := [
	"...c...",
	"..ccc..",
	".cacc..",
	"cccaacc",
	".accc..",
	"..c....",
	".c.....",
]


func _ready() -> void:
	custom_minimum_size.y = 358


func _draw() -> void:
	var middle := size * 0.5
	for radius in [126.0, 157.0, 177.0]:
		draw_arc(middle, radius, -0.38, TAU - 0.38, 96, RINGS, 1.0, true)
	var offset := middle - Vector2.ONE * 105.0
	for y in range(7):
		for x in range(7):
			var pixel: String = PIXELS[y][x]
			var color := TILE
			if pixel == "a":
				color = GOLD
			elif pixel == "c":
				color = MINT
			draw_rect(Rect2(offset + Vector2(x, y) * 30.0, Vector2.ONE * 26.0), color)
	for point in [Vector2(-173, 32), Vector2(117, -104), Vector2(160, 72)]:
		draw_circle(middle + point, 6.0, GOLD, true, -1.0, true)
