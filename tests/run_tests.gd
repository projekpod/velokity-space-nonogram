extends SceneTree

const SaveScript := preload("res://scripts/autoload/save.gd")
const FakeAds := preload("res://scripts/ads/fake_ads.gd")

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_save()
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
