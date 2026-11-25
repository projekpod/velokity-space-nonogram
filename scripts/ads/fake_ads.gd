extends "res://scripts/ads/ads_provider.gd"

var grant_rewards := true
var interstitial_count := 0
var banner_visible := false


func show_rewarded(_placement: StringName) -> bool:
	return grant_rewards


func show_interstitial() -> void:
	interstitial_count += 1


func set_banner_visible(visible: bool) -> void:
	banner_visible = visible
