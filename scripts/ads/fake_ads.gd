extends "res://scripts/ads/ads_provider.gd"

var available := true
var grant_rewards := true
var interstitial_count := 0
var banner_visible := false


func request_rewarded(_placement: StringName, request_id: int) -> void:
	rewarded_finished.emit.call_deferred(request_id, grant_rewards)


func request_interstitial(request_id: int) -> void:
	interstitial_count += 1
	interstitial_closed.emit.call_deferred(request_id)


func set_banner_visible(visible: bool) -> void:
	banner_visible = visible


func can_request_rewarded() -> bool:
	return available


func can_request_interstitial() -> bool:
	return available
