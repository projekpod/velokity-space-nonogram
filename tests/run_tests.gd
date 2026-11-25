extends SceneTree

const SaveScript := preload("res://scripts/autoload/save.gd")
const EconomyRules := preload("res://scripts/autoload/economy.gd")
const AdsScript := preload("res://scripts/autoload/ads.gd")
const FakeAds := preload("res://scripts/ads/fake_ads.gd")
const BridgeAds := preload("res://scripts/ads/bridge_ads.gd")
const MonetizationConfig := preload("res://scripts/ads/monetization_config.gd")
const Purchases := preload("res://scripts/payments/purchase_provider.gd")
const AdsProvider := preload("res://scripts/ads/ads_provider.gd")
const Puzzle := preload("res://scripts/nonogram/puzzle.gd")
const Catalog := preload("res://scripts/nonogram/catalog.gd")
const Board := preload("res://ui/board.gd")
const Daily := preload("res://scripts/daily/calendar.gd")
const DailyPuzzle := preload("res://scripts/daily/puzzle.gd")
const NonogramScreen := preload("res://ui/nonogram_screen.gd")
const Mascot := preload("res://ui/mascot.gd")
const Backdrop := preload("res://ui/space_backdrop.gd")
const Combo := preload("res://scripts/nonogram/combo.gd")
const Bonus := preload("res://scripts/nonogram/bonus.gd")
const Celebration := preload("res://ui/celebration.gd")
const Meta := preload("res://scripts/meta/progression.gd")
const MetaScreen := preload("res://ui/meta_screen.gd")
const AlbumPicture := preload("res://ui/album_picture.gd")

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
	_test_settings()
	await _test_settings_menu()
	_test_economy()
	_test_combo_rewards_and_migration()
	_test_xp_migration()
	_test_costume_economy()
	_test_login_calendar()
	await _test_meta_menu()
	_test_catalog()
	await _test_level_progression()
	await _test_first_puzzle()
	await _test_bonus_flow()
	_test_puzzle()
	_test_continue()
	_test_hint()
	_test_board_size()
	_test_drag()
	await _test_fake_ads()
	await _test_ads_recovery()
	await _test_bridge_ads()
	await _test_banner_clearance()
	_test_support_config()
	_test_free_coin_quota()
	await _test_shop_monetization()
	await _test_nonogram_flow()
	await _test_mascot_reactions()
	await _test_calm_visuals()
	await _test_celebrations()
	await _test_milestone_celebrations()
	_test_daily_selection()
	_test_daily_puzzle()
	_test_daily_rewards()
	await _test_audio_smoke()
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
	ads.notify_game_ready()
	ads.set_gameplay_active(true)
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
	var first: int = economy.award_nonogram("moon-test", 3)
	check(first == 30 and economy.balance() == 32 and economy.is_nonogram_cleared("moon-test"), "First clear saves reward and progress together")
	check(economy.award_nonogram("moon-test", 1) == 0 and economy.balance() == 32, "A replay cannot collect coins")
	check(economy.double_nonogram_reward("other") == 0, "An uncleared level has no coins to double")
	check(economy.double_nonogram_reward("moon-test") == first and economy.balance() == 62, "Double grants the original reward once")
	check(save.load_game() == OK and economy.is_nonogram_cleared("moon-test") and economy.balance() == 62, "Reload progress and coins together")
	check(economy.double_nonogram_reward("moon-test") == 0 and economy.balance() == 62, "A reloaded save cannot claim double coins again")
	DirAccess.remove_absolute(save.storage_path)
	save.storage_path += "/fail.json"
	check(not economy.spend(10) and economy.balance() == 62, "Failed writes never spend coins")
	check(economy.award_nonogram("mars-test", 1) == -1 and not economy.is_nonogram_cleared("mars-test") and economy.balance() == 62, "Failed wins never change coins or progress")
	save.data = previous_data
	save.storage_path = previous_path


func _test_combo_rewards_and_migration() -> void:
	for level in range(1, 32):
		var expected := 2
		for unlock in [5, 10, 15, 20, 30]:
			expected += int(level >= unlock)
		check(Combo.theme_count(level) == expected, "Theme pool at player level %d" % level)
	check([0, 1, 2, 3, 4, 5, 6, 20].map(Combo.multiplier) == [1, 1, 1, 2, 3, 4, 5, 5], "Combo multipliers rise from three lines and stop at five")

	var save := root.get_node("Save")
	var economy := root.get_node("Economy")
	var previous_data: Dictionary = save.data
	var previous_path: String = save.storage_path
	var path := "user://test-combo-%d.json" % OS.get_process_id()
	save.storage_path = path
	var legacy := {
		"version": 3, "coins": 80, "settings": {"language": "id"},
		"daily": {"last_day": 22000, "streak": 2},
		"nonogram": {"legacy": {"reward": 25, "doubled": true}},
	}
	check(save.write_game(legacy) == OK and save.load_game() == OK, "Load a V3 save from disk into the current schema")
	check(save.data.version == SaveScript.VERSION and save.data.bonus_clears == 0 and economy.badge_count() == 0, "V3 initializes badge and bonus progress without granting badges")
	check(economy.player_level() == 2 and save.data.daily.clears == 2 and save.data.settings.language == "id", "Legacy daily history starts at the known streak and contributes to the player level")
	check(economy.award_nonogram("legacy", 2, 6) == 0 and not economy.has_flawless_badge("legacy") and save.data.meta.xp == 300, "An imperfect replay grants zero coins and no badge")
	check(economy.award_nonogram("legacy", 3, 6) == 0 and economy.has_flawless_badge("legacy") and save.data.meta.xp == 320, "A flawless replay earns its badge with zero coins")
	check(save.load_game() == OK and economy.badge_count() == 1 and economy.balance() == 80, "Badge and balance persist on replay")
	check(economy.award_nonogram("legacy", 3, 6) == 0 and economy.badge_count() == 1 and save.data.meta.xp == 320, "The same level never grants a second badge")
	check(save.data.nonogram.legacy.reward == 25 and economy.double_nonogram_reward("legacy") == 0, "Preserve the historical win reward and ad claim")
	check(economy.award_nonogram("combo-x2", 1, 3) == 40 and economy.player_level() == 3, "An x2 first clear pays twice the base and counts once for player level")
	check(economy.award_nonogram("combo-cap", 3, 8) == 60 and economy.has_flawless_badge("combo-cap") and save.data.meta.xp == 540, "First-clear reward caps base and combo at 60 and saves the flawless badge")
	check(economy.award_daily(22002) == 10 and save.data.daily.streak == 1 and economy.player_level() == 4, "First daily clear after a streak gap increases lifetime progress")
	check(economy.award_daily(22002) == 0 and save.data.daily.clears == 3 and save.data.meta.xp == 640, "A daily replay never adds to lifetime progress")
	var snapshot: Dictionary = save.data.duplicate(true)
	save.storage_path = path + "/missing-dir/save.json"
	check(economy.award_nonogram("unwritten", 3, 6) == -1 and save.data == snapshot, "Failed first-clear write leaves the coins, badge and progress intact")
	save.storage_path = path
	check(save.load_game() == OK and save.data == snapshot, "Reload current badges, capped reward and daily count together")
	DirAccess.remove_absolute(path)
	save.storage_path = previous_path
	save.data = previous_data


