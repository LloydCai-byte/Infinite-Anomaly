extends RefCounted

static func get_data() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/home_content.json"))
