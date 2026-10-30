extends SceneTree
var home
var out=""
var profile=""
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shadow-output="):out=arg.trim_prefix("--shadow-output=").trim_suffix("/")+"/"
		if arg.begins_with("--shadow-profile="):profile=arg.trim_prefix("--shadow-profile=")
	if out.is_empty():quit(2);return
	DirAccess.make_dir_recursive_absolute(out);root.size=Vector2i(1600,900);root.content_scale_size=Vector2i(1600,900);call_deferred("run")
func capture(name:String)->void:
	home.queue_redraw();home.battle.queue_redraw();await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out+name+".png")
func run()->void:
	home=load("res://scripts/pixel_home/home.gd").new();home.profile_override=out+"isolated.json" if profile.is_empty() else profile;root.add_child(home)
	await process_frame;await process_frame;home.finish_intro();home.close_dialog();home.set_process(false);home.arrival=0
	var view=home.battle;view.set_process(false);view.set_process_unhandled_input(false);view.sound_enabled=false
	home.mode="battle";home.ui.hide();view.show();view.paused=false;view.auto_next=false
	for index in [14,0,13]:
		view.begin_level(index);view.set_process(false);view.enemy_arrival.active=false;view.travel.active=false;view.visual_clock=0
		for u in view.model.units:u.anim="idle";u.anim_time=0;u.pos=u.home;u.hit_time=0
		await capture("room-%02d-idle"%(index+1))
		if index==14:
			for u in view.model.units:u.anim="walk";u.anim_time=4.0/view.roster[u.get("visual_id",u.id)].clips.walk.fps
			await capture("room-15-walk")
			for u in view.model.units:u.anim="attack";u.anim_time=10.0/view.roster[u.get("visual_id",u.id)].clips.attack.fps
			await capture("room-15-attack")
	print("SHADOW_CAPTURE ",ProjectSettings.get_setting("application/config/version")," ",out);quit()
