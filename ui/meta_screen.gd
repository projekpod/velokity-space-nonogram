extends VBoxContainer

signal back_requested

const UI := preload("res://ui/controls.gd")
const Cosmetics := preload("res://scripts/meta/cosmetics.gd")
const ShopCard := preload("res://ui/shop_card.gd")
const Meta := preload("res://scripts/meta/progression.gd")
const Catalog := preload("res://scripts/nonogram/catalog.gd")
const Daily := preload("res://scripts/daily/calendar.gd")
const Picture := preload("res://ui/album_picture.gd")
const Portrait := preload("res://ui/mission_art.gd")

const AdsRules := preload("res://scripts/autoload/ads.gd")
const EconomyRules := preload("res://scripts/autoload/economy.gd")
const Purchases := preload("res://scripts/payments/purchase_provider.gd")

enum Page { ALBUM, SHOP, ACHIEVEMENTS, LOGIN, PURCHASES }

const PANEL := Color("#16243b")
const LINE := Color("#304768")

@onready var _economy := get_node("/root/Economy")
@onready var _ads := get_node("/root/Ads")

var page := Page.ALBUM
var planet := "moon"
var _slot := "helmet"
var _shop_tab := "cat"
var _shop_list: VBoxContainer
var _shop_scroll: ScrollContainer
var _shop_cards: Dictionary = {}
var _stage: ShopCard
var _preview_rarity: Label
var _preview_id := ""
var _preview_panel: VBoxContainer
var _preview_title: Label
var _portrait: Portrait
var _message := ""
var _message_color := UI.MINT
var _coin_ad_waiting := false
var _coin_reward_day := -1
var _purchases := Purchases.new()


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	_preview_id = _economy.equipped_cosmetic("cat")
	_ads.rewarded_finished.connect(_on_coin_ad_finished)
	_render()


func _render(focus := "") -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	var top := UI.row(self)
	var back_key := "GAME_BACK"
	if page == Page.ACHIEVEMENTS:
		back_key = "META_BACK_ALBUM"
	elif page == Page.PURCHASES:
		back_key = "META_SHOP"
	var back := UI.button(top, back_key)
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
		Page.PURCHASES:
			_render_purchases()


func _back() -> void:
	if page == Page.ACHIEVEMENTS:
		page = Page.ALBUM
		_render()
	elif page == Page.PURCHASES:
		page = Page.SHOP
		_message = ""
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
	var tabs := UI.row(self)
	for category in ["cat", "skin", "costume"]:
		var tab := UI.action(tabs, "SHOP_TAB_" + category.to_upper(), category == _shop_tab)
		tab.pressed.connect(_select_shop_tab.bind(category))

	_stage = ShopCard.new()
	_stage.rarity = _item(_preview_id).get("rarity", Cosmetics.Rarity.COMMON)
	_stage.padding = 8
	add_child(_stage)
	_preview_panel = VBoxContainer.new()
	_preview_panel.add_theme_constant_override("separation", 2)
	_stage.add_child(_preview_panel)
	_preview_title = UI.label(_preview_panel, "", 29, UI.INK)
	_preview_rarity = UI.label(_preview_panel, "", 20, UI.MINT)
	_update_shop_preview()
	if _shop_tab == "costume":
		var slots := UI.row(self)
		for slot: String in Meta.SLOTS:
			var tab := UI.action(slots, "COSTUME_SLOT_" + slot.to_upper(), slot == _slot)
			tab.add_theme_font_size_override("font_size", 20)
			tab.custom_minimum_size.y = 50
			tab.pressed.connect(_select_slot.bind(slot))

	_shop_scroll = ScrollContainer.new()
	_shop_scroll.custom_minimum_size.y = 410
	_shop_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_shop_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_RESERVE
	_shop_scroll.follow_focus = true
	add_child(_shop_scroll)
	_shop_list = VBoxContainer.new()
	_shop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shop_list.add_theme_constant_override("separation", 9)
	_shop_scroll.add_child(_shop_list)
	_shop_cards.clear()
	var equipped := _equipped_item()
	if _shop_tab == "costume":
		_shop_row("", {}, equipped, focus)
		for id: String in Meta.COSTUMES:
			var item: Dictionary = Meta.COSTUMES[id]
			if item.slot == _slot:
				_shop_row(id, item, equipped, focus)
	else:
		var items := Cosmetics.items(_shop_tab)
		for id: String in items:
			_shop_row(id, items[id], equipped, focus)
	_render_shop_actions()
	_show_message()
	if not focus.is_empty() and _shop_cards.has(focus):
		_reveal_shop_card.call_deferred(focus)


