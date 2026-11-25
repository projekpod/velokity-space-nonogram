extends RefCounted

const INK := Color("#edf5ff")
const MUTED := Color("#a3b7d4")
const MINT := Color("#93f2e4")
const GOLD := Color("#ffcf82")
const ERROR_COLOR := Color("#ff8f99")


static func level_title(level: Dictionary) -> String:
	return level.title.id if TranslationServer.get_locale().get_slice("_", 0) == "id" else level.title.en


static func row(parent: Control) -> HBoxContainer:
	var container := HBoxContainer.new()
	container.add_theme_constant_override("separation", 12)
	parent.add_child(container)
	return container


static func action(parent: HBoxContainer, key: String, primary := false) -> Button:
	var control := button(parent, key, primary)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return control

static func label(parent: Control, text: String, font_size: int, color := INK) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


static func button(parent: Control, key: String, primary := false) -> Button:
	var button := Button.new()
	button.text = key
	button.custom_minimum_size = Vector2(124, 65)
	button.add_theme_font_size_override("font_size", 25)
	style_button(button, primary)
	parent.add_child(button)
	wire_button_sound(button)
	return button


static func wire_button_sound(button: BaseButton) -> void:
	button.pressed.connect(button.get_node("/root/Audio").play_effect.bind(&"button"))


static func style_button(button: Button, primary: bool) -> void:
	var base := MINT if primary else Color("#1c2b45")
	var foreground := Color("#10222d") if primary else INK
	button.add_theme_stylebox_override("normal", _box(base))
	button.add_theme_stylebox_override("hover", _box(base.lightened(0.1)))
	button.add_theme_stylebox_override("pressed", _box(base.darkened(0.08)))
	button.add_theme_stylebox_override("hover_pressed", _box(base.darkened(0.08)))
	button.add_theme_stylebox_override("disabled", _box(Color("#161f33")))
	var outline := _box(Color.TRANSPARENT)
	outline.set_border_width_all(2)
	outline.border_color = GOLD
	button.add_theme_stylebox_override("focus", outline)
	for property in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(property, foreground)
	button.add_theme_color_override("font_disabled_color", MUTED)


static func _box(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(13)
	style.content_margin_left = 18
	style.content_margin_right = 18
	return style
