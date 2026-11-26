extends RefCounted

const Cosmetics := preload("res://scripts/meta/cosmetics.gd")
const Rarity := Cosmetics.Rarity
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
	"mint_visor": {"slot": "helmet", "color": Color("#87e4be"), "price": 425, "rarity": Rarity.COMMON},
	"violet_visor": {"slot": "helmet", "color": Color("#bb9df7"), "price": 900, "rarity": Rarity.COMMON},
	"solar_visor": {"slot": "helmet", "color": Color("#f8bb6e"), "price": 2600, "rarity": Rarity.RARE},
	"nebula_suit": {"slot": "suit", "color": Color("#91a8f8"), "price": 750, "rarity": Rarity.COMMON},
	"copper_pack": {"slot": "jetpack", "color": Color("#eaa38b"), "price": 1800, "rarity": Rarity.RARE},
	"prism_pack": {"slot": "jetpack", "color": Color("#8aceec"), "price": 3200, "rarity": Rarity.RARE},
	"coral_signal": {"slot": "accessory", "color": Color("#ff9db3"), "price": 600, "rarity": Rarity.COMMON},
	"ion_visor": {"slot": "helmet", "color": Color("#9077e8"), "price": 5000, "rarity": Rarity.EPIC},
	"aurora_suit": {"slot": "suit", "color": Color("#59dbc6"), "price": 6500, "rarity": Rarity.EPIC},
	"pulsar_pack": {"slot": "jetpack", "color": Color("#d17dde"), "price": 8000, "rarity": Rarity.EPIC},
	"halo_signal": {"slot": "accessory", "color": Color("#f4d166"), "price": 12000, "rarity": Rarity.LEGENDARY},
	"royal_suit": {"slot": "suit", "color": Color("#e5a948"), "price": 15000, "rarity": Rarity.LEGENDARY},
	"moonlight": {"slot": "helmet", "color": Color("#a7cef2"), "album": "moon"},
	"red_dust": {"slot": "suit", "color": Color("#f78c79"), "album": "mars"},
	"ring_runner": {"slot": "jetpack", "color": Color("#eed388"), "album": "saturn"},
	"pathfinder": {"slot": "suit", "color": Color("#8de0df"), "achievement": "explorer"},
	"perfect_signal": {"slot": "accessory", "color": Color("#bb9df7"), "achievement": "flawless"},
	"star_chart": {"slot": "helmet", "color": Color("#a1a9db"), "achievement": "stargazer"},
	"bonus_booster": {"slot": "jetpack", "color": Color("#98e4ae"), "achievement": "bonus_pilot"},
}


static func defaults() -> Dictionary:
	return {
		"xp": 0, "login": Daily.empty_progress(), "purchased": {}, "equipped": {},
		"cats": {}, "skins": {}, "cat": Cosmetics.DEFAULT_CAT, "skin": Cosmetics.DEFAULT_SKIN,
	}


static func costume_title(id: String) -> String:
	return "COSTUME_" + id.to_upper()


static func achievement_title(id: String) -> String:
	return "ACHIEVEMENT_" + id.to_upper()
