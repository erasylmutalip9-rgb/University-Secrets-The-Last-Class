extends RefCounted

var data: Dictionary

func _init() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign.json"))

func level(id: int) -> Dictionary:
	return data.levels[clampi(id, 1, 20) - 1]

func clue(id: String) -> Array:
	const Legacy = preload("res://scripts/game.gd")
	if Legacy.CLUE_INFO.has(id):
		return Legacy.CLUE_INFO[id]
	var entry: Array = data.evidence.get(id, [id, "", "document"])
	return [entry[0], entry[1], 50]

func clue_type(id: String) -> String:
	if data.evidence.has(id):
		return str(data.evidence[id][2])
	return {"pass":"digital", "audit":"digital", "security":"digital", "usb":"usb", "trace":"trace", "old_photo":"photo"}.get(id, "document")
