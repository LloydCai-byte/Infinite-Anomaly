extends SceneTree
var packed: Dictionary = {}
var failed = false
var pack = PCKPacker.new()
const OUT = "res://builds/InfiniteAnomaly-Full/"

func checked(code: Error, label: String) -> void:
	if code != OK:
		failed = true
		printerr(label+": "+error_string(code))

func add(path: String, destination: String = "") -> void:
	var target = destination if destination != "" else path
	if packed.has(target): return
	checked(pack.add_file(target,path),"pack "+path)
	packed[target] = true
	if path.ends_with(".import"):
		var remap = ConfigFile.new()
		checked(remap.load(path),"read import")
		for generated in remap.get_value("deps","dest_files",[]): add(generated)

func add_directory(path: String) -> void:
	var dir = DirAccess.open(path)
	if dir == null:
		failed = true
		return
	for name in dir.get_files():
		if name.get_extension() in ["gd","gdshader","png","wav","import","json"]: add(path.path_join(name))
	for name in dir.get_directories(): add_directory(path.path_join(name))

func _initialize() -> void:
	checked(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT)),"output directory")
	checked(pack.pck_start(OUT+"InfiniteAnomaly.pck"),"start pack")
	for path in ["project.godot","scenes/containment/main.tscn","scripts/save_store.gd","scripts/continuity/hotspot.gd"]: add("res://"+path)
	for directory in ["scripts/containment","data/containment","assets/continuity","assets/containment","assets/home"]: add_directory("res://"+directory)
	checked(pack.flush(),"finish pack")
	var manifest = FileAccess.open(OUT+"files.json",FileAccess.WRITE)
	manifest.store_string(JSON.stringify(packed.keys(),"  "))
	manifest.close()
	var license_file = FileAccess.open(OUT+"GODOT-LICENSE.txt",FileAccess.WRITE)
	license_file.store_string(Engine.get_license_text()+"\n"+JSON.stringify(Engine.get_license_info(),"  "))
	license_file.close()
	print("FULL_BUILD ",packed.size()," files; ","FAILED" if failed else "OK")
	quit(1 if failed else 0)