func _test_settings() -> void:
	var save := root.get_node("Save")
	var settings := root.get_node("Settings")
	var events := root.get_node("Events")
	var previous_data: Dictionary = save.data
	var previous_path: String = save.storage_path
	var previous_locale := TranslationServer.get_locale()
	save.storage_path = "user://test-settings-%d.json" % OS.get_process_id()
	save.data = SaveScript.defaults()
	check(settings.set_value("sound", false) and settings.set_value("music", false), "Save sound and music separately")
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")) and AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "Mute existing audio buses when settings change")
	check(settings.set_value("sound", true) and not AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")) and AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "Sound toggle does not change music")
	check(settings.set_value("vibration", false) and settings.set_value("calm_mode", true), "Save vibration and Calm Mode")
	check(settings.set_value("language", "id") and TranslationServer.get_locale() == "id", "Apply the saved language immediately")
	check(not settings.set_value("language", "es") and not settings.set_value("sound", "false"), "Reject unsupported language and setting types")
	save.data = SaveScript.defaults()
	check(save.load_game() == OK and settings.get_value("language") == "id" and settings.get_value("calm_mode"), "Read back language and Calm Mode")
	check(not settings.get_value("vibration") and not settings.get_value("music") and settings.get_value("sound"), "Read back audio and vibration")
	check(settings.set_value("language", "") and TranslationServer.get_locale() == settings._device_locale, "Device language can be restored")
	DirAccess.remove_absolute(save.storage_path)
	save.data = previous_data
	save.storage_path = previous_path
	TranslationServer.set_locale(previous_locale)
	events.settings_changed.emit()


func _test_nonogram_flow() -> void:
	var save := root.get_node("Save")
	var ads := root.get_node("Ads")
	var previous_data: Dictionary = save.data
	var previous_path: String = save.storage_path
	var fake := FakeAds.new()
	ads.set_provider(fake)
	save.storage_path = "user://test-game-flow-%d.json" % OS.get_process_id()
	save.data = SaveScript.defaults()
	save.data.coins = 80
	save.data.settings.vibration = false
	var screen := NonogramScreen.new()
	screen.level = {
		"id": "screen-test", "size": 3, "solution": ["aaa", "a..", "a.."],
		"palette": {}, "title": {"en": "Test", "id": "Tes"},
	}
	root.add_child(screen)
	var puzzle: Puzzle = screen._puzzle
	check(fake.banner_visible and screen._tools.visible and not screen._result.visible, "Banner and controls appear in gameplay")
	var hint_cell := puzzle.hint_cell()
	screen._hint.pressed.emit()
	check(puzzle.at(hint_cell) == Puzzle.Cell.FILLED and save.data.coins == 50, "A paid hint changes exactly the selected cell and spends 30 coins")
	for cell in [Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 2)]:
		puzzle.mark(cell, false)
	check(puzzle.state == Puzzle.State.LOST and not fake.banner_visible and screen._result.visible, "Loss opens a result with the banner hidden")
	screen._continue.pressed.emit()
	check(puzzle.state == Puzzle.State.PLAYING and puzzle.lives == 1 and save.data.coins == 0, "Paid continue spends 50 coins and resumes the same board with one life")
	check(puzzle.at(hint_cell) == Puzzle.Cell.FILLED and not puzzle.can_continue() and screen._hint.disabled, "Continuation retains marks and disables unaffordable hints")
	fake.grant_rewards = false
	var next_hint := puzzle.hint_cell()
	screen._request_ad(&"hint")
	await ads.rewarded_finished
	check(puzzle.at(next_hint) == Puzzle.Cell.UNKNOWN and save.data.coins == 0, "An ad denial never applies a hint")
	fake.grant_rewards = true
	screen._request_ad(&"hint")
	await ads.rewarded_finished
	check(puzzle.at(next_hint) == Puzzle.Cell.FILLED and save.data.coins == 0, "A rewarded ad only applies its hint after the grant")
	for cell in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(0, 2)]:
		puzzle.mark(cell, false)
	check(puzzle.state == Puzzle.State.WON and screen._result.visible and save.data.coins == 60, "A win opens a result and saves its capped first-clear coins")
	screen._request_ad(&"double_coins")
	await ads.rewarded_finished
	check(save.data.coins == 120 and save.data.nonogram["screen-test"].doubled, "A granted double ad persists the separate ad reward")
	screen.queue_free()
	await process_frame
	check(not fake.banner_visible, "Leaving the game clears the banner")
	DirAccess.remove_absolute(save.storage_path)
	save.data = previous_data
	save.storage_path = previous_path


