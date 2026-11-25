extends SceneTree

const SaveScript := preload("res://scripts/autoload/save.gd")
const FakeAds := preload("res://scripts/ads/fake_ads.gd")
const Puzzle := preload("res://scripts/nonogram/puzzle.gd")
const Catalog := preload("res://scripts/nonogram/catalog.gd")
const Board := preload("res://ui/board.gd")

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_save()
	_test_economy()
	_test_catalog()
	_test_puzzle()
	_test_drag()
	_test_fake_ads()
	var locale := TranslationServer.get_locale()
	TranslationServer.set_locale("id")
	check(TranslationServer.translate("MENU_PLAY") == "Main nonogram", "Indonesian translation")
	TranslationServer.set_locale("fr")
	check(TranslationServer.translate("MENU_PLAY") == "Play nonogram", "English fallback")
	TranslationServer.set_locale(locale)
	print("%d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 and checks > 0 else 1)


func _test_save() -> void:
	var save := SaveScript.new()
	var path := "user://test-%d.json" % OS.get_process_id()
	check(save.load_game(path) == OK and save.data.coins == 0, "Defaults for a missing save")
	check(SaveScript.migrate({"coins": 22}).coins == 22, "Migrate a legacy save")
	check(SaveScript.migrate({"version": 99}).is_empty(), "Reject a future schema")
	check(SaveScript.migrate({"coins": -5}).coins == 0, "Sanitize invalid coins")
	var snapshot := SaveScript.defaults()
	snapshot.coins = 17
	check(save.write_game(snapshot, path) == OK, "Write a save")
	save.data = SaveScript.defaults()
	check(save.load_game(path) == OK and save.data.coins == 17, "Read back the persisted balance")
	DirAccess.remove_absolute(path)
	save.free()


func _test_fake_ads() -> void:
	var fake := FakeAds.new()
	check(fake.show_rewarded(&"hint"), "Fake ads can grant rewards")
	fake.grant_rewards = false
	check(not fake.show_rewarded(&"hint"), "Fake ads can simulate unavailable rewards")


func check(result: bool, description: String) -> void:
	checks += 1
	if not result:
		failures += 1
		printerr("FAIL: " + description)


func _test_economy() -> void:
	var save := root.get_node("Save")
	var economy := root.get_node("Economy")
	var previous_data: Dictionary = save.data
	var previous_path: String = save.storage_path
	save.storage_path = "user://test-economy-%d.json" % OS.get_process_id()
	save.data = SaveScript.defaults()
	check(not economy.spend(1), "Reject overspending")
	check(not economy.earn(0) and not economy.spend(-1), "Reject non-positive transactions")
	check(economy.earn(5) and economy.balance() == 5, "Earn coins")
	check(economy.spend(3) and economy.balance() == 2, "Spend coins")
	check(save.load_game(save.storage_path) == OK and economy.balance() == 2, "Persist transactions")
	DirAccess.remove_absolute(save.storage_path)
	save.data = previous_data
	save.storage_path = previous_path


func _test_catalog() -> void:
	var levels := Catalog.read()
	check(levels.size() == 60, "Read all 60 puzzle files")
	if levels.size() == 60:
		check(levels[0].planet == "moon" and levels[0].size == 5, "Moon album comes first")
		check(levels[20].planet == "mars" and levels[20].size == 8, "Mars album comes second")
		check(levels[40].planet == "saturn" and levels[40].size == 10, "Saturn album comes third")


func _test_puzzle() -> void:
	check(Puzzle.clues(PackedByteArray([0, 0])).is_empty(), "Empty clue")
	check(Puzzle.clues(PackedByteArray([1, 1, 0, 1])) == PackedInt32Array([2, 1]), "Separated clue runs")
	var level := {"size": 3, "solution": ["a.a", "aa.", "..."], "palette": {"a": "#ffcc66"}}
	var puzzle := Puzzle.new(level)
	check(puzzle.row_clues[0] == PackedInt32Array([1, 1]), "Read row clues")
	check(puzzle.column_clues[0] == PackedInt32Array([2]), "Read column clues")
	check(puzzle.rows_done[2] == 1 and puzzle.at(Vector2i(0, 2)) == Puzzle.Cell.CROSSED, "Auto-cross an empty row")
	puzzle.mark(Vector2i(-1, 0), false)
	check(puzzle.lives == 3, "Ignore out-of-bounds marks")
	puzzle.mark(Vector2i(0, 0), true)
	check(puzzle.lives == 2 and puzzle.at(Vector2i.ZERO) == Puzzle.Cell.UNKNOWN, "An incorrect X loses one life")
	puzzle.mark(Vector2i(2, 1), true)
	check(puzzle.lives == 2 and puzzle.at(Vector2i(2, 1)) == Puzzle.Cell.CROSSED, "Mark an empty cell with X")
	check(puzzle.hint() and puzzle.at(Vector2i.ZERO) == Puzzle.Cell.FILLED, "Hint fills one correct cell")
	check(puzzle.at(Vector2i(2, 0)) == Puzzle.Cell.UNKNOWN and puzzle.state == Puzzle.State.PLAYING, "Hint leaves other cells alone")
	puzzle.mark(Vector2i.ZERO, true)
	check(puzzle.lives == 2, "A completed cell is locked")
	puzzle.mark(Vector2i(2, 0), false)
	check(puzzle.rows_done[0] == 1 and puzzle.at(Vector2i(1, 0)) == Puzzle.Cell.CROSSED, "Auto-cross a finished row")
	puzzle.mark(Vector2i(1, 1), false)
	check(puzzle.columns_done[1] == 1, "Detect a finished column")
	puzzle.mark(Vector2i(0, 1), false)
	check(puzzle.state == Puzzle.State.WON and puzzle.reveal(Vector2i.ZERO) == Color("#ffcc66"), "Win reveals the picture in color")
	check(not puzzle.hint(), "Hints stop after a win")
	var losing := Puzzle.new(level)
	for attempt in range(3):
		losing.mark(Vector2i(1, 0), false)
	check(losing.state == Puzzle.State.LOST and losing.lives == 0, "Lose after three mistakes")
	losing.mark(Vector2i.ZERO, false)
	check(losing.at(Vector2i.ZERO) == Puzzle.Cell.UNKNOWN and not losing.hint(), "Ignore play after a loss")


func _test_drag() -> void:
	var board := Board.new()
	board.puzzle = Puzzle.new({"size": 3, "solution": ["aaa", "a..", "a.."], "palette": {}})
	root.add_child(board)
	board.size = board.custom_minimum_size
	var grid := board._grid()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = grid.position + Vector2.ONE * 10
	board._gui_input(press)
	board.drag_to(Vector2i(2, 0))
	board.drag_to(Vector2i(2, 2))
	check(board.puzzle.rows_done[0] == 1, "Drag fills skipped cells between motion events")
	check(board.puzzle.at(Vector2i(0, 1)) == Puzzle.Cell.UNKNOWN and board.puzzle.lives == 3, "Drag remains locked to one axis")
	board.cancel_drag()
	board.drag_to(Vector2i(0, 2))
	check(board.puzzle.at(Vector2i(0, 2)) == Puzzle.Cell.UNKNOWN, "Canceled drag cannot mark cells")
	board._gui_input(press)
	board.drag_to(Vector2i(0, 2))
	check(board.puzzle.state == Puzzle.State.WON, "A new drag can select the other axis")
	board.free()
