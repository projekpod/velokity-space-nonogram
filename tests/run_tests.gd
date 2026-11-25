extends SceneTree

const SaveScript := preload("res://scripts/autoload/save.gd")
const FakeAds := preload("res://scripts/ads/fake_ads.gd")
const Puzzle := preload("res://scripts/nonogram/puzzle.gd")
const Catalog := preload("res://scripts/nonogram/catalog.gd")
const Board := preload("res://ui/board.gd")
const Daily := preload("res://scripts/daily/calendar.gd")
const DailyPuzzle := preload("res://scripts/daily/puzzle.gd")

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
	_test_daily_selection()
	_test_daily_puzzle()
	_test_daily_rewards()
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


func _test_daily_selection() -> void:
	var monday := Daily.day_number({"year": 2026, "month": 11, "day": 23})
	check(Daily.weekday(monday) == 0 and Daily.weekday(monday + 6) == 6, "Week runs Monday through Sunday")
	check(Daily.puzzle_name(monday) == Daily.puzzle_name(monday + 18 * 7), "Monday rotates through 18 boards")
	check(Daily.puzzle_name(monday + 1) == Daily.puzzle_name(monday + 17 * 7 + 1), "Tuesday rotates through 17 boards")
	check(Daily.puzzle_name(monday) != Daily.puzzle_name(monday + 7), "Same weekday changes next week")
	var previous_effort := 0
	for offset in range(7):
		var puzzle := Daily.puzzle_for(monday + offset)
		check(not puzzle.is_empty() and puzzle.get("difficulty") == offset + 1, "Load weekday tier %d" % (offset + 1))
		check(puzzle.get("effort", 0) > previous_effort, "Effort increases on weekday %d" % (offset + 1))
		previous_effort = int(puzzle.get("effort", 0))
	var year_end := Daily.day_number({"year": 2025, "month": 12, "day": 31})
	var new_year := Daily.day_number({"year": 2026, "month": 1, "day": 1})
	check(new_year == year_end + 1, "Consecutive dates across New Year")
	var leap := Daily.day_number({"year": 2024, "month": 2, "day": 29})
	check(Daily.day_number({"year": 2024, "month": 3, "day": 1}) == leap + 1, "Consecutive dates across leap day")


func _test_daily_puzzle() -> void:
	var level := Daily.puzzle_for(20780)
	if level.is_empty():
		check(false, "Load a daily puzzle to test")
		return
	var puzzle := DailyPuzzle.new(level)
	var first_star := Vector2i(int(level.solution[0]), 0)
	var wrong := Vector2i((first_star.x + 1) % puzzle.size, 0)
	puzzle.place(Vector2i(-1, 0), false)
	check(puzzle.lives == 3, "Daily starts with 3 lives and ignores out of bounds")
	puzzle.place(first_star, true)
	check(puzzle.has_note(first_star) and puzzle.lives == 3, "Daily notes are reversible and free")
	puzzle.place(first_star, true)
	check(not puzzle.has_note(first_star), "Tap again removes a note")
	puzzle.place(wrong, false)
	check(puzzle.lives == 2 and not puzzle.is_star(wrong), "An incorrect daily star costs one life")
	var used_columns := {}
	var used_regions := {}
	var no_touch := true
	for y in range(puzzle.size):
		var star := Vector2i(int(level.solution[y]), y)
		puzzle.place(star, false)
		used_columns[star.x] = true
		used_regions[puzzle.region_at(star)] = true
		if y > 0 and absi(puzzle.stars[y - 1] - star.x) <= 1:
			no_touch = false
	check(puzzle.state == DailyPuzzle.State.WON and puzzle.lives == 2, "Every row needs a star to win")
	check(used_columns.size() == puzzle.size and used_regions.size() == puzzle.size, "Every column and region has one star")
	check(no_touch, "Winning stars do not touch")
	var losing := DailyPuzzle.new(level)
	for attempt in range(3):
		losing.place(wrong, false)
	losing.place(first_star, false)
	check(losing.lives == 0 and losing.state == DailyPuzzle.State.LOST and not losing.is_star(first_star), "Loss locks daily board after three strikes")


func _test_daily_rewards() -> void:
	var previous := SaveScript.migrate({"version": 1, "coins": 80, "settings": {"language": "id"}})
	check(previous.version == 2 and previous.coins == 80 and previous.settings.language == "id", "Migrate V1 without losing balance or settings")
	check(previous.daily == Daily.empty_progress(), "V1 starts with an empty daily streak")
	check(SaveScript.migrate({"daily": {"last_day": 1.25, "streak": 2}}).daily.streak == 0, "Reject fractional saved dates")
	var save := root.get_node("Save")
	var economy := root.get_node("Economy")
	var original: Dictionary = save.data
	var original_path: String = save.storage_path
	var path := "user://test-daily-%d.json" % OS.get_process_id()
	save.storage_path = path
	save.data = previous
	var first_day := 21000
	var expected_balance := 80
	for index in range(Daily.REWARDS.size()):
		var amount: int = Daily.REWARDS[index]
		expected_balance += amount
		check(economy.award_daily(first_day + index) == amount, "Collect reward %d" % index)
	check(save.data.daily.streak == 7 and Daily.collected_slots(save.data.daily, first_day + 6) == 7, "Show all rewards claimed on day seven")
	check(Daily.collected_slots(save.data.daily, first_day + 7) == 0, "New reward calendar starts the next day")
	check(save.load_game(path) == OK and economy.balance() == expected_balance, "Restore streak and coins together from disk")
	check(economy.award_daily(first_day + 6) == 0 and economy.award_daily(first_day + 5) == 0, "Reload and clock rollback cannot claim again")
	check(economy.award_daily(first_day + 7) == Daily.REWARDS[0] and save.data.daily.streak == 8, "Streak continues after a calendar cycle")
	check(Daily.active_streak(save.data.daily, first_day + 9) == 0, "Missed date clears the displayed streak")
	check(economy.award_daily(first_day + 9) == Daily.REWARDS[0] and save.data.daily.streak == 1, "A gap starts over at day one")
	var latest: Dictionary = save.data.duplicate(true)
	save.storage_path = path + "/missing-dir/save.json"
	check(economy.award_daily(first_day + 10) == -1 and save.data == latest, "Failed write cannot grant coins or advance the streak")
	save.storage_path = path
	check(economy.award_daily(first_day + 10) == Daily.REWARDS[1], "A failed claim can be retried once")
	DirAccess.remove_absolute(path)
	save.data = original
	save.storage_path = original_path
