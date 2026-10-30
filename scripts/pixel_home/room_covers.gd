extends RefCounted
## Cover artwork belongs to stable room IDs and never replaces battle scenes.
const CATALOG = "res://assets/pixel_campaign/room_covers.json"
var rooms: Dictionary = {}

func _init() -> void:
	if not FileAccess.file_exists(CATALOG):return
	var data = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	if not data is Dictionary or not data.get("rooms") is Dictionary:return
	for key in data.rooms:
		var entry = data.rooms[key]
		if not entry is Dictionary:continue
		var valid: Dictionary = {"source_image":str(entry.get("source_image", ""))}
		for kind in ["portrait", "landscape"]:
			var path = str(entry.get(kind, ""))
			if not path.is_empty() and FileAccess.file_exists(path):valid[kind] = path
		rooms[key] = valid

func path_for(id: int, scene_image: String, kind: String) -> String:
	var entry: Dictionary = rooms.get("R%04d" % id, {})
	if entry.get("source_image", "") != scene_image:return scene_image
	return str(entry.get(kind, scene_image))

static func source_rect(texture_size: Vector2, target_size: Vector2) -> Rect2:
	if texture_size.x <= 0 or texture_size.y <= 0 or target_size.x <= 0 or target_size.y <= 0:return Rect2()
	var factor = maxf(target_size.x / texture_size.x, target_size.y / texture_size.y)
	var crop_size = target_size / factor
	return Rect2((texture_size - crop_size) * .5, crop_size)
