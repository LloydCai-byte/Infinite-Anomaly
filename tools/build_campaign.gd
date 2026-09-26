extends SceneTree
const OUT = "res://builds/InfiniteAnomaly-1.0/"
var packed: Dictionary = {}
var failed = false
var pack = PCKPacker.new()

func require_ok(code: Error, action: String) -> void:
	if code != OK:
		failed = true
		printerr(action + ": " + error_string(code))

func add(source: String, destination: String = "") -> void:
	var target=source if destination=="" else destination
	if packed.has(target): return
	require_ok(pack.add_file(target, source), "pack " + source)
	packed[target]=true
	if source.ends_with(".import"):
		var config=ConfigFile.new()
		require_ok(config.load(source),"read import remap")
		for path in config.get_value("deps","dest_files",[]): add(path)

func directory(path: String) -> void:
	var dir=DirAccess.open(path)
	if dir==null:
		failed=true
		printerr("Missing directory: "+path)
		return
	for name in dir.get_files():
		if name.ends_with(".gd") or name.ends_with(".png") or name.ends_with(".wav") or name.ends_with(".import"):
			add(path.path_join(name))
	for name in dir.get_directories(): directory(path.path_join(name))

func _initialize() -> void:
	require_ok(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT)),"create release folder")
	var config=ConfigFile.new()
	require_ok(config.load("res://project.godot"),"project settings")
	config.erase_section_key("autoload","Game")
	config.erase_section_key("autoload","Home")
	config.set_value("application","config/version","1.0.0")
	require_ok(config.save("res://.local/campaign-release.godot"),"release project settings")
	require_ok(pack.pck_start(OUT+"InfiniteAnomaly.pck"),"start pack")
	add("res://.local/campaign-release.godot","res://project.godot")
	for file in ["scenes/campaign/main.tscn","data/campaign.json","scripts/home/ui.gd","scripts/home/checkpoints.gd","scripts/save_store.gd"]:
		add("res://"+file)
	directory("res://scripts/campaign")
	directory("res://assets/v3")
	require_ok(pack.flush(),"finish pack")
	var licenses=FileAccess.open(OUT+"GODOT-LICENSE.txt",FileAccess.WRITE)
	licenses.store_string(Engine.get_license_text()+"\n\nThird-party components:\n"+JSON.stringify(Engine.get_license_info(),"  "))
	licenses.close()
	var manifest=FileAccess.open(OUT+"files.json",FileAccess.WRITE)
	manifest.store_string(JSON.stringify(packed.keys(),"  ")); manifest.close()
	print("CAMPAIGN_BUILD ",packed.size()," packed files; ","FAILED" if failed else "OK")
	quit(1 if failed else 0)
