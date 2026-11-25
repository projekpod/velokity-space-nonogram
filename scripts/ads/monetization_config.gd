extends RefCounted

const PATH := "res://data/config/monetization.cfg"


static func support_url(path := PATH) -> String:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return ""
	var value: Variant = config.get_value("support", "url", "")
	if not value is String or not value.begins_with("https://"):
		return ""
	for character: String in value:
		if character.unicode_at(0) <= 32 or character == "\\":
			return ""
	var host: String = value.substr(8).get_slice("/", 0).get_slice("?", 0).get_slice("#", 0)
	return value if not host.is_empty() and not host.contains("@") else ""
