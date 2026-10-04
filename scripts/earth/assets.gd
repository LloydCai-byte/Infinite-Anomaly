extends RefCounted
static var entries: Dictionary={}
static var cache: Dictionary={}

static func initialize() -> void:
	if not entries.is_empty(): return
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/earth/asset_registry.json"))
	if data is Dictionary:
		for row in data.entries: entries[row.id]=row

static func path(id: String) -> String:
	initialize()
	if not entries.has(id): return ""
	var item=entries[id]
	for key in ["target_path","current_path"]:
		var p=str(item.get(key,""))
		if p!="" and ResourceLoader.exists("res://"+p): return "res://"+p
	return ""

static func texture(id: String) -> Texture2D:
	var p=path(id)
	if p=="":return null
	if not cache.has(p): cache[p]=load(p)
	return cache[p] as Texture2D

static func ui(name: String) -> Texture2D:
	return texture("ui."+name)

static func final_available(id: String) -> bool:
	initialize()
	if not entries.has(id): return false
	var p=str(entries[id].get("target_path",""))
	return p!="" and ResourceLoader.exists("res://"+p)
