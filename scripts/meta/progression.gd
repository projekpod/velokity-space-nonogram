extends RefCounted

const Daily := preload("res://scripts/daily/calendar.gd")

const XP_PER_LEVEL := 200
const CLEAR_XP := 100
const BADGE_XP := 20
const BONUS_XP := 40
const MAX_XP := 2147483647
const LOGIN_REWARDS := [10, 15, 15, 20, 20, 30, 40]
const SLOTS := ["helmet", "suit", "jetpack", "accessory"]
const ALBUM_REWARDS := {"moon": "moonlight", "mars": "red_dust", "saturn": "ring_runner"}
const ACHIEVEMENTS := {
	"explorer": {"goal": 5, "costume": "pathfinder"},
	"flawless": {"goal": 4, "costume": "perfect_signal"},
	"stargazer": {"goal": 7, "costume": "star_chart"},
	"bonus_pilot": {"goal": 3, "costume": "bonus_booster"},
}
const COSTUMES := {
	"mint_visor": {"slot": "helmet", "color": Color("#87e4be"), "price": 400},
	"violet_visor": {"slot": "helmet", "color": Color("#bb9df7"), "price": 800},
	"solar_visor": {"slot": "helmet", "color": Color("#f8bb6e"), "price": 1600},
	"nebula_suit": {"slot": "suit", "color": Color("#91a8f8"), "price": 650},
	"copper_pack": {"slot": "jetpack", "color": Color("#eaa38b"), "price": 1200},
	"prism_pack": {"slot": "jetpack", "color": Color("#8aceec"), "price": 2000},
	"coral_signal": {"slot": "accessory", "color": Color("#ff9db3"), "price": 550},
	"moonlight": {"slot": "helmet", "color": Color("#a7cef2"), "album": "moon"},
	"red_dust": {"slot": "suit", "color": Color("#f78c79"), "album": "mars"},
	"ring_runner": {"slot": "jetpack", "color": Color("#eed388"), "album": "saturn"},
	"pathfinder": {"slot": "suit", "color": Color("#8de0df"), "achievement": "explorer"},
	"perfect_signal": {"slot": "accessory", "color": Color("#bb9df7"), "achievement": "flawless"},
	"star_chart": {"slot": "helmet", "color": Color("#a1a9db"), "achievement": "stargazer"},
	"bonus_booster": {"slot": "jetpack", "color": Color("#98e4ae"), "achievement": "bonus_pilot"},
}


static func defaults() -> Dictionary:
	return {"xp": 0, "login": Daily.empty_progress(), "purchased": {}, "equipped": {}}


static func costume_title(id: String) -> String:
	return "COSTUME_" + id.to_upper()


static func achievement_title(id: String) -> String:
	return "ACHIEVEMENT_" + id.to_upper()
