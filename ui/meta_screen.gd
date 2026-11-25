extends VBoxContainer

signal back_requested

const UI := preload("res://ui/controls.gd")
const Meta := preload("res://scripts/meta/progression.gd")
const Catalog := preload("res://scripts/nonogram/catalog.gd")
const Daily := preload("res://scripts/daily/calendar.gd")
const Picture := preload("res://ui/album_picture.gd")
const Portrait := preload("res://ui/mission_art.gd")

enum Page { ALBUM, SHOP, ACHIEVEMENTS, LOGIN }

const PANEL := Color("#16243b")
const LINE := Color("#304768")

@onready var _economy := get_node("/root/Economy")

var page := Page.ALBUM
var planet := "moon"
var _slot := "helmet"
var _preview_id := ""
var _preview_panel: VBoxContainer
var _preview_title: Label
var _portrait: Portrait
var _message := ""
var _message_color := UI.MINT


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	_preview_id = _economy.equipped_costumes().get(_slot, "")
	_render()


func _render(focus := "") -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	var top := UI.row(self)
	var back := UI.button(top, "META_BACK_ALBUM" if page == Page.ACHIEVEMENTS else "GAME_BACK")
	back.pressed.connect(_back)
	back.grab_focus()
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	if page == Page.ALBUM:
		UI.button(top, "META_ACHIEVEMENTS").pressed.connect(_open_achievements)
	elif page in [Page.SHOP, Page.LOGIN]:
		UI.label(top, tr("COIN_BALANCE") % _economy.balance(), 25, UI.GOLD)
	match page:
		Page.ALBUM:
			_render_album()
		Page.SHOP:
			_render_shop(focus)
		Page.ACHIEVEMENTS:
			_render_achievements()
		Page.LOGIN:
			_render_login()


func _back() -> void:
	if page == Page.ACHIEVEMENTS:
		page = Page.ALBUM
		_render()
	else:
		back_requested.emit()


func _open_achievements() -> void:
	page = Page.ACHIEVEMENTS
	_render()


func _render_album() -> void:
	UI.label(self, "META_ALBUM", 47, UI.INK)
	var tabs := UI.row(self)
	for id: String in Catalog.PLANETS:
		var tab := UI.action(tabs, _planet_title(id), id == planet)
		tab.pressed.connect(_select_planet.bind(id))

	var count: int = _economy.album_collected(planet)
	UI.label(self, tr("ALBUM_PROGRESS") % [count, Catalog.PICTURES_PER_ALBUM], 23, UI.MUTED)
	_meter(self, count, Catalog.PICTURES_PER_ALBUM)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	add_child(grid)
	for level: Dictionary in _economy.levels:
		if level.planet != planet:
			continue
		var revealed: bool = _economy.is_nonogram_cleared(level.id)
		var card := _panel(grid, PANEL if revealed else Color("#121d32"), Color("#427182") if revealed else LINE, 7)
		card.custom_minimum_size.x = 142
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var stack := VBoxContainer.new()
		stack.add_theme_constant_override("separation", 2)
		card.add_child(stack)
		var picture := Picture.new()
		picture.level = level if revealed else {}
		card.tooltip_text = UI.level_title(level) if revealed else tr("ALBUM_LOCKED")
		stack.add_child(picture)
		var name_label := UI.label(stack, UI.level_title(level) if revealed else "", 16)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.max_lines_visible = 2
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.custom_minimum_size.y = 44

	var reward: String = Meta.ALBUM_REWARDS[planet]
	var footer := _panel(self, PANEL, LINE, 13)
	var reward_text := VBoxContainer.new()
	footer.add_child(reward_text)
	UI.label(reward_text, tr("ALBUM_REWARD") % tr(Meta.costume_title(reward)), 23, UI.GOLD)
	UI.label(reward_text, "META_UNLOCKED" if _economy.owns_costume(reward) else "ALBUM_REQUIREMENT", 19, UI.MUTED)


func _select_planet(id: String) -> void:
	planet = id
	_render()


