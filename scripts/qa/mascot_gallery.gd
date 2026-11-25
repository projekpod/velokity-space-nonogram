extends RefCounted

const UI := preload("res://ui/controls.gd")
const Mascot := preload("res://ui/mascot.gd")

const EXPRESSIONS := {
	"QA_HAPPY": Mascot.Face.HAPPY, "QA_PROUD": Mascot.Face.PROUD,
	"QA_SURPRISED": Mascot.Face.SURPRISED, "QA_SAD": Mascot.Face.SAD,
	"QA_THINKING": Mascot.Face.THINKING, "QA_SLEEPING": Mascot.Face.SLEEPING,
	"QA_DANCING": Mascot.Face.DANCING, "QA_CHEERING": Mascot.Face.CHEERING,
}
const REACTIONS := {
	"QA_FILL": Mascot.Reaction.FILL, "QA_MISTAKE": Mascot.Reaction.MISTAKE,
	"QA_COMBO": Mascot.Reaction.COMBO, "QA_WIN": Mascot.Reaction.WIN,
}


static func open(main: Control, reactions: bool) -> void:
	var wide := reactions and main.get_viewport_rect().size.x >= 1150.0
	main._reset_column(minf(main.get_viewport_rect().size.x - 64.0, 1580.0) if wide else 676.0, 22)
	var column: VBoxContainer = main._column
	UI.label(column, "QA_REACTIONS" if reactions else "QA_MASCOT", 44, UI.MINT)
	var grid := GridContainer.new()
	grid.columns = 4 if reactions else 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	column.add_child(grid)
	if reactions:
		for label: String in REACTIONS:
			var portrait := _card(grid, label, 348.0 if wide else 174.0)
			portrait.hold_pose(Mascot.Face.HAPPY, REACTIONS[label])
	else:
		for label: String in EXPRESSIONS:
			var portrait := _card(grid, label, 207.0)
			portrait.hold_pose(EXPRESSIONS[label])


static func _card(grid: GridContainer, label: String, height: float) -> Mascot:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#17253cb5")
	style.set_corner_radius_all(22)
	style.set_border_width_all(1)
	style.border_color = Color("#4c6a8b94")
	style.content_margin_top = 7
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)
	grid.add_child(panel)
	var content := VBoxContainer.new()
	panel.add_child(content)
	var portrait := Mascot.new()
	portrait.custom_minimum_size = Vector2(146, height)
	content.add_child(portrait)
	UI.label(content, label, 23)
	return portrait
