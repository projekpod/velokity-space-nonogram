extends Node

const AdsProvider := preload("res://scripts/ads/ads_provider.gd")
const FakeAds := preload("res://scripts/ads/fake_ads.gd")

var provider: AdsProvider = FakeAds.new()
var _session_started := Time.get_ticks_msec()
var _last_interstitial := -90000


func show_rewarded(placement: StringName) -> bool:
	return placement in [&"continue", &"hint", &"double_coins"] and provider.show_rewarded(placement)


func show_interstitial_after_result(level: int) -> bool:
	var now := Time.get_ticks_msec()
	if level < 10 or now - _session_started < 120000 or now - _last_interstitial < 90000:
		return false
	_last_interstitial = now
	provider.show_interstitial()
	return true


func set_gameplay_banner(visible: bool) -> void:
	provider.set_banner_visible(visible)
