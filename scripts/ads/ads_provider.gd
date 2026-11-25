extends RefCounted

@warning_ignore("unused_signal")
signal rewarded_finished(request_id: int, granted: bool)
@warning_ignore("unused_signal")
signal interstitial_closed(request_id: int)
@warning_ignore("unused_signal")
signal request_failed(request_id: int)


func request_rewarded(_placement: StringName, request_id: int) -> void:
	rewarded_finished.emit.call_deferred(request_id, false)


func request_interstitial(request_id: int) -> void:
	interstitial_closed.emit.call_deferred(request_id)


func set_banner_visible(_visible: bool) -> void:
	pass


func can_request_rewarded() -> bool:
	return true


func can_request_interstitial() -> bool:
	return true


func game_ready() -> void:
	pass


func set_gameplay_active(_active: bool) -> void:
	pass


func allows_support_link() -> bool:
	return false


func abandon_request(_request_id: int) -> void:
	pass
