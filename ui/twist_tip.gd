extends RefCounted

const UI := preload("res://ui/controls.gd")
const Twists := preload("res://scripts/nonogram/twists.gd")
const COLORS := {
	"revealed": Color("#93f2e4"), "asteroid": Color("#d4baff"), "star": Color("#ffcf82"),
	"shield": Color("#9fcbff"), "comet": Color("#ff9caf"), "perfect": Color("#b8ef9c"),
}
const PIXELS := {
	"revealed": [".........", ".#######.", ".#.....#.", ".#...#.#.", ".##.#..#.", ".#.##..#.", ".#.....#.", ".#######.", "........."],
	"asteroid": [".........", "...####..", "..######.", ".##.####.", ".#####.#.", ".#######.", "..##.##..", "...###...", "........."],
	"star": ["....#....", "....#....", "...###...", "...###...", "#########", "...###...", "...###...", "....#....", "....#...."],
	"shield": ["...###...", ".#######.", ".#######.", ".##...##.", ".##...##.", "..#...#..", "..#####..", "...###...", "....#...."],
	"comet": ["......##.", ".....####", "....#####", "...#####.", "..#####..", "...###...", ".#.......", "..#......", "#........"],
	"perfect": ["...###...", "..#####..", ".##...##.", ".#...#.#.", ".##.#..#.", "..#####..", "...###...", "..#.#.#..", "..#...#.."],
}

static var _icons: Dictionary = {}


static func title_key(kind: String) -> String:
	return "TWIST_" + kind.to_upper()


static func icon(kind: String) -> Texture2D:
	if not _icons.has(kind):
		var pixels: Array = PIXELS[kind]
		var image := Image.create_empty(9, 9, false, Image.FORMAT_RGBA8)
		for y in range(9):
			for x in range(9):
				if pixels[y][x] == "#":
					image.set_pixel(x, y, COLORS[kind])
		image.resize(36, 36, Image.INTERPOLATE_NEAREST)
		_icons[kind] = ImageTexture.create_from_image(image)
	return _icons[kind]


static func card(kind: String, seconds := 0) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var accent: Color = COLORS[kind]
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#16243c")
	style.border_color = accent.darkened(0.55)
	style.set_border_width_all(1)
	style.border_width_top = 3
	style.set_corner_radius_all(16)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 9)
	panel.add_child(content)
	var symbol := TextureRect.new()
	symbol.texture = icon(kind)
	symbol.custom_minimum_size = Vector2(48, 48)
	symbol.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	symbol.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	symbol.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	symbol.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	content.add_child(symbol)
	UI.label(content, title_key(kind), 27, accent)
	var description_key := title_key(kind) + "_TIP"
	var description := String(TranslationServer.translate(description_key))
	if kind == "comet":
		description = description % [seconds, Twists.COINS.comet]
	elif Twists.COINS.has(kind):
		description = description % Twists.COINS[kind]
	UI.label(content, description, 22, UI.INK).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return panel
