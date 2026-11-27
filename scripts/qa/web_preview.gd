extends RefCounted

const Cosmetics := preload("res://scripts/meta/cosmetics.gd")
const ShopCard := preload("res://ui/shop_card.gd")
const UI := preload("res://ui/controls.gd")
const Main := preload("res://ui/main.gd")
const SaveScript := preload("res://scripts/autoload/save.gd")
const Catalog := preload("res://scripts/nonogram/catalog.gd")
const Daily := preload("res://scripts/daily/calendar.gd")
const Puzzle := preload("res://scripts/nonogram/puzzle.gd")
const Playthrough := preload("res://scripts/qa/playthrough.gd")
const StoreArt := preload("res://scripts/qa/store_art.gd")
const Gallery := preload("res://scripts/qa/mascot_gallery.gd")
const Mascot := preload("res://ui/mascot.gd")
const Bonus := preload("res://scripts/nonogram/bonus.gd")
const Meta := preload("res://scripts/meta/progression.gd")
const MetaScreen := preload("res://ui/meta_screen.gd")
const NonogramScreen := preload("res://ui/nonogram_screen.gd")
const Twists := preload("res://scripts/nonogram/twists.gd")
const TwistTip := preload("res://ui/twist_tip.gd")
const STORE_BOARD := "toi700-19-robot-arm"
const PREVIEW_FILLED_ROWS := 12


static func open(main: Main) -> bool:
	var route: Variant = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('qa')", true)
	if route not in ["menu", "game", "win", "daily", "mascot", "reactions", "combo", "bonus", "album", "shop", "celebration", "store-cover", "store-icon", "playthrough", "preview", "streak", "space", "cats", "shop-legendary", "zoom", "twists", "store-zoom", "store-twist", "store-preview"]:
		return false
	if route not in ["playthrough", "preview"]:
		_seed_progress(main)
	match route:
		"playthrough", "preview", "zoom":
			if route == "playthrough":
				main._open_start_screen()
			elif route == "preview":
				main._play(0)
			else:
				_open_zoom(main)
		"store-zoom", "store-preview":
			var index := main._levels.find_custom(func(level: Dictionary) -> bool: return level.id == STORE_BOARD)
			var screen := _open_store_puzzle(main, index)
			if screen == null:
				push_error("The store video board could not start")
				return false
			screen._puzzle.set_block_signals(true)
			_fill_rows(screen, PREVIEW_FILLED_ROWS if route == "store-preview" else 8)
			screen._puzzle.set_block_signals(false)
			screen._board.queue_redraw()
			if route == "store-zoom":
				await main.get_tree().process_frame
				await main.get_tree().process_frame
				var frame := screen._board._grid()
				var center := frame.get_center()
				screen._board._zoom_at(frame.size.x / screen._puzzle.size * 1.37, center, center)
		"store-twist":
			var screen := _open_store_puzzle(main, main._planet_levels("venus")[0], false)
			if screen == null:
				push_error("The store twist tip could not start")
				return false
		"store-cover", "store-icon":
			var art := StoreArt.new()
			art.icon_only = route == "store-icon"
			main.add_child(art)
			art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		"menu":
			main.show_menu()
		"game", "win":
			if not await _open_nonogram(main, route == "win"):
				push_error("The QA Nonogram could not reach the requested state")
				return false
		"daily":
			var screen := main._open_daily()
			if screen._puzzle == null:
				push_error("The QA daily puzzle is unavailable")
				return false
			var daily := Daily.puzzle_for(screen._day)
			var x := int(daily.solution[0])
			screen._puzzle.place(Vector2i(x, 0), false)
			screen._puzzle.place(Vector2i((x + 1) % screen._puzzle.size, 0), true)
		"mascot", "reactions":
			Gallery.open(main, route == "reactions")
		"space":
			main.get_node("Backdrop").freeze_at_events()
		"twists":
			_open_twists(main)
		"streak":
			var screen := main._play(main._planet_levels("saturn")[0])
			if screen == null:
				return false
			_fill_rows(screen, 4)
			screen._celebration.dismiss()
			screen._streak.freeze_at(maxi(9, screen._streak.peak))
		"combo":
			if not _open_combo(main):
				push_error("The QA puzzle could not reach a combo")
				return false
		"bonus":
			var save := main.get_node("/root/Save")
			for index in range(Bonus.BADGES_PER_ROUND):
				save.data.nonogram[main._levels[index].id].flawless = true
			var screen := main._open_bonus()
			if screen == null or screen.bonus_index != 0 or screen._puzzle.size != 5:
				push_error("The QA Bonus Round could not start")
				return false
		"album":
			var planet: Variant = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('planet')", true)
			if planet is String and planet in Catalog.planets():
				for index in main._planet_levels(planet):
					main._save.data.nonogram[main._levels[index].id] = {"reward": 30, "doubled": false}
				main._open_meta(MetaScreen.Page.ALBUM, planet)
				JavaScriptBridge.get_interface("document").documentElement.setAttribute("data-velokity-qa-album", planet)
			else:
				main._open_meta(MetaScreen.Page.ALBUM)
		"shop":
			var save := main.get_node("/root/Save")
			save.data.coins = 1450
			save.data.meta.purchased.mint_visor = true
			save.data.meta.equipped.helmet = "mint_visor"
			var screen := main._open_meta(MetaScreen.Page.SHOP)
			screen._select_shop_tab("costume")
			screen._preview_item("violet_visor")
		"cats":
			_open_cat_gallery(main)
		"shop-legendary":
			main._save.data.coins = 27500
			var screen := main._open_meta(MetaScreen.Page.SHOP)
			screen._preview_item("savannah")
			await main.get_tree().process_frame
			await main.get_tree().process_frame
			screen._reveal_shop_card("savannah")
			screen._portrait.mascot.hold_pose(Mascot.Face.PROUD)
		"celebration":
			if not await _open_celebration(main):
				push_error("The QA album could not reach a tier four celebration")
				return false
	if route in ["playthrough", "preview", "zoom", "store-zoom", "store-twist", "store-preview", "streak", "shop-legendary"]:
		var observer := Playthrough.new()
		observer.main = main
		main.add_child(observer)
	var document := JavaScriptBridge.get_interface("document")
	document.documentElement.setAttribute("data-velokity-qa-screen", route)
	return true


