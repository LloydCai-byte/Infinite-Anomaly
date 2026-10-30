extends SceneTree
const Home=preload("res://scripts/pixel_home/home.gd")
var out="res://docs/feedback-revision-20261028/verification/hud/"
var home
func _initialize() -> void:
	root.size=Vector2i(1600,900);root.content_scale_size=Vector2i(1600,900)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--feedback-output="):out=arg.trim_prefix("--feedback-output=").trim_suffix("/")+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out));call_deferred("run")
func shot(name:String) -> void:
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out+name+".png")
func run() -> void:
	home=Home.new();root.add_child(home);await process_frame;await process_frame
	home.finish_intro();home.close_dialog();home.player=Vector2(800,740);home.arrival=0;await shot("home")
	home.depart(0);home.battle.paused=true;await shot("battle")
	print("VISIBLE BATTLE CONTROLS ",home.battle.controls.keys())
	home.battle.open_equipment();await shot("equipment")
	home.battle.close_equipment();home.finish_return();home.close_dialog()
	print("FEEDBACK_CAPTURE complete; isolated profile=",home.battle.profile_path)
	home.queue_free();await process_frame;quit()
