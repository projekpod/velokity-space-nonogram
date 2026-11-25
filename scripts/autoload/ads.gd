extends Node

signal rewarded_finished(placement: StringName, granted: bool)
signal interstitial_closed

const AdsProvider := preload("res://scripts/ads/ads_provider.gd")
const FakeAds := preload("res://scripts/ads/fake_ads.gd")
const INTERSTITIAL := &"interstitial"
const TIMEOUT_SECONDS := 45.0

var _provider: AdsProvider = FakeAds.new()
var _session_started := Time.get_ticks_msec()
var _last_interstitial := -90000
var _placement: StringName
var _request_id := 0
var _previously_paused := false
var _timeout: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_timeout = Timer.new()
	_timeout.one_shot = true
	_timeout.ignore_time_scale = true
	_timeout.wait_time = TIMEOUT_SECONDS
	_timeout.timeout.connect(func() -> void: _on_request_failed(_request_id))
	add_child(_timeout)
	_connect_provider()


func set_provider(provider: AdsProvider) -> bool:
	if provider == null or _placement != &"":
		return false
	if is_node_ready():
		_provider.rewarded_finished.disconnect(_on_rewarded_finished)
		_provider.interstitial_closed.disconnect(_on_interstitial_closed)
		_provider.request_failed.disconnect(_on_request_failed)
	_provider = provider
	if is_node_ready():
		_connect_provider()
	return true


func _connect_provider() -> void:
	_provider.rewarded_finished.connect(_on_rewarded_finished, CONNECT_DEFERRED)
	_provider.interstitial_closed.connect(_on_interstitial_closed, CONNECT_DEFERRED)
	_provider.request_failed.connect(_on_request_failed, CONNECT_DEFERRED)


func request_rewarded(placement: StringName) -> bool:
	if _placement != &"" or placement not in [&"continue", &"hint", &"double_coins"]:
		return false
	_begin(placement)
	_provider.request_rewarded(placement, _request_id)
	return true


func request_interstitial_after_result(level: int) -> bool:
	var now := Time.get_ticks_msec()
	if _placement != &"" or level < 10 or now - _session_started < 120000 or now - _last_interstitial < 90000:
		return false
	_begin(INTERSTITIAL)
	_provider.request_interstitial(_request_id)
	return true


func set_gameplay_banner(visible: bool) -> void:
	_provider.set_banner_visible(visible)


func _begin(placement: StringName) -> void:
	_placement = placement
	_request_id += 1
	_previously_paused = get_tree().paused
	get_tree().paused = true
	_timeout.start()


func _end() -> void:
	_placement = &""
	_timeout.stop()
	get_tree().paused = _previously_paused


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