func _test_first_puzzle() -> void:
	var save := root.get_node("Save")
	var original: Dictionary = save.data
	var original_path: String = save.storage_path
	var path := "user://test-onboarding-%d.json" % OS.get_process_id()
	save.storage_path = path
	save.load_game()
	var main := preload("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var screen := main._column.get_child(0) as NonogramScreen
	check(screen != null and screen.first_puzzle and screen.level == main._levels[0], "Fresh save lands in the first Moon puzzle")
	var step_text := screen._tutorial_text.text
	check(screen.tutorial_step == 0 and _press_button(screen._tutorial, "TUTORIAL_NEXT") and screen._tutorial_text.text != step_text, "First tutorial step advances to X mode")
	check(_press_button(screen._tutorial, "TUTORIAL_NEXT") and screen.tutorial_step == 2, "Third tutorial step explains clues")
	check(_press_button(screen._tutorial, "TUTORIAL_SKIP") and not screen._tutorial.visible, "Skip leaves the puzzle playable")
	screen._leave(&"retry")
	screen = main._column.get_child(0) as NonogramScreen
	check(screen.first_puzzle and screen._tutorial == null and not save.data.onboarding_complete, "Retry preserves an in-session skip without completing onboarding")
	_solve_nonogram(screen)
	screen._celebration.dismiss()
	check(save.data.onboarding_complete and _press_button(screen._result, "GAME_BACK"), "The saved first win opens the main menu")
	check(_press_button(main._column, "MENU_PLAY"), "Main menu is available after onboarding")
	main.free()
	check(save.load_game() == OK and save.data.onboarding_complete, "The first clear and onboarding completion survive reload")
	for snapshot: Dictionary in [save.data, SaveScript.migrate({"version": 6})]:
		save.data = snapshot
		main = preload("res://scenes/main.tscn").instantiate()
		root.add_child(main)
		check(_press_button(main._column, "MENU_PLAY"), "Returning saves still start in the menu")
		main.free()
	DirAccess.remove_absolute(path)
	save.data = original
	save.storage_path = original_path
	await process_frame


func _test_mascot_reactions() -> void:
	var save := root.get_node("Save")
	var previous_data: Dictionary = save.data
	var previous_path: String = save.storage_path
	save.data = SaveScript.defaults()
	save.data.settings.vibration = false
	save.storage_path = "user://test-mascot-%d.json" % OS.get_process_id()
	var screen := NonogramScreen.new()
	screen.level = {
		"id": "mascot-test", "size": 4, "solution": ["a...", ".a..", "..a.", "...a"],
		"palette": {}, "title": {"en": "Test", "id": "Tes"},
	}
	root.add_child(screen)
	var mascot := screen._portrait.mascot
	var board := screen._board
	screen._puzzle.mark(Vector2i.ZERO, false)
	check(mascot._reaction == Mascot.Reaction.FILL and board._fills.has(Vector2i.ZERO), "A correct mark reacts and bounces")
	check(screen._correct_lines == 2 and board._rows.has(0) and board._columns.has(0), "A correct fill can complete and light both lines")
	screen._puzzle.mark(Vector2i(1, 1), false)
	check(mascot._reaction == Mascot.Reaction.COMBO and screen._correct_lines == 4, "Cross the three-line combo threshold without a mistake")
	check(screen._celebration.tier == 2 and screen._combo_theme in [0, 1], "A level-one combo uses an unlocked theme and a tier two overlay")
	screen._puzzle.mark(Vector2i(3, 2), false)
	check(mascot._reaction == Mascot.Reaction.MISTAKE and board._shake_time > 0.0 and screen._correct_lines == 0, "Mistakes shake once and reset the combo count")
	check(screen._celebration.tier == 0 and screen._peak_lines == 4, "A mistake ends the active combo and retains the best run for the reward")
	screen._puzzle.mark(Vector2i(2, 2), false)
	check(mascot._reaction == Mascot.Reaction.MISTAKE and screen._correct_lines == 2, "A normal fill does not interrupt the active mistake reaction")
	screen._puzzle.mark(Vector2i(3, 3), false)
	check(mascot._reaction == Mascot.Reaction.WIN and mascot.idle_expression == Mascot.Face.PROUD, "Win supersedes combo and settles into proud")
	screen.queue_free()
	await process_frame
	DirAccess.remove_absolute(save.storage_path)
	save.data = previous_data
	save.storage_path = previous_path


func _test_calm_visuals() -> void:
	var save := root.get_node("Save")
	var events := root.get_node("Events")
	var previous_data: Dictionary = save.data
	save.data = SaveScript.defaults()
	var backdrop := Backdrop.new()
	backdrop.size = Vector2(720, 1280)
	root.add_child(backdrop)
	var mascot := Mascot.new()
	mascot.size = Vector2(290, 291)
	root.add_child(mascot)
	var board := Board.new()
	board.puzzle = Puzzle.new({"size": 3, "solution": ["a..", ".a.", "..a"], "palette": {}})
	root.add_child(board)
	backdrop._process(0.25)
	check(backdrop._layers.size() == 3 and backdrop._layers[0].position != backdrop._layers[2].position, "Starfield layers move at different depths")
	mascot._time = PI / 4.2
	mascot._apply_pose()
	check(absf(mascot._body.position.y) > 3.0, "Normal idle pose visibly floats")
	save.data.settings.calm_mode = true
	events.settings_changed.emit()
	mascot.react(Mascot.Reaction.WIN)
	mascot._set_progress(0.5)
	mascot._apply_pose()
	board.puzzle.mark(Vector2i.ZERO, false)
	board.puzzle.mark(Vector2i(2, 1), false)
	check(not backdrop.is_processing() and backdrop._layers[2].position == Vector2.ZERO, "Calm Mode holds the star layers still")
	check(absf(mascot._body.position.y) < 1.5 and not mascot._sparks.emitting, "Calm Mode shortens the reaction and limits mascot motion")
	check(board._fills.is_empty() and board._rows.is_empty() and board._columns.is_empty() and board._shake_time == 0.0, "Calm Mode skips board animations")
	check(board.puzzle.lives == 2 and board.puzzle.at(Vector2i.ZERO) == Puzzle.Cell.FILLED, "Calm Mode preserves play and mistake correction")
	for node in [board, mascot, backdrop]:
		node.queue_free()
	await process_frame
	save.data = previous_data
	events.settings_changed.emit()


func _test_settings_menu() -> void:
	var screen := preload("res://scenes/main.tscn").instantiate()
	root.add_child(screen)
	screen.show_menu()
	for child in screen._column.get_children():
		if child is Button and child.text == "MENU_SETTINGS":
			child.pressed.emit()
			break
	var language: Array[Node] = screen._column.find_children("*", "OptionButton", false, false)
	check(language.size() == 1 and language[0].item_count == 3, "Settings menu shows the three language choices")
	check(screen._column.find_children("*", "CheckButton", false, false).size() == 4, "Settings menu shows all four toggles")
	screen.queue_free()
	await process_frame


func _test_catalog() -> void:
	var levels := Catalog.read()
	check(levels.size() == 60, "Read all 60 puzzle files")
	if levels.size() == 60:
		check(levels[0].planet == "moon" and levels[0].size == 5, "Moon album comes first")
		check(levels[20].planet == "mars" and levels[20].size == 8, "Mars album comes second")
		check(levels[40].planet == "saturn" and levels[40].size == 10, "Saturn album comes third")


func _test_level_progression() -> void:
	var save := root.get_node("Save")
	var previous_data: Dictionary = save.data
	var previous_path: String = save.storage_path
	var previous_locale := TranslationServer.get_locale()
	var path := "user://test-progression-%d.json" % OS.get_process_id()
	save.data = SaveScript.defaults()
	save.storage_path = path + "/unwritable"
	TranslationServer.set_locale("en")
	var main := preload("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var levels: Array[Dictionary] = main._levels
	var open_levels := []
	for index in range(levels.size()):
		if main._is_level_unlocked(index):
			open_levels.append(index)
	check(open_levels == [0], "A fresh save opens only Moon 01")
	main._show_planets()
	var planet_list: Control = main._column
	var mars_card := planet_list.get_child(3) as Button
	check(mars_card.disabled and "Clear 15 puzzles in Moon" in mars_card.text, "Locked Mars displays its requirement")
	mars_card.pressed.emit()
	check(main._column == planet_list, "A locked planet cannot open its level list")
	main._show_levels("moon")
	var moon_list: Control = main._column
	var grid := moon_list.get_child(3) as GridContainer
	var moon_02 := grid.get_child(1) as Button
	check(moon_02.disabled and "Clear 01" in moon_02.text, "Locked level displays its prerequisite")
	moon_02.pressed.emit()
	check(main._column == moon_list and main._play(20) == null, "A locked level cannot start through selection or direct play")

	var screen: NonogramScreen = main._play(0)
	var solution: Array = levels[0].solution
	for y in range(solution.size()):
		for x in range(solution.size()):
			if solution[y][x] != ".":
				screen._puzzle.mark(Vector2i(x, y), false)
	var buttons := screen._result.find_children("*", "Button", true, false)
	check(not main._is_level_unlocked(1) and not buttons.any(func(button: Node) -> bool: return button.text == "GAME_NEXT"), "An unsaved win cannot expose a locked Next")
	save.storage_path = path
	screen._retry_win()
	buttons = screen._result.find_children("*", "Button", true, false)
	check(main._is_level_unlocked(0) and main._is_level_unlocked(1) and not main._is_level_unlocked(2), "Clearing Moon 01 keeps it replayable and opens Moon 02")
	check(buttons.any(func(button: Node) -> bool: return button.text == "GAME_NEXT"), "Next appears after recording the clear")

	for planet in ["moon", "mars"]:
		var indices: Array[int] = main._planet_levels(planet)
		var next_planet := "mars" if planet == "moon" else "saturn"
		for offset in range(14):
			save.data.nonogram[levels[indices[offset]].id] = {"reward": 30, "doubled": false}
		check(not main._is_planet_unlocked(next_planet), "Fourteen %s clears leave %s locked" % [planet, next_planet])
		save.data.nonogram[levels[indices[14]].id] = {"reward": 30, "doubled": false}
		var next_first: int = main._planet_levels(next_planet)[0]
		check(main._is_planet_unlocked(next_planet) and main._is_level_unlocked(next_first), "Fifteen %s clears open %s level 01" % [planet, next_planet])
		check(not main._is_level_unlocked(next_first + 1), "Planet unlock still requires clearing level 01")

	var legacy := SaveScript.defaults()
	legacy.nonogram[levels[21].id] = {"reward": 25, "doubled": true}
	check(save.write_game(legacy) == OK and save.load_game() == OK, "Read a sparse save from before progression")
	check(not main._is_planet_unlocked("mars") and main._is_level_unlocked(21) and not main._is_level_unlocked(22), "Legacy Mars clear is replayable without opening new Mars levels")
	main._show_planets()
	var legacy_replay := main._column.get_child(4) as Button
	check(not legacy_replay.disabled and "Replay cleared puzzles" in legacy_replay.text, "Locked albums with legacy clears offer replay")
	legacy_replay.pressed.emit()
	check(main._play(21) != null and main._play(22) == null, "Legacy replay cannot bypass the planet lock")
	main.queue_free()
	await process_frame
	DirAccess.remove_absolute(path)
	save.data = previous_data
	save.storage_path = previous_path
	TranslationServer.set_locale(previous_locale)


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


func _test_continue() -> void:
	var level := {"size": 4, "solution": ["aa..", ".aa.", "..aa", "a..a"], "palette": {}}
	var puzzle := Puzzle.new(level)
	check(not puzzle.continue_game(), "Continue cannot add lives before a loss")
	for cell in [Vector2i(2, 0), Vector2i(3, 0), Vector2i(0, 1)]:
		puzzle.mark(cell, false)
	check(puzzle.continue_game() and puzzle.lives == 1 and puzzle.at(Vector2i(0, 1)) == Puzzle.Cell.CROSSED, "Continue restores one life and keeps the grid")
	puzzle.mark(Vector2i(0, 2), false)
	check(puzzle.state == Puzzle.State.LOST and not puzzle.continue_game(), "A second loss cannot be continued")
	var last_cell := Puzzle.new(level)
	last_cell.mark(Vector2i(2, 0), false)
	last_cell.mark(Vector2i(3, 0), false)
	for cell in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2), Vector2i(3, 2), Vector2i(0, 3)]:
		last_cell.mark(cell, false)
	last_cell.mark(Vector2i(3, 3), true)
	check(last_cell.state == Puzzle.State.LOST and last_cell.continue_game() and last_cell.state == Puzzle.State.WON, "Continuing after a final corrected fill reveals the win")


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
	check(previous.version == SaveScript.VERSION and previous.coins == 80 and previous.settings.language == "id", "Migrate V1 without losing balance or settings")
	check(previous.daily == Daily.empty_progress(), "V1 starts with an empty daily streak")
	var v2 := SaveScript.migrate({"version": 2, "coins": 14, "daily": {"last_day": 20780, "streak": 5}})
	check(v2.version == SaveScript.VERSION and v2.nonogram.is_empty() and v2.coins == 14 and v2.daily.streak == 5, "Migrate V2 while preserving daily progress and coins")
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


