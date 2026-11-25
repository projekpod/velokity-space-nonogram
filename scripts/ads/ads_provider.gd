extends RefCounted

@warning_ignore("unused_signal")
signal rewarded_finished(request_id: int, granted: bool)
@warning_ignore("unused_signal")
signal interstitial_closed(request_id: int)


func request_rewarded(_placement: StringName, request_id: int) -> void:
	rewarded_finished.emit.call_deferred(request_id, false)


func request_interstitial(request_id: int) -> void:
	interstitial_closed.emit.call_deferred(request_id)


func set_banner_visible(_visible: bool) -> void:
	pass
