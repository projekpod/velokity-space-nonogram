extends Node

signal rewarded_finished(placement: StringName, granted: bool)
signal interstitial_closed
signal banner_space_changed

const AdsProvider := preload("res://scripts/ads/ads_provider.gd")
const FakeAds := preload("res://scripts/ads/fake_ads.gd")
const BridgeAds := preload("res://scripts/ads/bridge_ads.gd")
const FREE_COINS := &"free_coins"
const INTERSTITIAL := &"interstitial"
const TIMEOUT_SECONDS := 45.0

var _provider: AdsProvider = FakeAds.new()
var _session_started := Time.get_ticks_msec()
var _last_interstitial := -90000
var _placement: StringName
var _request_id := 0
var _previously_paused := false
var _previously_muted := false
var _game_ready := false
var _gameplay_active := false
var _banner_wanted := false
var _reported_gameplay := false
var _banner_shown := false
var _timeout: Timer
var _banner_space := 0.0
var _banner_fits_viewport := true
var _browser: JavaScriptObject
var _resize_callback: JavaScriptObject


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_timeout = Timer.new()
	_timeout.one_shot = true
	_timeout.ignore_time_scale = true
	_timeout.wait_time = TIMEOUT_SECONDS
	_timeout.timeout.connect(_on_timeout)
	add_child(_timeout)
	if OS.has_feature("web") and not Engine.is_editor_hint() and DisplayServer.get_name() != "headless":
		var bridge := get_node("/root/Bridge")
		if bridge.advertisement != null:
			_provider = BridgeAds.new(bridge.advertisement, bridge.platform)
		else:
			var unavailable := FakeAds.new()
			unavailable.available = false
			_provider = unavailable
	_connect_provider()
	set_process(OS.has_feature("web"))
	if OS.has_feature("web"):
		_browser = JavaScriptBridge.get_interface("window")
		_resize_callback = JavaScriptBridge.create_callback(_on_browser_resize)
		_browser.addEventListener("resize", _resize_callback)
		_on_browser_resize([])


func _exit_tree() -> void:
	if _browser != null:
		_browser.removeEventListener("resize", _resize_callback)


func _process(_delta: float) -> void:
	_on_banner_space_changed()


func _on_browser_resize(_args: Array) -> void:
	var width := float(_browser.innerWidth)
	_banner_fits_viewport = width >= 600.0 and width > float(_browser.innerHeight)
	_sync_platform()


func set_provider(provider: AdsProvider) -> bool:
	if provider == null or _placement != &"":
		return false
	if is_node_ready():
		if _banner_shown:
			_provider.set_banner_visible(false)
			_banner_shown = false
		if _reported_gameplay:
			_provider.set_gameplay_active(false)
			_reported_gameplay = false
		_provider.rewarded_finished.disconnect(_on_rewarded_finished)
		_provider.interstitial_closed.disconnect(_on_interstitial_closed)
		_provider.request_failed.disconnect(_on_request_failed)
		_provider.banner_space_changed.disconnect(_on_banner_space_changed)
	_provider = provider
	if is_node_ready():
		_connect_provider()
		if _game_ready:
			_provider.game_ready()
		_sync_platform()
		_on_banner_space_changed()
	return true


func _connect_provider() -> void:
	_provider.rewarded_finished.connect(_on_rewarded_finished, CONNECT_DEFERRED)
	_provider.interstitial_closed.connect(_on_interstitial_closed, CONNECT_DEFERRED)
	_provider.request_failed.connect(_on_request_failed, CONNECT_DEFERRED)
	_provider.banner_space_changed.connect(_on_banner_space_changed)


func _on_banner_space_changed() -> void:
	var next := banner_clearance()
	if not is_equal_approx(_banner_space, next):
		_banner_space = next
		banner_space_changed.emit()


func banner_clearance() -> float:
	return _provider.banner_clearance()


func can_request_rewarded() -> bool:
	return _placement == &"" and _provider.can_request_rewarded()


func request_rewarded(placement: StringName) -> bool:
	if not can_request_rewarded() or placement not in [&"continue", &"hint", &"double_coins", FREE_COINS]:
		return false
	_begin(placement)
	_provider.request_rewarded(placement, _request_id)
	return true


func request_interstitial_after_result(level: int) -> bool:
	var now := Time.get_ticks_msec()
	if _placement != &"" or not _provider.can_request_interstitial() or level < 10 or now - _session_started < 120000 or now - _last_interstitial < 90000:
		return false
	_begin(INTERSTITIAL)
	_provider.request_interstitial(_request_id)
	return true


func notify_game_ready() -> void:
	if _game_ready:
		return
	_game_ready = true
	_provider.game_ready()
	_sync_platform()


func set_gameplay_active(active: bool, allow_banner := true) -> void:
	_gameplay_active = active
	set_gameplay_banner(active and allow_banner)


func set_gameplay_banner(visible: bool) -> void:
	_banner_wanted = visible
	_sync_platform()


func allows_support_link() -> bool:
	return _provider.allows_support_link()


func _sync_platform() -> void:
	var without_ad := _placement == &""
	var active := _game_ready and _gameplay_active and without_ad
	if active != _reported_gameplay:
		_reported_gameplay = active
		_provider.set_gameplay_active(active)
	var banner := active and _banner_wanted and _banner_fits_viewport
	if banner != _banner_shown:
		_banner_shown = banner
		_provider.set_banner_visible(banner)


func _begin(placement: StringName) -> void:
	_placement = placement
	_request_id += 1
	_previously_paused = get_tree().paused
	_previously_muted = AudioServer.is_bus_mute(0)
	get_tree().paused = true
	AudioServer.set_bus_mute(0, true)
	_sync_platform()
	_timeout.start()


func _end() -> void:
	_placement = &""
	_timeout.stop()
	get_tree().paused = _previously_paused
	AudioServer.set_bus_mute(0, _previously_muted)
	_sync_platform()


func _on_timeout() -> void:
	_provider.abandon_request(_request_id)
	_on_request_failed(_request_id)


func _on_request_failed(request_id: int) -> void:
	if _placement == INTERSTITIAL:
		_on_interstitial_closed(request_id)
	else:
		_on_rewarded_finished(request_id, false)


func _on_rewarded_finished(request_id: int, granted: bool) -> void:
	if request_id != _request_id or _placement in [&"", INTERSTITIAL]:
		return
	var placement := _placement
	_end()
	rewarded_finished.emit(placement, granted)


func _on_interstitial_closed(request_id: int) -> void:
	if request_id != _request_id or _placement != INTERSTITIAL:
		return
	_last_interstitial = Time.get_ticks_msec()
	_end()
	interstitial_closed.emit()
