extends RefCounted

const Main := preload("res://ui/main.gd")
const SaveScript := preload("res://scripts/autoload/save.gd")
const Catalog := preload("res://scripts/nonogram/catalog.gd")
const Daily := preload("res://scripts/daily/calendar.gd")
const Puzzle := preload("res://scripts/nonogram/puzzle.gd")
const Gallery := preload("res://scripts/qa/mascot_gallery.gd")
const Mascot := preload("res://ui/mascot.gd")
const Bonus := preload("res://scripts/nonogram/bonus.gd")
const Meta := preload("res://scripts/meta/progression.gd")
const MetaScreen := preload("res://ui/meta_screen.gd")
const NonogramScreen := preload("res://ui/nonogram_screen.gd")


static func open(main: Main) -> bool:
	var route: Variant = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('qa')", true)
	if route not in ["menu", "game", "win", "daily", "mascot", "reactions", "combo", "bonus", "album", "shop", "celebration"]:
		return false
	_seed_progress(main)
	match route:
		"menu":
			main.show_menu()
		"game", "win":
			if not _open_nonogram(main, route == "win"):
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
			main._open_meta(MetaScreen.Page.ALBUM)
		"shop":
			var save := main.get_node("/root/Save")
			save.data.coins = 1450
			save.data.meta.purchased.mint_visor = true
			save.data.meta.equipped.helmet = "mint_visor"
			var screen := main._open_meta(MetaScreen.Page.SHOP)
			screen._preview_costume("violet_visor")
		"celebration":
			if not _open_celebration(main):
				push_error("The QA album could not reach a tier four celebration")
				return false
	var document := JavaScriptBridge.get_interface("document")
	document.documentElement.setAttribute("data-velokity-qa-screen", route)
	return true


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
	if screen._celebration.tier != 4:
		return false
	screen._celebration.freeze_at(0.62)
	return true
