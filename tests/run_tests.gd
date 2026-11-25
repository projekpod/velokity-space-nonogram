extends SceneTree

const SaveScript := preload("res://scripts/autoload/save.gd")
const AdsScript := preload("res://scripts/autoload/ads.gd")
const FakeAds := preload("res://scripts/ads/fake_ads.gd")
const AdsProvider := preload("res://scripts/ads/ads_provider.gd")
const Puzzle := preload("res://scripts/nonogram/puzzle.gd")
const Catalog := preload("res://scripts/nonogram/catalog.gd")
const Board := preload("res://ui/board.gd")
const Daily := preload("res://scripts/daily/calendar.gd")
const DailyPuzzle := preload("res://scripts/daily/puzzle.gd")

var checks := 0
var failures := 0


class SilentAds extends AdsProvider:
	func request_rewarded(_placement: StringName, _request_id: int) -> void:
		pass

	func request_interstitial(_request_id: int) -> void:
		pass


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_save()
	_test_save_recovery()
	_test_economy()
	_test_catalog()
	_test_puzzle()
	_test_hint()
	_test_board_size()
	_test_drag()
	await _test_fake_ads()
	await _test_ads_recovery()
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


func _test_save_recovery() -> void:
	var directory := "user://save-test-%d" % OS.get_process_id()
	check(DirAccess.make_dir_absolute(directory) == OK, "Create an isolated save test directory")
	var save := SaveScript.new()
	var path := directory.path_join("save.json")
	save.storage_path = path
	save.data.coins = 20
	var corrupt := "{broken"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(corrupt)
	file.close()
	check(save.load_game() == OK and save.data.coins == 0, "Unreadable JSON recovers to defaults")
	var archived := DirAccess.get_files_at(directory)
	check(archived.size() == 1 and archived[0].begins_with("save.corrupt-"), "Keep the corrupt save under a dated archive name")
	if not archived.is_empty():
		check(FileAccess.get_file_as_string(directory.path_join(archived[0])) == corrupt, "Archive preserves the exact broken bytes")
	var snapshot := SaveScript.defaults()
	snapshot.coins = 12
	check(save.write_game(snapshot) == OK and save.load_game() == OK and save.data.coins == 12, "Allow writes after recovering a corrupt save")
	var newer := JSON.stringify({"version": SaveScript.VERSION + 1, "coins": 50})
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(newer)
	file.close()
	check(save.load_game() == ERR_FILE_UNRECOGNIZED, "A newer version stays protected")
	check(save.write_game(snapshot) == ERR_FILE_UNRECOGNIZED, "Refuse default-path writes to a newer save")
	check(save.write_game(snapshot, path) == ERR_FILE_UNRECOGNIZED, "An explicit path cannot bypass newer-save protection")
	check(FileAccess.get_file_as_string(path) == newer and DirAccess.get_files_at(directory).size() == 2, "Keep the newer save and existing archive intact")
	for name in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(name))
	DirAccess.remove_absolute(directory)
	save.free()


func _test_fake_ads() -> void:
	var ads := AdsScript.new()
	var fake := FakeAds.new()
	check(ads.set_provider(fake), "Configure an ad provider before startup")
	root.add_child(ads)
	var player := AudioStreamPlayer.new()
	root.add_child(player)
	var stream := AudioStreamWAV.new()
	var samples := PackedByteArray()
	samples.resize(8192)
	stream.mix_rate = 44100
	stream.data = samples
	player.stream = stream
	player.play()
	var results: Array[Array] = []
	ads.rewarded_finished.connect(func(placement: StringName, granted: bool) -> void:
		results.append([placement, granted])
	)
	check(not ads.request_rewarded(&"other") and not paused, "Reject unknown reward placements")
	check(ads.request_rewarded(&"hint"), "Accept a rewarded request")
	check(results.is_empty(), "No reward before the provider completion")
	check(paused and not player.can_process() and player.stream_paused, "An ad pauses game processing and active audio")
	check(not ads.request_rewarded(&"continue") and not ads.set_provider(FakeAds.new()), "Reject overlapping ads or provider swaps")
	var rewarded: Array = await ads.rewarded_finished
	check(rewarded == [&"hint", true] and results.size() == 1, "Granted reward arrives once and includes its placement")
	check(not paused and player.can_process() and not player.stream_paused, "Ad completion resumes gameplay and audio")
	fake.grant_rewards = false
	paused = true
	check(ads.request_rewarded(&"continue"), "Accept an ad while the game was already paused")
	var denied: Array = await ads.rewarded_finished
	check(denied == [&"continue", false], "Unavailable reward finishes without a grant")
	check(paused, "Finishing an ad preserves a pause that started before it")
	paused = false
	check(not ads.request_interstitial_after_result(10), "No interstitial in the first two session minutes")
	ads._session_started = Time.get_ticks_msec() - 120000
	check(not ads.request_interstitial_after_result(9), "No interstitial before level ten")
	check(ads.request_interstitial_after_result(10) and paused, "An eligible interstitial pauses the game")
	await ads.interstitial_closed
	check(not paused and fake.interstitial_count == 1, "Interstitial close resumes gameplay exactly once")
	check(not ads.request_interstitial_after_result(10), "Interstitial close begins a ninety-second cooldown")
	ads.set_gameplay_banner(true)
	check(fake.banner_visible, "Banner visibility reaches the provider")
	# Let the resumed sample finish so the audio mixer can release its playback.
	if player.playing:
		await player.finished
	player.stream = null
	player.queue_free()
	ads.queue_free()
	await process_frame


