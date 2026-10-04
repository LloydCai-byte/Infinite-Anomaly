extends SceneTree
const Assets=preload("res://scripts/earth/assets.gd")
var failures=0
var checks=0
func ck(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL "+label)
func _initialize() -> void:
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/earth/asset_registry.json"))
	Assets.initialize()
	ck(data.entries.size()==Assets.entries.size(),"unique stable IDs")
	ck(data.entries.size()==278,"248 existing entries plus 10 anomaly backgrounds and 20 monster poses")
	for entry in data.entries:
		ck(str(entry.target_path).begins_with("assets/earth/"),"replacement isolated from legacy: "+entry.id)
		if entry.current_path!="":ck(ResourceLoader.exists("res://"+entry.current_path),"baseline exists "+entry.id)
		if entry.id.begins_with("room."):
			ck(Assets.texture(entry.id).get_size()==Vector2(1920,1080),"room full HD "+entry.id)
		if entry.id.begins_with("ui.") or entry.id.begins_with("battle.") or entry.id.begins_with("opening.") or entry.id=="menu":
			if entry.get("render_mode","")=="time_card":
				var shots=JSON.parse_string(FileAccess.get_file_as_string("res://assets/earth/opening.json"))
				ck(shots[5].id=="06" and shots[5].get("presentation","")=="time_card","native time card explicitly renders without bitmap")
			else:ck(Assets.texture(entry.id)!=null,"runtime image resolves "+entry.id)
		if entry.id.begins_with("audio."):
			ck(load(Assets.path(entry.id)) is AudioStream,"audio resolves "+entry.id)
	for person in ["dadong","fenfen","gao","wang","qiqi"]:
		for tier in range(1,4):
			var id="actor.%s.t%d.idle"%[person,tier]
			var path=Assets.path(id)
			if path!="":
				var frames=load(path) as SpriteFrames
				ck(frames!=null,"SpriteFrames type "+id)
				if frames!=null:
					for action in ["idle","move","attack","hit","fall"]:ck(frames.has_animation(action) and frames.get_frame_count(action)>0,"action exists "+id+action)
	print("EARTH ASSETS ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