func _render_achievements() -> void:
	UI.label(self, "META_ACHIEVEMENTS", 44)
	for id: String in Meta.ACHIEVEMENTS:
		var achievement: Dictionary = Meta.ACHIEVEMENTS[id]
		var progress: int = mini(_economy.achievement_progress(id), achievement.goal)
		var card := _panel(self, PANEL, LINE, 16)
		var details := VBoxContainer.new()
		card.add_child(details)
		UI.label(details, Meta.achievement_title(id), 29, UI.MINT)
		var requirement := tr("ACHIEVEMENT_PROGRESS") % [progress, achievement.goal]
		UI.label(details, tr("ACHIEVEMENT_GOAL_" + id.to_upper()) % requirement, 21, UI.MUTED)
		_meter(details, progress, achievement.goal)
		var reward := tr(Meta.costume_title(achievement.costume))
		UI.label(details, tr("ALBUM_REWARD") % reward, 20, UI.GOLD)
		if _economy.owns_costume(achievement.costume):
			UI.label(details, "META_UNLOCKED", 19, UI.MINT)


func _render_shop(focus: String) -> void:
	UI.label(self, "META_SHOP", 47)
	var stage := _panel(self, Color("#132239"), Color("#40607c"), 9)
	_preview_panel = VBoxContainer.new()
	stage.add_child(_preview_panel)
	_preview_title = UI.label(_preview_panel, "", 24, UI.MINT)
	_preview_costume(_preview_id)

	var tabs := UI.row(self)
	for slot: String in Meta.SLOTS:
		var tab := UI.action(tabs, "COSTUME_SLOT_" + slot.to_upper(), slot == _slot)
		tab.add_theme_font_size_override("font_size", 22)
		tab.pressed.connect(_select_slot.bind(slot))

	var equipped: Dictionary = _economy.equipped_costumes()
	_shop_row("", {}, equipped.get(_slot, ""), focus)
	for id: String in Meta.COSTUMES:
		var item: Dictionary = Meta.COSTUMES[id]
		if item.slot == _slot:
			_shop_row(id, item, equipped.get(_slot, ""), focus)
	_show_message()


func _select_slot(slot: String) -> void:
	_slot = slot
	_preview_id = _economy.equipped_costumes().get(slot, "")
	_message = ""
	_render()


func _preview_costume(id: String) -> void:
	_preview_id = id
	var outfit: Dictionary = _economy.equipped_costumes()
	outfit[_slot] = id
	if is_instance_valid(_portrait) and _portrait.get_parent() == _preview_panel:
		_preview_panel.remove_child(_portrait)
		_portrait.queue_free()
	_portrait = Portrait.new()
	_portrait.display_height = 278
	_portrait.preview_outfit = outfit
	_preview_panel.add_child(_portrait)
	_preview_panel.move_child(_portrait, 0)
	_preview_title.text = tr("COSTUME_PREVIEW") % tr(_costume_title(id))


func _shop_row(id: String, item: Dictionary, equipped: String, focus: String) -> void:
	var card := _panel(self, PANEL, LINE, 6)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)

	var swatch := ColorRect.new()
	swatch.color = item.get("color", UI.INK)
	swatch.custom_minimum_size = Vector2(12, 30)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(swatch)

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 1)
	row.add_child(copy)
	var preview := UI.button(copy, _costume_title(id))
	preview.alignment = HORIZONTAL_ALIGNMENT_LEFT
	preview.custom_minimum_size.y = 32
	preview.add_theme_font_size_override("font_size", 21)
	preview.pressed.connect(_preview_costume.bind(id))

	if item.has("album"):
		_source_label(copy, tr("COSTUME_FROM_ALBUM") % _planet_title(item.album))
	elif item.has("achievement"):
		_source_label(copy, tr("COSTUME_FROM_ACHIEVEMENT") % tr(Meta.achievement_title(item.achievement)))

	var action: Button
	if equipped == id:
		action = UI.button(row, "COSTUME_EQUIPPED")
		action.disabled = true
	elif id.is_empty() or _economy.owns_costume(id):
		action = UI.button(row, "COSTUME_EQUIP", true)
		action.pressed.connect(_equip.bind(id))
	elif item.has("price"):
		action = UI.button(row, tr("COSTUME_BUY") % item.price, true)
		action.disabled = _economy.balance() < item.price
		action.pressed.connect(_buy.bind(id))
	else:
		action = UI.button(row, "COSTUME_LOCKED")
		action.disabled = true
	action.custom_minimum_size = Vector2(190, 50)
	action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	action.add_theme_font_size_override("font_size", 20)
	if not focus.is_empty() and focus == id:
		if action.disabled:
			preview.grab_focus()
		else:
			action.grab_focus()