func _solve_nonogram(screen: NonogramScreen) -> void:
	for y in range(screen._puzzle.size):
		for x in range(screen._puzzle.size):
			if screen.level.solution[y][x] != ".":
				screen._puzzle.mark(Vector2i(x, y), false)


func _press_button(parent: Node, key: String) -> bool:
	for button: Button in parent.find_children("*", "Button", true, false):
		if button.text == key and not button.disabled:
			button.pressed.emit()
			return true
	return false


func _test_bonus_flow() -> void:
	var save := root.get_node("Save")
	var economy := root.get_node("Economy")
	var previous_data: Dictionary = save.data
	var previous_path: String = save.storage_path
	var path := "user://test-bonus-%d.json" % OS.get_process_id()
	save.data = SaveScript.defaults()
	save.data.settings.vibration = false
	save.storage_path = path
	var main := preload("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in range(1, 4):
		economy.award_nonogram(main._levels[i].id, 3)
	check(main._open_bonus() == null and economy.award_bonus(0) == -1, "Three badges cannot open a round or claim its rewards")
	var normal: NonogramScreen = main._play(0)
	_solve_nonogram(normal)
	check(economy.badge_count() == 4 and normal._celebration._detail.text == tr("BONUS_UNLOCKED"), "A flawless fourth clear saves the badge and announces the unlock")
	normal._celebration.dismiss()
	var balance: int = economy.balance()
	var xp: int = save.data.meta.xp
	check(_press_button(normal._result, "BONUS_TITLE"), "The fourth win offers the Bonus Round")
	var first := main._column.get_child(0) as NonogramScreen
	check(first.bonus_index == 0 and first._puzzle.size == 5 and first._hint == null, "The round opens the first dedicated 5x5 without paid hints")
	save.storage_path = path + "/missing-dir/save.json"
	_solve_nonogram(first)
	check(economy.balance() == balance and economy.next_bonus_index() == 0, "Failed Bonus Round save keeps the current stage and coins")
	save.storage_path = path
	check(_press_button(first._result, "SAVE_RETRY") and economy.balance() == balance + 10, "Retrying the bonus save awards x1 once")
	check(economy.award_bonus(0) == -1 and economy.next_bonus_index() == 1, "A stale stage cannot award again")
	first._leave(&"levels")
	check(save.load_game() == OK and _press_button(main._column, "BONUS_TITLE"), "Reloading keeps the round accessible from the planet list")
	var second := main._column.get_child(0) as NonogramScreen
	check(second.bonus_index == 1 and second.level.id != first.level.id, "Resuming opens the next separate puzzle")
	for y in range(second._puzzle.size):
		for x in range(second._puzzle.size):
			second._puzzle.mark(Vector2i(x, y), second.level.solution[y][x] != ".")
	check(second._puzzle.state == Puzzle.State.LOST and economy.next_bonus_index() == 1 and economy.balance() == balance + 10, "Losing leaves the current bonus stage available with no coins")
	check(_press_button(second._result, "GAME_RETRY"), "A lost bonus puzzle can be retried")
	var retry := main._column.get_child(0) as NonogramScreen
	_solve_nonogram(retry)
	check(retry.level.id == second.level.id and economy.balance() == balance + 30, "The second stage awards x2 on retry")
	check(_press_button(retry._result, "GAME_NEXT"), "The second win advances in the same round")
	var third := main._column.get_child(0) as NonogramScreen
	_solve_nonogram(third)
	check(third.bonus_index == 2 and economy.balance() == balance + 60, "The final stage awards x3 for a total of 60")
	check(save.data.meta.xp == xp + 120 and economy.owns_costume("bonus_booster"), "Three bonus stages grant 40 XP each and unlock their achievement costume")
	check(third._celebration.tier == 4 and third._celebration._title.text == "CELEBRATION_BONUS", "Completing the round shows the max celebration")
	check(save.load_game() == OK and economy.next_bonus_index() == -1 and economy.badge_count() == 4, "Finishing exhausts one round and preserves badges across reload")
	for i in range(4, 8):
		economy.award_nonogram(main._levels[i].id, 3)
	check(economy.next_bonus_index() == 3 and Bonus.puzzle_for(3).id != first.level.id, "Four additional badges open a new set of puzzles")
	main.queue_free()
	await process_frame
	DirAccess.remove_absolute(path)
	save.storage_path = previous_path
	save.data = previous_data


func _test_celebrations() -> void:
	var save := root.get_node("Save")
	var previous_data: Dictionary = save.data
	save.data = SaveScript.defaults()
	var host := Control.new()
	root.add_child(host)
	var focus := Button.new()
	host.add_child(focus)
	var overlay := Celebration.new()
	overlay.attach(host)
	focus.grab_focus()

	overlay.play_combo(0, 3)
	check(overlay.tier == 2 and overlay._duration == 1.0 and overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Combo lasts one second and leaves board input available")
	overlay.freeze_at(0.48)
	check(not overlay.is_processing() and is_equal_approx(overlay._elapsed, 0.48), "QA freezes the combined visual at a known frame")
	for tier in [3, 4]:
		overlay.play(tier, "CELEBRATION_FLAWLESS")
		var start := overlay._mascot.position
		overlay._process(0.99)
		check(not overlay._skip.visible and overlay._mascot.position.x > start.x, "Tier %d flies in and waits one second before Skip" % tier)
		check(overlay._mascot.position + overlay._mascot.size * 0.5 == overlay.size * 0.5 and overlay._mascot.size.x >= 320, "Tier %d uses a large Velokity centered on the viewport" % tier)
		overlay._process(0.02)
		check(overlay._skip.visible and overlay._duration == Celebration.SECONDS[tier], "Tier %d is skippable during its full-length celebration" % tier)
		overlay._skip.pressed.emit()
		check(overlay.tier == 0 and not overlay.visible and focus.has_focus(), "Skip closes the overlay and restores focus")

	save.data.settings.calm_mode = true
	overlay.play(4, "CELEBRATION_BONUS")
	var calm_start := overlay._mascot.position
	overlay._process(1.0)
	check(overlay._mascot.position == calm_start and overlay._duration < 2.0 and not overlay._skip.visible, "Calm Mode skips the flight and shortens the max celebration")
	overlay._process(0.2)
	check(not overlay.visible, "Shortened celebrations still close automatically")
	host.queue_free()
	await process_frame
	save.data = previous_data


func _test_milestone_celebrations() -> void:
	var save := root.get_node("Save")
	var previous_data: Dictionary = save.data
	var previous_path: String = save.storage_path
	var path := "user://test-milestones-%d.json" % OS.get_process_id()
	save.data = SaveScript.defaults()
	save.storage_path = path
	var main := preload("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var level: Dictionary = main._levels[0]
	var screen: NonogramScreen = main._play(0)
	_solve_nonogram(screen)
	check(screen._celebration.tier == 3, "The first flawless clear triggers the big celebration")
	for i in range(1, 19):
		save.data.nonogram[main._levels[i].id] = {"reward": 25, "doubled": false}
	screen = main._play(19)
	_solve_nonogram(screen)
	check(screen._celebration.tier == 4 and screen._celebration._title.text == "CELEBRATION_ALBUM", "The final planet clear celebrates the completed album")
	check(save.data.nonogram.has(level.id), "Album completion retains the first clear")

	save.data.daily = {"last_day": Daily.today() - 1, "streak": 6, "clears": 6}
	var daily = main._open_daily()
	var daily_level := Daily.puzzle_for(daily._day)
	for y in range(daily_level.solution.size()):
		daily._puzzle.place(Vector2i(int(daily_level.solution[y]), y), false)
	check(daily._celebration.tier == 4 and daily._celebration._title.text == "CELEBRATION_STREAK", "The seventh daily win celebrates the streak")
	main.queue_free()
	await process_frame
	DirAccess.remove_absolute(path)
	save.storage_path = previous_path
	save.data = previous_data


func _test_xp_migration() -> void:
	var save := root.get_node("Save")
	var economy := root.get_node("Economy")
	var original: Dictionary = save.data
	var progress := {}
	for i in range(6):
		progress["moon-test-%d" % i] = {"reward": 60, "doubled": i == 0, "flawless": i < 4}
	for total in [7, 8, 17, 18, 27, 28, 37, 38, 57, 58, 60]:
		var legacy := {
			"version": 4, "coins": 90, "nonogram": progress, "bonus_clears": 1,
			"daily": {"last_day": 22000, "streak": 1, "clears": total - progress.size()},
		}
		save.data = SaveScript.migrate(legacy)
		@warning_ignore("integer_division")
		var old_level: int = 1 + total / 2
		var player_level: int = economy.player_level()
		check(player_level == old_level and Combo.theme_count(player_level) == Combo.theme_count(old_level), "V4 preserves the level and combo themes at %d first clears" % total)
		check(economy.xp_progress() == (total % 2) * 100, "V4 preserves progress toward the next level")
	check(save.data.coins == 90 and economy.badge_count() == 4 and save.data.bonus_clears == 1, "XP migration keeps coins, badges, and the in-progress Bonus Round")
	check(save.data.nonogram["moon-test-0"].doubled and save.data.meta.login == Daily.empty_progress(), "V4 keeps the ad claim and starts with a fresh login calendar")

	var malformed: Dictionary = save.data.duplicate(true)
	malformed.meta = {
		"xp": -5, "login": {"last_day": 22000.5, "streak": 7},
		"purchased": {"invalid": true, "moonlight": true, "mint_visor": true},
		"equipped": {"helmet": "red_dust", "suit": "pathfinder"},
	}
	var clean := SaveScript.migrate(malformed)
	check(clean.meta.xp == 6000 and clean.meta.login == Daily.empty_progress(), "Invalid V5 fields retain the XP floor and reset invalid login data")
	check(clean.meta.purchased == {"mint_visor": true} and clean.meta.equipped == {"suit": "pathfinder"}, "V5 sanitizes costume sources and equipment slots")
	save.data = original


func _test_costume_economy() -> void:
	var save := root.get_node("Save")
	var economy := root.get_node("Economy")
	var original: Dictionary = save.data
	var original_path: String = save.storage_path
	var path := "user://test-costumes-%d.json" % OS.get_process_id()
	save.data = SaveScript.defaults()
	save.storage_path = path
	save.data.coins = 1600
	var min_price := EconomyRules.MAX_COINS
	var max_price := 0
	for id: String in Meta.COSTUMES:
		var item: Dictionary = Meta.COSTUMES[id]
		if item.has("price"):
			min_price = mini(min_price, item.price)
			max_price = maxi(max_price, item.price)
	check(min_price == 400 and max_price == 2000, "Shop prices span the requested range")
	check(not economy.buy_costume("moonlight") and not economy.buy_costume("pathfinder"), "Album and achievement rewards cannot be purchased")
	check(not economy.buy_costume("prism_pack") and not economy.equip_costume("helmet", "mint_visor"), "Reject an unaffordable purchase and an unowned equipment request")
	save.storage_path = path + "/missing-dir/save.json"
	check(not economy.buy_costume("mint_visor") and economy.balance() == 1600 and not economy.owns_costume("mint_visor"), "A failed purchase changes neither balance nor ownership")
	save.storage_path = path
	check(economy.buy_costume("mint_visor") and economy.balance() == 1200 and economy.owns_costume("mint_visor"), "Purchase saves ownership and debits the set price")
	check(not economy.buy_costume("mint_visor") and economy.balance() == 1200, "Owning an item prevents duplicate charges")
	check(not economy.equip_costume("suit", "mint_visor") and economy.equip_costume("helmet", "mint_visor"), "Only the matching slot can equip the purchased item")
	check(economy.buy_costume("nebula_suit") and economy.equip_costume("suit", "nebula_suit"), "Unlock and equip a second slot independently")
	check(save.load_game() == OK and economy.equipped_costumes() == {"helmet": "mint_visor", "suit": "nebula_suit"} and economy.balance() == 550, "Reload two equipped slots and the balance")
	check(economy.equip_costume("helmet", "") and economy.equipped_costumes() == {"suit": "nebula_suit"}, "Resetting one slot preserves the other")
	check(not economy.owns_costume("pathfinder") and not economy.owns_costume("perfect_signal"), "Achievements start locked")

	for planet: String in Catalog.PLANETS:
		var entries: Array = economy.levels.filter(func(level: Dictionary) -> bool: return level.planet == planet)
		var reward: String = Meta.ALBUM_REWARDS[planet]
		for level: Dictionary in entries.slice(0, 19):
			economy.award_nonogram(level.id, 3)
		check(economy.album_collected(planet) == 19 and not economy.owns_costume(reward), "Nineteen published pictures cannot unlock the album reward")
		economy.award_nonogram(entries[19].id, 2)
		check(economy.album_collected(planet) == 20 and economy.owns_costume(reward), "The twentieth picture unlocks its album costume")
	check(economy.owns_costume("pathfinder") and economy.owns_costume("perfect_signal"), "First clears and flawless badges unlock their achievement costumes")
	check(save.load_game() == OK and economy.owns_costume("moonlight") and economy.equip_costume("helmet", "moonlight"), "Reloading preserves eligibility for album-exclusive equipment")

	DirAccess.remove_absolute(path)
	save.data = original
	save.storage_path = original_path


func _test_login_calendar() -> void:
	var save := root.get_node("Save")
	var economy := root.get_node("Economy")
	var original: Dictionary = save.data
	var original_path: String = save.storage_path
	var path := "user://test-login-%d.json" % OS.get_process_id()
	save.data = SaveScript.defaults()
	save.storage_path = path
	var day := 22000
	var balance := 0
	for i in range(Meta.LOGIN_REWARDS.size()):
		var reward: int = Meta.LOGIN_REWARDS[i]
		check(economy.login_status(day + i).reward == reward, "Show the available reward before claiming")
		check(economy.claim_login(day + i) == reward and economy.claim_login(day + i) == 0, "Grant exactly one claim per local day")
		balance += reward
	check(economy.balance() == balance and economy.login_status(day + 6).slots == 7, "The seventh day fills the calendar")
	check(save.data.daily == Daily.empty_progress() and economy.player_level() == 1, "Login claims leave Rasi Bintang progress and XP independent")
	check(save.load_game() == OK and economy.claim_login(day + 5) == 0 and economy.login_status(day + 5).clock_behind, "A rollback after reloading cannot grant a claim or hide the date gate")
	check(economy.award_daily(day + 6) == Daily.REWARDS[0] and economy.claim_login(day + 6) == 0, "Rasi Bintang can be cleared independently on the claimed date")
	check(economy.claim_login(day + 7) == Meta.LOGIN_REWARDS[0], "The calendar rolls over after seven days")
	check(economy.claim_login(day + 10) == Meta.LOGIN_REWARDS[0] and economy.login_status(day + 10).slots == 1, "A missed day starts a new login cycle")
	var snapshot: Dictionary = save.data.duplicate(true)
	save.storage_path = path + "/missing-dir/save.json"
	check(economy.claim_login(day + 11) == -1 and save.data == snapshot, "A write failure leaves the next login claim available")
	save.storage_path = path
	check(economy.claim_login(day + 11) == Meta.LOGIN_REWARDS[1], "The next successful write collects the correct reward once")
	check(economy.claim_login(4000000) == 0 and economy.claim_login(-1) == 0, "Reject unsupported dates that could not be persisted")
	DirAccess.remove_absolute(path)
	save.data = original
	save.storage_path = original_path


func _test_meta_menu() -> void:
	var save := root.get_node("Save")
	var economy := root.get_node("Economy")
	var original: Dictionary = save.data
	var original_path: String = save.storage_path
	var path := "user://test-meta-menu-%d.json" % OS.get_process_id()
	save.data = SaveScript.defaults()
	save.data.coins = 850
	save.storage_path = path
	var main := preload("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	economy.award_nonogram(main._levels[0].id, 2)
	main.show_menu()
	check(_press_button(main._column, "META_ALBUM"), "The menu opens the planet albums")
	var screen := main._column.get_child(0) as MetaScreen
	var pictures := screen.find_children("*", "Control", true, false).filter(func(node: Node) -> bool: return node.get_script() == AlbumPicture)
	check(pictures.size() == 20 and pictures[0].level == main._levels[0] and pictures[1].level.is_empty(), "Album cards display only pictures from cleared levels")
	check(_press_button(screen, "META_ACHIEVEMENTS") and screen.page == MetaScreen.Page.ACHIEVEMENTS, "The album links to achievement progress")
	check(_press_button(screen, "META_BACK_ALBUM") and screen.page == MetaScreen.Page.ALBUM, "Achievements return to the album")
	main.show_menu()
	check(_press_button(main._column, "META_SHOP"), "The menu opens the wardrobe and shop")
	screen = main._column.get_child(0) as MetaScreen
	check(_press_button(screen, "COSTUME_MINT_VISOR") and screen._portrait.preview_outfit.helmet == "mint_visor" and economy.equipped_costumes().is_empty(), "Previewing a shop item leaves the saved outfit unchanged")
	check(_press_button(screen, tr("COSTUME_BUY") % 400) and economy.owns_costume("mint_visor"), "The shop action buys an available costume")
	check(_press_button(screen, "COSTUME_EQUIP") and economy.equipped_costumes().helmet == "mint_visor", "The shop action equips a purchased costume")
	main.show_menu()
	check(_press_button(main._column, "META_LOGIN"), "The menu opens the separate login calendar")
	screen = main._column.get_child(0) as MetaScreen
	check(_press_button(screen, tr("LOGIN_CLAIM") % Meta.LOGIN_REWARDS[0]) and economy.login_status(Daily.today()).reward == 0, "The login screen claims today's reward and disables repeat claims")
	main.queue_free()
	await process_frame
	DirAccess.remove_absolute(path)
	save.data = original
	save.storage_path = original_path


class TestPortalAds extends RefCounted:
	signal banner_state_changed(state: String)
	signal rewarded_state_changed(state: String)
	signal interstitial_state_changed(state: String)

	var is_rewarded_supported := true
	var is_interstitial_supported := true
	var is_banner_supported := true
	var requests: Array[String] = []
	var banners: Array[String] = []
	var hide_immediately := true

	func show_rewarded(placement: String) -> void:
		requests.append(placement)

	func show_interstitial() -> void:
		requests.append("interstitial")

	func show_banner(position: String) -> void:
		banners.append(position)
		banner_state_changed.emit("shown")

	func hide_banner() -> void:
		banners.append("hidden")
		if hide_immediately:
			banner_state_changed.emit("hidden")


class TestPortal extends RefCounted:
	var id := "mock"
	var is_external_links_allowed := true
	var messages: Array[String] = []

	func send_message(message: String) -> void:
		messages.append(message)


func _test_bridge_ads() -> void:
	var ads := AdsScript.new()
	var portal_ads := TestPortalAds.new()
	var platform := TestPortal.new()
	var provider := BridgeAds.new(portal_ads, platform)
	var prior_mute := AudioServer.is_bus_mute(0)
	AudioServer.set_bus_mute(0, false)
	ads.set_provider(provider)
	root.add_child(ads)
	check(root.get_node("Ads")._provider is FakeAds, "Godot headless uses FakeAds")
	ads.notify_game_ready()
	ads.notify_game_ready()
	ads.set_gameplay_active(true)
	check(platform.messages == ["game_ready", "gameplay_started"] and portal_ads.banners == ["bottom"], "Report readiness once and start gameplay with a bottom banner")
	var results: Array[Array] = []
	ads.rewarded_finished.connect(func(placement: StringName, granted: bool) -> void:
		results.append([placement, granted])
	)
	check(ads.request_rewarded(AdsScript.FREE_COINS), "Shop uses a distinct Bridge rewarded placement")
	check(paused and AudioServer.is_bus_mute(0) and portal_ads.requests == ["free_coins"], "Bridge requests pause and mute the game")
	check(platform.messages.back() == "gameplay_stopped" and portal_ads.banners.back() == "hidden", "Hide the banner and report stopped before the full-screen ad")
	portal_ads.rewarded_state_changed.emit("opened")
	portal_ads.rewarded_state_changed.emit("rewarded")
	await process_frame
	check(paused and results.is_empty(), "Wait for close even after Bridge reports a reward")
	portal_ads.rewarded_state_changed.emit("closed")
	await process_frame
	check(not paused and not AudioServer.is_bus_mute(0) and results == [[AdsScript.FREE_COINS, true]], "Bridge close fulfills the granted placement exactly once")
	check(platform.messages.back() == "gameplay_started" and portal_ads.banners.back() == "bottom", "Resume the active puzzle and restore its banner")
	check(ads.request_rewarded(&"hint"), "Accept a second rewarded ad")
	portal_ads.rewarded_state_changed.emit("closed")
	await process_frame
	check(results.back() == [&"hint", false], "Closing Bridge without a reward denies the grant")

	AudioServer.set_bus_mute(0, true)
	check(ads.request_rewarded(&"continue"), "Begin a request that will time out")
	ads._on_timeout()
	check(not paused and AudioServer.is_bus_mute(0) and results.back() == [&"continue", false], "The watchdog restores the prior audio mute and denies the request")
	check(not ads.request_rewarded(&"hint"), "Do not attribute a timed-out Bridge callback to a new request")
	var count := results.size()
	portal_ads.rewarded_state_changed.emit("rewarded")
	portal_ads.rewarded_state_changed.emit("closed")
	await process_frame
	check(results.size() == count and ads.can_request_rewarded(), "Drain late Bridge events before accepting another request")
	check(ads.request_rewarded(&"hint"), "Accept the next request after draining an expired Bridge ad")
	portal_ads.rewarded_state_changed.emit("failed")
	await process_frame
	check(results.size() == count + 1 and results.back() == [&"hint", false], "Bridge failure recovers without a payout")

	ads.set_gameplay_active(false)
	portal_ads.is_banner_supported = false
	portal_ads.is_rewarded_supported = false
	var banner_count := portal_ads.banners.size()
	ads.set_gameplay_active(true)
	check(portal_ads.banners.size() == banner_count and not ads.request_rewarded(&"hint"), "Platforms without banner or rewarded support never call those APIs")
	ads.set_gameplay_active(false)
	ads._session_started = Time.get_ticks_msec() - 120000
	check(ads.request_interstitial_after_result(10) and paused, "Eligible results also use the Bridge interstitial")
	portal_ads.interstitial_state_changed.emit("closed")
	await process_frame
	check(not paused and platform.messages.back() == "gameplay_stopped", "An interstitial outside a puzzle restores input without starting gameplay")
	check(ads.allows_support_link(), "Bridge mock represents a standalone site")
	for id in ["crazy_games", "poki", "playgama", "game_distribution", "standalone", "unknown"]:
		platform.id = id
		check(not ads.allows_support_link(), "Never show the support link on %s" % id)
	platform.id = "mock"
	platform.is_external_links_allowed = false
	check(not ads.allows_support_link(), "An external link also requires Bridge permission")
	ads.queue_free()
	await process_frame
	AudioServer.set_bus_mute(0, prior_mute)


func _test_support_config() -> void:
	var path := "user://test-support-%d.cfg" % OS.get_process_id()
	var config := ConfigFile.new()
	check(MonetizationConfig.support_url() == "https://trakteer.id/velokity_project", "The shipped support URL points to Velokity on Trakteer")
	for invalid in ["", "http://example.test", "https://", "https://?go=example.test", "https://portal.test@example.test", "https://example.test/test path"]:
		config.set_value("support", "url", invalid)
		config.save(path)
		check(MonetizationConfig.support_url(path).is_empty(), "Reject a missing or unsafe support link")
	var valid := "https://example.test/velokity?from=game"
	config.set_value("support", "url", valid)
	config.save(path)
	check(MonetizationConfig.support_url(path) == valid, "Read the configured support URL")
	DirAccess.remove_absolute(path)


func _test_free_coin_quota() -> void:
	var save := root.get_node("Save")
	var economy := root.get_node("Economy")
	var original: Dictionary = save.data
	var original_path: String = save.storage_path
	var path := "user://test-coin-ads-%d.json" % OS.get_process_id()
	var day := 22000
	save.storage_path = path
	save.data = SaveScript.migrate({"version": 5, "coins": 80, "meta": {"xp": 400}})
	check(economy.free_coin_ads_remaining(day) == 5 and economy.balance() == 80 and economy.player_level() == 3, "V5 keeps progress and starts with a full ad quota")
	for i in range(5):
		check(economy.award_free_ad_coins(day) == 25 and economy.free_coin_ads_remaining(day) == 4 - i, "Pay 25 coins per completed ad")
	check(economy.award_free_ad_coins(day) == 0 and economy.balance() == 205, "The sixth reward is capped")
	check(save.load_game() == OK and economy.award_free_ad_coins(day) == 0 and economy.award_free_ad_coins(day - 1) == 0, "Reload and date rollback preserve the used quota")
	var snapshot: Dictionary = save.data.duplicate(true)
	save.storage_path = path + "/missing-directory/save.json"
	check(economy.award_free_ad_coins(day + 1) == -1 and save.data == snapshot, "A failed save changes neither quota nor balance")
	save.storage_path = path
	check(economy.award_free_ad_coins(day + 1) == 25 and economy.free_coin_ads_remaining(day + 1) == 4, "The next local date starts a new quota")
	check(economy.award_free_ad_coins(day) == 0 and economy.award_free_ad_coins(Daily.MAX_DAY + 1) == 0, "Only nondecreasing, supported local dates qualify")
	DirAccess.remove_absolute(path)
	save.data = original
	save.storage_path = original_path


func _test_shop_monetization() -> void:
	var save := root.get_node("Save")
	var ads := root.get_node("Ads")
	var economy := root.get_node("Economy")
	var original: Dictionary = save.data
	var original_path: String = save.storage_path
	var prior_provider: RefCounted = ads._provider
	var path := "user://test-shop-ads-%d.json" % OS.get_process_id()
	save.data = SaveScript.defaults()
	save.storage_path = path
	var fake := FakeAds.new()
	ads.set_provider(fake)
	var main := preload("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var screen: MetaScreen = main._open_meta(MetaScreen.Page.SHOP)
	var caption := tr("FREE_COINS_BUTTON") % [25, 5]
	fake.grant_rewards = false
	check(_press_button(screen, caption), "Shop exposes the rewarded ad action")
	await ads.rewarded_finished
	check(economy.balance() == 0 and economy.free_coin_ads_remaining(Daily.today()) == 5, "A denied shop ad uses no quota")
	fake.grant_rewards = true
	save.storage_path = path + "/missing-directory/save.json"
	check(_press_button(screen, caption), "The same quota is still eligible after an ad denial")
	await ads.rewarded_finished
	check(economy.balance() == 0 and screen._coin_reward_day == Daily.today(), "A granted ad is retained for save retry")
	save.storage_path = path
	check(_press_button(screen, "SAVE_RETRY") and economy.balance() == 25, "Retry the save with no second ad")
	check(not _press_button(screen, "IAP_TITLE") and screen.page == MetaScreen.Page.SHOP, "Hide the IAP entry when no product is available")
	screen._open_purchases()
	check(screen.page == MetaScreen.Page.SHOP, "An unavailable purchase page cannot be opened directly")
	var preview := screen.find_children("*", "Button", true, false).filter(func(button: Button) -> bool: return button.text == "COSTUME_MINT_VISOR")
	check(preview.size() == 1 and preview[0].get_theme_stylebox("normal") is StyleBoxEmpty, "Costume names have no input-like background")
	check(not Purchases.new().request_purchase(&"no_ads"), "The IAP stub cannot start a purchase")
	main.queue_free()
	await process_frame
	ads.set_provider(prior_provider)
	DirAccess.remove_absolute(path)
	save.data = original
	save.storage_path = original_path



func _test_banner_clearance() -> void:
	var ads := root.get_node("Ads")
	var prior_provider: RefCounted = ads._provider
	var portal_ads := TestPortalAds.new()
	var platform := TestPortal.new()
	portal_ads.hide_immediately = false
	var measured := [132.0]
	ads.set_provider(BridgeAds.new(portal_ads, platform, func() -> float: return measured[0]))
	var main := preload("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.show_menu()
	check(main.find_children("*", "Button", true, false).any(func(button: Button) -> bool: return button.text == "MENU_SUPPORT"), "A standalone Bridge menu shows the configured support button")
	platform.id = "playgama"
	main.show_menu()
	check(not main.find_children("*", "Button", true, false).any(func(button: Button) -> bool: return button.text == "MENU_SUPPORT"), "A portal menu hides the support button")
	main._play(0)
	for height: float in [132.0, 210.0]:
		measured[0] = height
		main.center.size = Vector2(1800, 1280)
		main._layout_content()
		await process_frame
		var column: VBoxContainer = main._column
		var clearance: float = height * main.center.size.y / root.size.y
		var bottom := column.position.y + column.size.y * column.scale.y
		check(bottom <= maxf(1.0, main.center.size.y - clearance) + 0.01, "Banner reserve keeps all controls above the bottom strip after resize")
		check(absf(column.position.x + column.size.x * column.scale.x * 0.5 - main.center.size.x * 0.5) <= 1.0, "The adjusted board remains horizontally centered")
	ads.set_gameplay_active(false)
	check(ads.banner_clearance() > 0, "Keep the strip reserved until the asynchronous banner hide finishes")
	portal_ads.banner_state_changed.emit("hidden")
	check(ads.banner_clearance() == 0.0, "Release the strip once the SDK reports it hidden")
	main.queue_free()
	await process_frame
	ads.set_provider(prior_provider)


func _test_audio_smoke() -> void:
	var audio := root.get_node("Audio")
	var ads := root.get_node("Ads")
	var save := root.get_node("Save")
	var events := root.get_node("Events")
	var original: Dictionary = save.data
	var original_path: String = save.storage_path
	var path := "user://test-audio-%d.json" % OS.get_process_id()
	save.data = SaveScript.defaults()
	save.storage_path = path
	events.settings_changed.emit()
	var main := preload("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.show_menu()
	var music: AudioStreamPlayer = audio._music
	var music_bus := AudioServer.get_bus_index("Music")
	var sfx_bus := AudioServer.get_bus_index("SFX")
	check(audio._effects.size() == 9, "Import all nine procedural effects")
	for player: AudioStreamPlayer in audio._effects.values():
		check(player.stream is AudioStreamWAV and player.stream.get_length() > 0 and player.stream.get_length() <= 1.05 and player.stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, "A short effect imports as a nonlooping WAV")
	for track: AudioStreamWAV in [audio._menu_music, audio._puzzle_music]:
		check(track.loop_mode == AudioStreamWAV.LOOP_FORWARD and track.loop_begin == 0 and track.loop_end >= track.data.size() / 2.0 - 1.0, "A music WAV loops over its complete sample range")
		check(track.get_length() >= 9.0 and track.get_length() <= 12.0, "Music loops are short")
	check(music.playback_type == AudioServer.PLAYBACK_TYPE_STREAM, "Music loops in the mixer without browser callback gaps")
	check(not music.playing, "Music is silent before the first real input")
	audio._input(InputEventMouseMotion.new())
	audio._input(InputEventMouseButton.new())
	check(not music.playing, "Mouse motion and release do not start music")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	audio._input(click)
	check(music.playing and music.stream == audio._menu_music, "A pressed input starts the menu loop")
	var screen = main._play(0)
	check(music.playing and music.stream == audio._puzzle_music, "Opening a puzzle switches to the puzzle loop")
	screen._puzzle.mark(Vector2i(0, 0), true)
	check(audio._effects[&"cross"].playing, "Manually crossing a cell triggers the cross effect")
	var before := AudioServer.get_bus_volume_db(music_bus)
	save.data.settings.calm_mode = true
	events.settings_changed.emit()
	check(AudioServer.get_bus_volume_db(music_bus) < before, "Calm Mode lowers the music gain")
	save.data.settings.sound = false
	events.settings_changed.emit()
	check(AudioServer.is_bus_mute(sfx_bus) and music.playing, "Sound off mutes only effects")
	save.data.settings.music = false
	events.settings_changed.emit()
	check(AudioServer.is_bus_mute(music_bus) and not music.playing, "Music off stops the current loop")
	save.data.settings.music = true
	save.data.settings.sound = true
	events.settings_changed.emit()
	check(music.playing and not AudioServer.is_bus_mute(sfx_bus), "Settings can reenable each audio bus")
	check(ads.request_rewarded(&"hint") and paused and AudioServer.is_bus_mute(0) and music.stream_paused, "Ads mute Master and halt music")
	await ads.rewarded_finished
	check(music.playing and not music.stream_paused and not AudioServer.is_bus_mute(0), "Ad completion resumes the loop and restores Master")
	main.show_menu()
	check(music.stream == audio._menu_music, "Returning to the menu switches tracks")
	root.get_node("Economy").earn(1)
	check(audio._effects[&"coin"].playing, "Saving an earned coin plays its cue")
	audio._input_received = false
	audio.set_process_input(true)
	for player: AudioStreamPlayer in audio._effects.values():
		player.stop()
	main.queue_free()
	await process_frame
	DirAccess.remove_absolute(path)
	save.data = original
	save.storage_path = original_path
	events.settings_changed.emit()
	# Allow the audio mixer to release stopped WAV playback objects.
	await create_timer(0.12).timeout
