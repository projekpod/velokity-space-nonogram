extends Control

@onready var center: CenterContainer = $Center


func _ready() -> void:
	show_menu()


func show_menu() -> void:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 500
	column.add_theme_constant_override("separation", 20)
	center.add_child(column)
	for item: Array in [["GAME_NAME", 92], ["GAME_SUBTITLE", 42], ["MENU_TAGLINE", 24]]:
		var title := Label.new()
		title.text = item[0]
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", item[1])
		column.add_child(title)
	for key in ["MENU_PLAY", "MENU_DAILY"]:
		var button := Button.new()
		button.text = key
		button.custom_minimum_size.y = 72
		button.add_theme_font_size_override("font_size", 26)
		button.disabled = true
		column.add_child(button)