func _source_label(parent: Control, text: String) -> void:
	var source := UI.label(parent, text, 17, UI.MUTED)
	source.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	source.clip_text = true


func _costume_title(id: String) -> String:
	return "COSTUME_DEFAULT" if id.is_empty() else Meta.costume_title(id)


func _buy(id: String) -> void:
	_message = ""
	if _economy.buy_costume(id):
		_preview_id = id
	else:
		_fail()
	_render(id)


func _equip(id: String) -> void:
	_message = ""
	if _economy.equip_costume(_slot, id):
		_preview_id = id
	else:
		_fail()
	_render(id)


func _render_login() -> void:
	UI.label(self, "META_LOGIN", 46)
	var today := Daily.today()
	var status: Dictionary = _economy.login_status(today)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 9)
	grid.add_theme_constant_override("v_separation", 9)
	add_child(grid)
	for index in range(Meta.LOGIN_REWARDS.size()):
		var collected: bool = index < status.slots
		var available: bool = index == status.slots and status.reward > 0
		var card := _panel(grid, PANEL, UI.MINT if available else LINE, 12)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var labels := VBoxContainer.new()
		card.add_child(labels)
		UI.label(labels, tr("DAILY_REWARD_DAY") % (index + 1), 19, UI.MUTED)
		UI.label(labels, tr("COIN_BALANCE") % Meta.LOGIN_REWARDS[index], 23, UI.GOLD)
		var caption := "LOGIN_COLLECTED" if collected else "LOGIN_READY" if available else ""
		UI.label(labels, caption, 17, UI.MINT)
	var claim := UI.button(self, tr("LOGIN_CLAIM") % status.reward if status.reward > 0 else "LOGIN_CLOCK" if status.clock_behind else "LOGIN_TOMORROW", status.reward > 0)
	claim.disabled = status.reward <= 0
	claim.pressed.connect(_claim_login)
	_show_message()

	var timer := Timer.new()
	timer.wait_time = 1.0
	add_child(timer)
	timer.timeout.connect(func() -> void:
		if Daily.today() != today:
			_message = ""
			_render()
	)
	timer.start()


func _claim_login() -> void:
	_message = ""
	var reward: int = _economy.claim_login(Daily.today())
	if reward > 0:
		_message = tr("GAME_EARNED") % reward
		_message_color = UI.MINT
	elif reward < 0:
		_fail()
	_render()


func _fail() -> void:
	_message = "SAVE_FAILED"
	_message_color = UI.ERROR_COLOR


func _show_message() -> void:
	if not _message.is_empty():
		UI.label(self, _message, 21, _message_color)


func _planet_title(id: String) -> String:
	return tr("PLANET_" + id.to_upper())


static func _panel(parent: Control, color: Color, border: Color, padding: float) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(padding)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel


static func _meter(parent: Control, value: int, goal: int) -> void:
	var meter := ProgressBar.new()
	meter.show_percentage = false
	meter.max_value = goal
	meter.value = value
	meter.custom_minimum_size.y = 8
	for key in ["background", "fill"]:
		var style := StyleBoxFlat.new()
		style.bg_color = UI.MINT if key == "fill" else Color("#21334f")
		style.set_corner_radius_all(4)
		meter.add_theme_stylebox_override(key, style)
	parent.add_child(meter)
