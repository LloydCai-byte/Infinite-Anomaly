extends SceneTree
const Home = preload("res://scripts/pixel_home/home.gd")
const Covers = preload("res://scripts/pixel_home/room_covers.gd")
var output = ""
var requested = ""
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--audit-output="):output = arg.trim_prefix("--audit-output=")
		if arg.begins_with("--profile="):requested = arg.trim_prefix("--profile=")
	if output.is_empty() or requested.is_empty():quit(2);return
	call_deferred("run")
func run() -> void:
	var home = Home.new()
	root.add_child(home)
	await process_frame
	await process_frame
	var covers = Covers.new()
	var pairs = 0
	for entry in covers.rooms.values():
		if entry.has("portrait") and entry.has("landscape"):pairs += 1
	var report = {"version":ProjectSettings.get_setting("application/config/version",""),"profile":home.battle.profile_path,"requested":requested,"rooms":home.battle.model.level_defs.size(),"waves":home.battle.model.scene_count(),"xuan_frames":home.life.atlas.xuan.frames.size(),"cover_pairs":pairs}
	report["pass"] = report.version == "0.38.0-room-covers" and report.profile == requested and report.rooms == 20 and report.waves == 10 and report.xuan_frames == 36 and pairs == 10
	var file = FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	home.queue_free()
	await process_frame
	quit(0 if report.pass else 1)
