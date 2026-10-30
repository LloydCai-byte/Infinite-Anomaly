extends SceneTree
const Home=preload("res://scripts/pixel_home/home.gd")
const Gear=preload("res://scripts/pixel_home/gear.gd")
var output=""
var profile=""
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--profile="):profile=arg.trim_prefix("--profile=")
		if arg.begins_with("--audit-output="):output=arg.trim_prefix("--audit-output=")
	if profile.is_empty() or output.is_empty():quit(2);return
	call_deferred("run")
func run()->void:
	var before=Gear.new(42);before.open_profile(profile)
	var original=before.snapshot();var checks=[]
	var home=Home.new();home.profile_override=profile;root.add_child(home);await process_frame;await process_frame
	home.finish_intro();home.close_dialog();home.set_process(false);home.battle.set_process(false)
	var loaded=home.gear.snapshot()
	checks.append({"name":"normal save copy preserves inventory equipment gold and growth","pass":loaded.state==original.state and loaded.growth==original.growth})
	home.open_campaign();await process_frame;await process_frame
	checks.append({"name":"normal save copy opens number-only portal","pass":not home.campaign_ui.title.visible and not home.campaign_ui.detail.visible and home.campaign_ui.selected>0})
	home.close_campaign();home.open_overlay("equipment");await process_frame
	checks.append({"name":"normal save copy opens interactive equipment UI","pass":home.battle.equipment_ui.is_visible_in_tree() and home.battle.equipment_ui.controls.size()>0})
	var f=FileAccess.open(output,FileAccess.WRITE);var failures=checks.filter(func(c):return not c.pass)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"inventory":home.gear.s.inventory.size(),"profile":profile,"original_profile_loaded":false},"\t"));f.close()
	print("NORMAL_SAVE_COPY ",checks.size()," checks ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
