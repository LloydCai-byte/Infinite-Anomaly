extends SceneTree
const OUT="res://builds/InfiniteAnomaly-Earth-0.11.0/"
var pack=PCKPacker.new()
var packed: Dictionary={}
var failed=false

func checked(code: Error,label: String) -> void:
	if code!=OK: failed=true;printerr(label+": "+error_string(code))

func add(path: String,target="") -> void:
	if target=="":target=path
	if packed.has(target):return
	checked(pack.add_file(target,path),"pack "+path)
	packed[target]=true
	if path.ends_with(".import"):
		var config=ConfigFile.new()
		checked(config.load(path),"import metadata")
		for generated in config.get_value("deps","dest_files",[]):add(generated)

func directory(path: String) -> void:
	var d=DirAccess.open(path)
	if d==null:failed=true;printerr("Missing "+path);return
	for file in d.get_files():
		if file.get_extension() in ["gd","tres","png","svg","wav","ogg","json","import","gdshader"]:add(path.path_join(file))
	for sub in d.get_directories():directory(path.path_join(sub))

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var config=ConfigFile.new()
	checked(config.load("res://project.godot"),"read project")
	config.set_value("application","config/name","无限异常")
	config.set_value("application","config/description","五人出战与成长、七个房间交互。地球篇功能版，美术分项替换。")
	config.set_value("application","config/version","0.11.0-earth-kaidan")
	config.set_value("application","run/main_scene","res://scenes/earth/main.tscn")
	checked(config.save("res://.local/earth-project.godot"),"pack config")
	checked(pack.pck_start(OUT+"InfiniteAnomaly.pck"),"pack start")
	add("res://.local/earth-project.godot","res://project.godot")
	for scene in ["earth","reboot"]:add("res://scenes/"+scene+"/main.tscn")
	for path in ["scripts/earth","scripts/reboot","assets/earth","assets/reboot","assets/character_sequences"]:directory("res://"+path)
	checked(pack.flush(),"pack flush")
	var f=FileAccess.open(OUT+"files.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(packed.keys(),"  "));f.close()
	f=FileAccess.open(OUT+"GODOT-LICENSE.txt",FileAccess.WRITE)
	f.store_string(Engine.get_license_text()+"\n"+JSON.stringify(Engine.get_license_info(),"  "));f.close()
	print("EARTH BUILD ",packed.size()," files / ","FAILED" if failed else "OK")
	quit(1 if failed else 0)