func check(result: bool, description: String) -> void:
	checks += 1
	if not result:
		failures += 1
		printerr("FAIL: " + description)


func _test_ads_recovery() -> void:
	var ads := AdsScript.new()
	var provider := SilentAds.new()
	ads.set_provider(provider)
	root.add_child(ads)
	var rewards: Array = []
	var interstitials: Array = []
	ads.rewarded_finished.connect(func(placement: StringName, granted: bool) -> void:
		rewards.append([placement, granted])
	)
	ads.interstitial_closed.connect(func() -> void: interstitials.append(true))
	check(ads.request_rewarded(&"hint") and paused, "Silent rewarded request pauses the game")
	check(ads._timeout.wait_time == 45.0 and ads._timeout.time_left > 0, "The watchdog starts with a 45-second deadline")
	ads._timeout.start(0.02)
	await create_timer(0.10).timeout
	check(not paused and rewards == [[&"hint", false]], "Rewarded timeout resumes the game without a grant")
	ads._session_started = Time.get_ticks_msec() - 120000
	check(ads.request_interstitial_after_result(10) and paused, "Accept a new ad after the timeout")
	provider.rewarded_finished.emit(1, true)
	await process_frame
	check(paused and rewards.size() == 1, "Ignore a late result from the timed-out request")
	await create_timer(0.10).timeout
	check(not paused and interstitials.size() == 1, "Silent interstitial closes on timeout")
	check(ads.request_rewarded(&"continue"), "Accept another ad after the interstitial timeout")
	provider.request_failed.emit(ads._request_id)
	await process_frame
	check(not paused and rewards == [[&"hint", false], [&"continue", false]], "Provider errors deny rewards and resume the game")
	ads._last_interstitial = Time.get_ticks_msec() - 90000
	check(ads.request_interstitial_after_result(10), "Accept an eligible interstitial after recovery")
	provider.request_failed.emit(ads._request_id)
	await process_frame
	check(not paused and interstitials.size() == 2, "Provider errors close interstitials")
	ads.queue_free()
	await process_frame


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
	check(puzzle.lives == 2 and puzzle.at(Vector2i.ZERO) == Puzzle.Cell.FILLED, "An incorrect X spends one life and reveals the fill")
	puzzle.mark(Vector2i.ZERO, true)
	check(puzzle.lives == 2, "Tapping the same incorrect X twice costs one life total")
	puzzle.mark(Vector2i(2, 1), true)
	check(puzzle.lives == 2 and puzzle.at(Vector2i(2, 1)) == Puzzle.Cell.CROSSED, "Mark an empty cell with X")
	puzzle.mark(Vector2i(2, 0), false)
	check(puzzle.rows_done[0] == 1 and puzzle.at(Vector2i(1, 0)) == Puzzle.Cell.CROSSED, "Auto-cross a finished row")
	puzzle.mark(Vector2i(1, 1), false)
	check(puzzle.columns_done[1] == 1, "Detect a finished column")
	puzzle.mark(Vector2i(0, 1), true)
	check(puzzle.state == Puzzle.State.WON and puzzle.lives == 1, "Correcting a wrong X checks the final win")
	check(puzzle.rows_done[1] == 1 and puzzle.columns_done[0] == 1, "An auto-filled cell checks both lines")
	check(puzzle.reveal(Vector2i.ZERO) == Color("#ffcc66"), "Win reveals the picture in color")
	check(not puzzle.hint(), "Hints stop after a win")
	var losing := Puzzle.new(level)
	var empty := Vector2i(1, 0)
	losing.mark(empty, false)
	losing.mark(empty, false)
	check(losing.lives == 2 and losing.at(empty) == Puzzle.Cell.CROSSED, "Tapping the same incorrect fill twice costs one life total")
	losing.mark(Vector2i(2, 1), false)
	losing.mark(Vector2i(1, 1), true)
	check(losing.state == Puzzle.State.LOST and losing.lives == 0, "Lose on the third distinct mistake")
	check(losing.at(Vector2i(1, 1)) == Puzzle.Cell.FILLED, "The last mistake is still corrected")
	losing.mark(Vector2i.ZERO, false)
	check(losing.at(Vector2i.ZERO) == Puzzle.Cell.UNKNOWN and not losing.hint(), "Ignore play after a loss")