func _reveal_shop_card(id: String) -> void:
	if is_instance_valid(_shop_scroll) and _shop_cards.has(id):
		_shop_scroll.ensure_control_visible(_shop_cards[id])


func _equipped_item() -> String:
	return _economy.equipped_costumes().get(_slot, "") if _shop_tab == "costume" else _economy.equipped_cosmetic(_shop_tab)


func _item(id: String) -> Dictionary:
	var items := Meta.COSTUMES if _shop_tab == "costume" else Cosmetics.items(_shop_tab)
	return items.get(id, {})


func _select_shop_tab(category: String) -> void:
	if _shop_tab == category:
		return
	_shop_tab = category
	_preview_id = _equipped_item()
	_message = ""
	_render()


func _render_shop_actions() -> void:
	var actions := UI.row(self)
	var today := Daily.today()
	var remaining: int = _economy.free_coin_ads_remaining(today)
	var label := tr("FREE_COINS_BUTTON") % [EconomyRules.FREE_COIN_AMOUNT, remaining]
	if _coin_reward_day >= 0:
		UI.action(actions, "SAVE_RETRY", true).pressed.connect(_save_coin_reward)
	elif _ads.supports_rewarded():
		var free_coins := UI.action(actions, label, true)
		free_coins.disabled = remaining == 0 or not _ads.can_request_rewarded()
		free_coins.pressed.connect(_request_coin_ad)
	if _purchases.has_available_products():
		UI.button(actions, "IAP_TITLE").pressed.connect(_open_purchases)
	if actions.get_child_count() == 0:
		remove_child(actions)
		actions.queue_free()
	_watch_local_day(today)


func _request_coin_ad() -> void:
	if _coin_ad_waiting or _coin_reward_day >= 0 or _economy.free_coin_ads_remaining(Daily.today()) == 0:
		return
	_coin_ad_waiting = _ads.request_rewarded(AdsRules.FREE_COINS)
	if not _coin_ad_waiting:
		_ad_unavailable()


func _on_coin_ad_finished(placement: StringName, granted: bool) -> void:
	if placement != AdsRules.FREE_COINS or not _coin_ad_waiting or not is_inside_tree():
		return
	_coin_ad_waiting = false
	if granted:
		_coin_reward_day = Daily.today()
		_save_coin_reward()
	else:
		_ad_unavailable()


func _save_coin_reward() -> void:
	if _coin_reward_day < 0:
		return
	var amount: int = await _economy.award_free_ad_coins(_coin_reward_day)
	if amount < 0:
		_fail()
	else:
		_coin_reward_day = -1
		_message = tr("GAME_EARNED") % amount if amount > 0 else "FREE_COINS_LIMIT"
		_message_color = UI.MINT
	_render()


func _ad_unavailable() -> void:
	_message = "AD_UNAVAILABLE"
	_message_color = UI.ERROR_COLOR
	_render()


func _open_purchases() -> void:
	if not _purchases.has_available_products():
		return
	_message = ""
	page = Page.PURCHASES
	_render()


func _render_purchases() -> void:
	UI.label(self, "IAP_TITLE", 46)
	for id: StringName in Purchases.PRODUCTS:
		if _purchases.is_product_available(id):
			UI.button(self, Purchases.PRODUCTS[id]).pressed.connect(_request_purchase.bind(id))
	if not _purchases.has_available_products() or not _message.is_empty():
		UI.label(self, "IAP_UNAVAILABLE", 23, UI.MUTED)


func _request_purchase(id: StringName) -> void:
	if _purchases.is_product_available(id) and not _purchases.request_purchase(id):
		_message = "IAP_UNAVAILABLE"
		_render()


func _select_slot(slot: String) -> void:
	_shop_tab = "costume"
	_slot = slot
	_preview_id = _economy.equipped_costumes().get(slot, "")
	_message = ""
	_render()


func _preview_item(id: String) -> void:
	_preview_id = id
	var rarity: int = _item(id).get("rarity", Cosmetics.Rarity.COMMON)
	if rarity != _stage.rarity:
		var old_stage := _stage
		_stage = ShopCard.new()
		_stage.rarity = rarity
		_stage.padding = old_stage.padding
		add_child(_stage)
		move_child(_stage, old_stage.get_index())
		_preview_panel.reparent(_stage)
		remove_child(old_stage)
		old_stage.queue_free()
	_update_shop_preview()