static func _open_store_puzzle(main: Main, index: int, skip_tip := true) -> NonogramScreen:
	if index < 0:
		return null
	var level := main._levels[index]
	var progress: Dictionary = main._save.data.nonogram
	var previous := Catalog.previous_planet(level.planet)
	for earlier in main._planet_levels(previous).slice(0, Catalog.PLANET_CLEAR_REQUIREMENT):
		progress[main._levels[earlier].id] = {"reward": 30, "doubled": false}
	if main._levels[index - 1].planet == level.planet:
		progress[main._levels[index - 1].id] = {"reward": 30, "doubled": false}
	if skip_tip:
		main._save.data.twist_tips[level.twist.kind] = true
	return main._play(index)


static func _open_twists(main: Main) -> void:
	main._reset_column(630)
	UI.label(main._column, "TWIST_GALLERY", 43, UI.MINT)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	main._column.add_child(grid)
	var seconds := 0
	for level in main._levels:
		var twist: Dictionary = level.get("twist", {})
		if twist.get("kind") == "comet":
			seconds = int(twist.seconds)
			break
	for kind: String in Twists.KINDS:
		grid.add_child(TwistTip.card(kind, seconds))


static func _open_zoom(main: Main) -> void:
	var rows: Array[String] = []
	for index in range(15):
		rows.append(".".repeat(index) + "a" + ".".repeat(14 - index))
	main._reset_column(NonogramScreen.BOARD_WIDTH, 0, true)
	var screen := NonogramScreen.new()
	screen.level = {
		"id": "qa-zoom", "planet": "moon", "size": 15, "solution": rows,
		"palette": {"a": "#ffd27b"}, "title": {"en": "Zoom test", "id": "Uji zoom"},
	}
	main._column.add_child(screen)


