extends SceneTree
const Home=preload("res://scripts/pixel_home/home.gd")
const Store=preload("res://scripts/pixel_home/room_save.gd")
var output=""
var requested=""
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--audit-output="):output=arg.trim_prefix("--audit-output=")
		if arg.begins_with("--profile="):requested=arg.trim_prefix("--profile=")
	if output.is_empty() or requested.is_empty():quit(2);return
	call_deferred("run")
func run()->void:
	var home=Home.new();root.add_child(home);await process_frame;await process_frame
	var battle=home.battle
	var report={"version":ProjectSettings.get_setting("application/config/version",""),"profile":battle.profile_path,"requested":requested,"rooms":battle.model.level_defs.size(),"waves":battle.model.scene_count(),"difficulty_max":home.gear.unlocked_depth(),"xuan_frames":home.life.atlas.xuan.frames.size(),"compressed_store":home.gear.persistence is Store,"auto_salvage":home.gear.salvage_rules.auto_max_quality,"portal_menu":FileAccess.file_exists("res://art/feedback-portal-polish-20261030/plate.png")}
	report["pass"]=report.version=="0.37.0-portal-polish" and report.profile==requested and report.rooms==20 and report.waves==10 and report.difficulty_max==10 and report.xuan_frames==36 and report.compressed_store and report.auto_salvage==-1 and report.portal_menu
	var f=FileAccess.open(output,FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close()
	home.queue_free();await process_frame;quit(0 if report.pass else 1)
