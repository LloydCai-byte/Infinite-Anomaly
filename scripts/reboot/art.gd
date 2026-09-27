extends RefCounted
static var textures: Dictionary = {}
static var manifest: Dictionary = {}
static var frames: Dictionary = {}

static func texture(path: String) -> Texture2D:
	if not textures.has(path): textures[path]=load(path)
	return textures[path]

static func ui(name: String) -> Texture2D:
	return texture("res://assets/reboot/ui/"+name+".svg")

static func initialize() -> void:
	if manifest.is_empty(): manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/reboot/art_manifest.json"))

static func frame(id: String, index: int) -> AtlasTexture:
	initialize()
	var key=id+str(index)
	if not frames.has(key):
		var data=manifest[id]
		var a=AtlasTexture.new()
		a.atlas=texture("res://"+data.path)
		var r=data.frames[clampi(index,0,data.frames.size()-1)].region
		a.region=Rect2(r[0],r[1],r[2],r[3])
		a.filter_clip=true
		frames[key]=a
	return frames[key]

static func background(id: String) -> Texture2D:
	return texture("res://assets/reboot/backgrounds/"+id+".png")