static func _open_cat_gallery(main: Main) -> void:
	main._reset_column(632)
	UI.label(main._column, "SHOP_TAB_CAT", 43, UI.MINT)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 11)
	main._column.add_child(grid)
	for id: String in Cosmetics.CATS:
		var card := ShopCard.new()
		card.rarity = Cosmetics.CATS[id].rarity
		card.padding = 7.0
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(card)
		var group := VBoxContainer.new()
		card.add_child(group)
		var cat := Mascot.new()
		cat.preview_cat = id
		cat.preview_skin = Cosmetics.DEFAULT_SKIN
		cat.preview_outfit = {}
		cat.custom_minimum_size.y = 152
		group.add_child(cat)
		cat.hold_pose(Mascot.Face.HAPPY)
		UI.label(group, Cosmetics.title("cat", id), 23)


static func _seed_progress(main: Main) -> void:
	var snapshot := SaveScript.defaults()
	snapshot.coins = 120
	snapshot.daily = {"last_day": Daily.today() - 1, "streak": 3, "clears": 3}
	for planet in ["moon", "mars"]:
		var indices := main._planet_levels(planet)
		for index in indices.slice(0, Catalog.PLANET_CLEAR_REQUIREMENT):
			snapshot.nonogram[main._levels[index].id] = {"reward": 30, "doubled": false}
	snapshot.meta.xp = (snapshot.nonogram.size() + snapshot.daily.clears) * Meta.CLEAR_XP
	main.get_node("/root/Save").data = snapshot


static func _open_nonogram(main: Main, won: bool) -> bool:
	var indices := main._planet_levels("saturn")
	if indices.is_empty():
		return false
	var screen := main._play(indices[0])
	if screen == null:
		return false
	var rows := screen._puzzle.size if won else mini(4, screen._puzzle.size)
	_fill_rows(screen, rows)
	await _wait_for_result(screen)
	screen._celebration.dismiss()
	return screen._puzzle.state == (Puzzle.State.WON if won else Puzzle.State.PLAYING)


static func _fill_rows(screen: NonogramScreen, rows: int) -> void:
	for y in range(rows):
		for x in range(screen._puzzle.size):
			screen._puzzle.mark(Vector2i(x, y), screen.level.solution[y][x] == ".")


static func _open_combo(main: Main) -> bool:
	var screen := main._play(0)
	if screen == null:
		return false
	for y in range(screen._puzzle.size):
		for x in range(screen._puzzle.size):
			if screen.level.solution[y][x] == ".":
				continue
			screen._puzzle.mark(Vector2i(x, y), false)
			if screen._celebration.tier == 2 and screen._puzzle.state == Puzzle.State.PLAYING:
				screen._celebration.play_combo(0, screen._correct_lines)
				screen._celebration.freeze_at(0.48)
				screen._portrait.mascot.hold_pose(Mascot.Face.DANCING, Mascot.Reaction.COMBO)
				return true
	return false



static func _open_celebration(main: Main) -> bool:
	var save := main.get_node("/root/Save")
	var indices := main._planet_levels("moon")
	for index in indices.slice(0, indices.size() - 1):
		save.data.nonogram[main._levels[index].id] = {"reward": 30, "doubled": false}
	save.data.meta.xp = (save.data.nonogram.size() + save.data.daily.clears) * Meta.CLEAR_XP
	var screen := main._play(indices.back())
	if screen == null:
		return false
	_fill_rows(screen, screen._puzzle.size)
	await _wait_for_result(screen)
	if screen._celebration.tier != 4:
		return false
	screen._celebration.freeze_at(0.62)
	return true


static func _wait_for_result(screen: NonogramScreen) -> void:
	while screen._saving:
		await screen.get_tree().process_frame
