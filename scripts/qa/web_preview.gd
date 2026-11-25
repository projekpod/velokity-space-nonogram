extends RefCounted

const Main := preload("res://ui/main.gd")
const SaveScript := preload("res://scripts/autoload/save.gd")
const Catalog := preload("res://scripts/nonogram/catalog.gd")
const Daily := preload("res://scripts/daily/calendar.gd")
const Puzzle := preload("res://scripts/nonogram/puzzle.gd")
const Gallery := preload("res://scripts/qa/mascot_gallery.gd")


static func open(main: Main) -> bool:
	var route: Variant = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('qa')", true)
	if route not in ["menu", "game", "win", "daily", "mascot", "reactions"]:
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
	var document := JavaScriptBridge.get_interface("document")
	document.documentElement.setAttribute("data-velokity-qa-screen", route)
	return true


static func _seed_progress(main: Main) -> void:
	var snapshot := SaveScript.defaults()
	snapshot.coins = 120
	snapshot.daily = {"last_day": Daily.today() - 1, "streak": 3}
	for planet in ["moon", "mars"]:
		var indices := main._planet_levels(planet)
		for index in indices.slice(0, Catalog.PLANET_CLEAR_REQUIREMENT):
			snapshot.nonogram[main._levels[index].id] = {"reward": 30, "doubled": false}
	main.get_node("/root/Save").data = snapshot


static func _open_nonogram(main: Main, won: bool) -> bool:
	var indices := main._planet_levels("saturn")
	if indices.is_empty():
		return false
	var screen := main._play(indices[0])
	if screen == null:
		return false
	var solution: Array = screen.level.solution
	for y in range(solution.size() if won else mini(4, solution.size())):
		for x in range(solution.size()):
			screen._puzzle.mark(Vector2i(x, y), solution[y][x] == ".")
	return screen._puzzle.state == (Puzzle.State.WON if won else Puzzle.State.PLAYING)