func _test_hint() -> void:
	var rows := ["aaaa", "a..a", "..a.", "a..a"]
	for horizontal: bool in [true, false]:
		var solution := rows
		if not horizontal:
			solution = ["aa.a", "a...", "a.a.", "aa.a"]
		var puzzle := Puzzle.new({"size": 4, "solution": solution, "palette": {}})
		for index in range(3):
			var known := Vector2i(index, 3) if horizontal else Vector2i(3, index)
			puzzle.mark(known, index != 0)
		check(puzzle.hint(), "Hint reveals one cell")
		check(puzzle.at(Vector2i(3, 3)) == Puzzle.Cell.FILLED, "Hint targets the shortest unfinished row or column")
		check(puzzle.at(Vector2i.ZERO) == Puzzle.Cell.UNKNOWN, "Hint leaves an unrelated top-left cell alone")


func _test_drag() -> void:
	var board := Board.new()
	board.puzzle = Puzzle.new({"size": 3, "solution": ["aaa", "a..", "a.."], "palette": {}})
	root.add_child(board)
	board.size = board.get_combined_minimum_size()
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

	var mistake_board := Board.new()
	var rows := ["a...a", "aaaaa", "aaaaa", "aaaaa", "aaaaa"]
	mistake_board.puzzle = Puzzle.new({"size": 5, "solution": rows, "palette": {}})
	root.add_child(mistake_board)
	mistake_board.size = mistake_board.get_combined_minimum_size()
	press.position = mistake_board._grid().position + Vector2.ONE * 10
	mistake_board._gui_input(press)
	mistake_board.drag_to(Vector2i(3, 0))
	mistake_board.drag_to(Vector2i(4, 0))
	check(mistake_board.puzzle.lives == 2, "One drag across three wrong cells costs just one life")
	check(mistake_board.puzzle.at(Vector2i(1, 0)) == Puzzle.Cell.CROSSED, "A drag corrects the first mistake")
	for index in range(2, 5):
		check(mistake_board.puzzle.at(Vector2i(index, 0)) == Puzzle.Cell.UNKNOWN, "Drag stops before cell %d" % index)
	mistake_board.free()


func _test_board_size() -> void:
	for row in ["a.a.a.a.a.", "aaaaaaaaaa"]:
		var rows: Array = []
		rows.resize(10)
		rows.fill(row)
		var board := Board.new()
		board.puzzle = Puzzle.new({"size": 10, "solution": rows, "palette": {}})
		root.add_child(board)
		board.size = board.get_combined_minimum_size()
		var grid := board._grid()
		check(grid.size.x / 10 >= 56.0, "10x10 cells are at least 56 pixels at base width")
		var expected_gutter := 128.0 if row.contains(".") else 32.0
		check(grid.position.x == expected_gutter and is_equal_approx(grid.end.x, Board.WIDTH - 4.0), "Clue gutter uses only the width it needs")
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
	puzzle.place(wrong, true)
	puzzle.place(wrong, false)
	puzzle.place(wrong, false)
	puzzle.place(wrong, true)
	check(puzzle.lives == 2 and puzzle.is_eliminated(wrong), "The same wrong daily star costs exactly one life")
	check(not puzzle.has_note(wrong) and not puzzle.is_star(wrong), "An eliminated cell stays blocked in both modes")
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
	for offset in range(1, 4):
		losing.place(Vector2i((first_star.x + offset) % puzzle.size, 0), false)
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
