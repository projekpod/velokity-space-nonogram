extends "res://scripts/ads/ads_provider.gd"

# Bridge's largest standard banner is 300×250 CSS pixels.
const BANNER_CLEARANCE := 258.0

enum Kind { NONE, REWARDED, INTERSTITIAL }

var _advertisement: Object
var _platform: Object
var _kind := Kind.NONE
var _request_id := 0
var _rewarded := false
var _abandoned := false
var _banner_requested := false
var _banner_state := "hidden"


func _init(advertisement: Object, platform: Object) -> void:
	_advertisement = advertisement
	_platform = platform
	_advertisement.banner_state_changed.connect(_on_banner_state)
	_advertisement.rewarded_state_changed.connect(_on_rewarded)
	_advertisement.interstitial_state_changed.connect(_on_interstitial)


func can_request_rewarded() -> bool:
	return _kind == Kind.NONE and _advertisement.is_rewarded_supported


func can_request_interstitial() -> bool:
	return _kind == Kind.NONE and _advertisement.is_interstitial_supported


func request_rewarded(placement: StringName, request_id: int) -> void:
	if not can_request_rewarded():
		request_failed.emit(request_id)
		return
	_begin(Kind.REWARDED, request_id)
	_advertisement.show_rewarded(String(placement))


func request_interstitial(request_id: int) -> void:
	if not can_request_interstitial():
		request_failed.emit(request_id)
		return
	_begin(Kind.INTERSTITIAL, request_id)
	_advertisement.show_interstitial()


func set_banner_visible(visible: bool) -> void:
	_banner_requested = visible and _advertisement.is_banner_supported
	if _banner_requested:
		_on_banner_state("loading")
		_advertisement.show_banner("bottom")
	elif banner_clearance() > 0.0:
		_advertisement.hide_banner()


func banner_clearance() -> float:
	return BANNER_CLEARANCE if _banner_state in ["loading", "shown"] else 0.0


func _on_banner_state(state: String) -> void:
	var previous := banner_clearance()
	_banner_state = state
	if banner_clearance() != previous:
		banner_space_changed.emit()
	if state == "shown" and not _banner_requested:
		_advertisement.hide_banner()


func game_ready() -> void:
	_platform.send_message("game_ready")


func set_gameplay_active(active: bool) -> void:
	_platform.send_message("gameplay_started" if active else "gameplay_stopped")


func allows_support_link() -> bool:
	return _platform.id == "mock" and _platform.is_external_links_allowed


func abandon_request(request_id: int) -> void:
	if _kind != Kind.NONE and _request_id == request_id:
		# Bridge reports global ad state. Wait for its terminal event before accepting a new request.
		_abandoned = true


func _begin(kind: Kind, request_id: int) -> void:
	_kind = kind
	_request_id = request_id
	_rewarded = false
	_abandoned = false


func _on_rewarded(state: String) -> void:
	if _kind != Kind.REWARDED:
		return
	match state:
		"rewarded":
			_rewarded = true
		"closed", "failed":
			_finish(state == "closed")


func _on_interstitial(state: String) -> void:
	if _kind == Kind.INTERSTITIAL and state in ["closed", "failed"]:
		_finish(state == "closed")


func _finish(closed: bool) -> void:
	var kind := _kind
	var id := _request_id
	_kind = Kind.NONE
	if _abandoned:
		return
	if not closed:
		request_failed.emit(id)
	elif kind == Kind.REWARDED:
		rewarded_finished.emit(id, _rewarded)
	else:
		interstitial_closed.emit(id)
