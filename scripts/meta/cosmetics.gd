extends RefCounted

enum Rarity { COMMON, RARE, EPIC, LEGENDARY }

const DEFAULT_CAT := "velokity"
const DEFAULT_SKIN := "natural"
const CATS := {
	"velokity": {"price": 0, "rarity": Rarity.COMMON, "color": Color("#ed9960")},
	"british_shorthair": {"price": 2500, "rarity": Rarity.RARE, "color": Color("#8d9cb2")},
	"siamese": {"price": 3000, "rarity": Rarity.RARE, "color": Color("#efcfaa")},
	"sphynx": {"price": 3500, "rarity": Rarity.RARE, "color": Color("#db9c94")},
	"devon_rex": {"price": 4000, "rarity": Rarity.RARE, "color": Color("#b99882")},
	"persian": {"price": 6000, "rarity": Rarity.EPIC, "color": Color("#e9e0d8")},
	"ragdoll": {"price": 7500, "rarity": Rarity.EPIC, "color": Color("#ecdac3")},
	"bengal": {"price": 9000, "rarity": Rarity.EPIC, "color": Color("#d89655")},
	"maine_coon": {"price": 18000, "caption": "CAT_POPULAR", "rarity": Rarity.LEGENDARY, "color": Color("#af7459")},
	"savannah": {"price": 25000, "caption": "CAT_MOST_EXPENSIVE", "rarity": Rarity.LEGENDARY, "color": Color("#ddba79")},
}
const SKINS := {
	"natural": {"price": 0, "rarity": Rarity.COMMON, "color": Color("#ed9960")},
	"black": {"price": 500, "rarity": Rarity.COMMON, "color": Color("#363748")},
	"white": {"price": 500, "rarity": Rarity.COMMON, "color": Color("#f1eced")},
	"grey": {"price": 650, "rarity": Rarity.COMMON, "color": Color("#9fa6b2")},
	"calico": {"price": 900, "rarity": Rarity.COMMON, "color": Color("#f5e9cf")},
	"tuxedo": {"price": 1000, "rarity": Rarity.COMMON, "color": Color("#45465a")},
	"cream": {"price": 2000, "rarity": Rarity.RARE, "color": Color("#efceb0")},
	"chocolate": {"price": 2000, "rarity": Rarity.RARE, "color": Color("#8a594d")},
	"galaxy": {"price": 6000, "rarity": Rarity.EPIC, "color": Color("#7c659c")},
	"gold": {"price": 15000, "rarity": Rarity.LEGENDARY, "color": Color("#e6af48")},
}
const FRAME_COLORS := [Color("#394c67"), Color("#5599e8"), Color("#bb82f2"), Color("#f5c775")]
const TITLE_PREFIX := {"cat": "CAT_", "skin": "SKIN_", "costume": "COSTUME_"}


static func items(category: String) -> Dictionary:
	match category:
		"cat":
			return CATS
		"skin":
			return SKINS
	return {}


static func title(category: String, id: String) -> String:
	if category == "costume" and id.is_empty():
		return "COSTUME_DEFAULT"
	return TITLE_PREFIX[category] + id.to_upper()


static func rarity_title(rarity: int) -> String:
	return "SHOP_RARITY_" + Rarity.keys()[rarity]
