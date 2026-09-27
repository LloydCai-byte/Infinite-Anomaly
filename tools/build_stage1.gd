extends SceneTree
var packed: Dictionary = {}
var failed = false
var pack = PCKPacker.new()
const OUT = "res://builds/InfiniteAnomaly-Stage1/"

func checked(code: Error, label: String) -> void:
	if code != OK:
		failed = true
		printerr(label + ": " + error_string(code))

func add(path: String, destination: String = "") -> void:
	var target = destination if destination != "" else path
	if packed.has(target):
		return
	checked(pack.add_file(target,path),"pack " + path)
	packed[target] = true
	if path.ends_with(".import"):
		var remap = ConfigFile.new()
		checked(remap.load(path),"read import")
		for generated in remap.get_value("deps","dest_files",[]):
			add(generated)

func add_directory(path: String) -> void:
	var dir = DirAccess.open(path)
	if dir == null:
		failed = true
		return
	for name in dir.get_files():
		if name.get_extension() in ["gd","png","wav","import"]:
			add(path.path_join(name))
	for name in dir.get_directories():
		add_directory(path.path_join(name))

func _initialize() -> void:
	checked(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT)),"output directory")
	var config = ConfigFile.new()
	checked(config.load("res://project.godot"),"settings")
	# The release contains only the new flow. Old autoloads remain in source for history.
	config.erase_section("autoload")
	checked(config.save("res://.local/stage1-release.godot"),"release settings")
	checked(pack.pck_start(OUT+"InfiniteAnomaly.pck"),"start pack")
	add("res://.local/stage1-release.godot","res://project.godot")
	for path in ["scenes/continuity/main.tscn","scripts/save_store.gd","data/continuity/floor.json"]:
		add("res://"+path)
	add_directory("res://scripts/continuity")
	add_directory("res://assets/continuity")
	checked(pack.flush(),"finish pack")
	var manifest = FileAccess.open(OUT+"files.json",FileAccess.WRITE)
	manifest.store_string(JSON.stringify(packed.keys(),"  "))
	manifest.close()
	var license_file = FileAccess.open(OUT+"GODOT-LICENSE.txt",FileAccess.WRITE)
	license_file.store_string(Engine.get_license_text()+"\n"+JSON.stringify(Engine.get_license_info(),"  "))
	license_file.close()
	print("STAGE1_BUILD ",packed.size()," files; ","FAILED" if failed else "OK")
	quit(1 if failed else 0)
