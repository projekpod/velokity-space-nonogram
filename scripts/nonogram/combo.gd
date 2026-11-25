extends RefCounted

const THEME_LEVELS := [1, 1, 5, 10, 15, 20, 30]
const THEMES := [
	&"COMBO_SHOOTING_STAR", &"COMBO_COMET", &"COMBO_SUPERNOVA",
	&"COMBO_METEOR_SHOWER", &"COMBO_WARP", &"COMBO_AURORA", &"COMBO_BLACK_HOLE",
]
const COLORS := [
	Color("#ffe29b"), Color("#93f2e4"), Color("#ff9e83"), Color("#ffc386"),
	Color("#9bbcff"), Color("#a5ffcc"), Color("#d9b7ff"),
]


static func theme_count(level: int) -> int:
	for index in range(THEME_LEVELS.size() - 1, -1, -1):
		if level >= THEME_LEVELS[index]:
			return index + 1
	return 0


static func multiplier(lines: int) -> int:
	return 1 if lines < 3 else mini(lines - 1, 5)