func _update_shop_preview() -> void:
	var outfit: Dictionary = _economy.equipped_costumes()
	if _shop_tab == "costume":
		outfit[_slot] = _preview_id
	if is_instance_valid(_portrait) and _portrait.get_parent() == _preview_panel:
		_preview_panel.remove_child(_portrait)
		_portrait.queue_free()
	_portrait = Portrait.new()
	_portrait.display_height = 234
	_portrait.preview_outfit = outfit
	_portrait.preview_cat = _preview_id if _shop_tab == "cat" else ""
	_portrait.preview_skin = _preview_id if _shop_tab == "skin" else ""
	_preview_panel.add_child(_portrait)
	_preview_panel.move_child(_portrait, 0)
	_preview_title.text = Cosmetics.title(_shop_tab, _preview_id)
	_preview_rarity.text = Cosmetics.rarity_title(_stage.rarity)
	_preview_rarity.add_theme_color_override("font_color", Cosmetics.FRAME_COLORS[_stage.rarity].lightened(0.3))


func _shop_row(id: String, item: Dictionary, equipped: String, focus: String) -> void:
	var card := ShopCard.new()
	card.rarity = item.get("rarity", Cosmetics.Rarity.COMMON)
	card.padding = 9
	_shop_list.add_child(card)
	_shop_cards[id] = card
	var row := UI.row(card)
	var swatch := ColorRect.new()
	swatch.color = item.get("color", UI.INK)
	swatch.custom_minimum_size = Vector2(10, 34)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(swatch)

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 2)
	row.add_child(copy)
	var preview := UI.button(copy, Cosmetics.title(_shop_tab, id))
	preview.alignment = HORIZONTAL_ALIGNMENT_LEFT
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		preview.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	preview.add_theme_color_override("font_hover_color", UI.MINT)
	preview.custom_minimum_size.y = 36
	preview.add_theme_font_size_override("font_size", 25)
	preview.pressed.connect(_preview_item.bind(id))

	var source := Cosmetics.rarity_title(card.rarity)
	if item.has("album"):
		source = tr("COSTUME_FROM_ALBUM") % _planet_title(item.album)
	elif item.has("achievement"):
		source = tr("COSTUME_FROM_ACHIEVEMENT") % tr(Meta.achievement_title(item.achievement))
	elif item.has("caption"):
		source = tr(source) + " · " + tr(item.caption)
	var color: Color = Cosmetics.FRAME_COLORS[card.rarity].lightened(0.39)
	var caption := UI.label(copy, source, 18, color)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	caption.clip_text = true

	var owned: bool = id.is_empty()
	if not owned:
		owned = _economy.owns_costume(id) if _shop_tab == "costume" else _economy.owns_cosmetic(_shop_tab, id)
	var action: Button
	if equipped == id:
		action = UI.button(row, "COSTUME_EQUIPPED")
		action.disabled = true
	elif owned:
		action = UI.button(row, "COSTUME_EQUIP", true)
		action.pressed.connect(_equip.bind(id))
	elif item.has("price"):
		action = UI.button(row, tr("COSTUME_BUY") % item.price, true)
		action.disabled = _economy.balance() < item.price
		action.pressed.connect(_buy.bind(id))
	else:
		action = UI.button(row, "COSTUME_LOCKED")
		action.disabled = true
	action.custom_minimum_size = Vector2(192, 50)
	action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	action.add_theme_font_size_override("font_size", 20)
	if not focus.is_empty() and focus == id:
		if action.disabled:
			preview.grab_focus()
		else:
			action.grab_focus()


func _buy(id: String) -> void:
	var category := _shop_tab
	var bought: bool
	if category == "costume":
		bought = await _economy.buy_costume(id)
	else:
		bought = await _economy.buy_cosmetic(category, id)
	_finish_shop_action(id, category, bought)


func _equip(id: String) -> void:
	var category := _shop_tab
	var slot := _slot
	var equipped: bool
	if category == "costume":
		equipped = await _economy.equip_costume(slot, id)
	else:
		equipped = await _economy.equip_cosmetic(category, id)
	_finish_shop_action(id, category, equipped)


func _finish_shop_action(id: String, category: String, saved: bool) -> void:
	if not is_inside_tree() or page != Page.SHOP:
		return
	_message = ""
	if not saved:
		_fail()
	if saved and category == _shop_tab and (category != "costume" or id.is_empty() or Meta.COSTUMES[id].slot == _slot):
		_preview_id = id
		_render(id)
	else:
		_render()


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
	_watch_local_day(today)


func _watch_local_day(today: int) -> void:
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
	var reward: int = await _economy.claim_login(Daily.today())
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
