extends SceneTree
const OUT="res://builds/InfiniteAnomaly-Reboot-Full-0.5.3/"
var pack=PCKPacker.new()
var packed: Dictionary={}
var failed=false

func checked(code: Error,label: String) -> void:
	if code!=OK:
		failed=true
		printerr(label+": "+error_string(code))

func add(path: String,target="") -> void:
	if target=="": target=path
	if packed.has(target): return
	checked(pack.add_file(target,path),"pack "+path)
	packed[target]=true
	if path.ends_with(".import"):
		var config=ConfigFile.new()
		checked(config.load(path),"import metadata")
		for generated in config.get_value("deps","dest_files",[]): add(generated)

func directory(path: String) -> void:
	var d=DirAccess.open(path)
	if d==null:
		failed=true
		return
	for file in d.get_files():
		if file.get_extension() in ["gd","tres","png","svg","wav","json","import"]: add(path.path_join(file))
	for sub in d.get_directories(): directory(path.path_join(sub))

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var config=ConfigFile.new()
	checked(config.load("res://project.godot"),"read project")
	config.set_value("application","config/name","无限异常")
	config.set_value("application","config/description","培养四人，送往星海。百万房间与真实远征。")
	config.set_value("application","config/version","0.5.3-street")
	config.set_value("application","run/main_scene","res://scenes/reboot/main.tscn")
	config.set_value("display","window/size/viewport_width",1600)
	config.set_value("display","window/size/viewport_height",900)
	config.set_value("display","window/size/window_width_override",1600)
	config.set_value("display","window/size/window_height_override",900)
	config.set_value("display","window/stretch/mode","canvas_items")
	checked(config.save("res://.local/reboot-project.godot"),"pack project config")
	checked(pack.pck_start(OUT+"InfiniteAnomaly.pck"),"pack start")
	add("res://.local/reboot-project.godot","res://project.godot")
	add("res://scenes/reboot/main.tscn")
	directory("res://scripts/reboot")
	add("res://scripts/earth/gait.gd")
	directory("res://assets/reboot")
	directory("res://assets/character_sequences")
	checked(pack.flush(),"pack flush")
	var f=FileAccess.open(OUT+"files.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(packed.keys(),"  "))
	f.close()
	f=FileAccess.open(OUT+"GODOT-LICENSE.txt",FileAccess.WRITE)
	f.store_string(Engine.get_license_text()+"\n"+JSON.stringify(Engine.get_license_info(),"  "))
	f.close()
	print("REBOOT_BUILD ",packed.size()," files / ","FAILED" if failed else "OK")
	quit(1 if failed else 0)
