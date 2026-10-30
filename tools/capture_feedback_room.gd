extends SceneTree
const Home=preload("res://scripts/pixel_home/home.gd")
var room="living"
var out="res://docs/feedback-revision-20261028/verification/rooms/"
func _initialize() -> void:
	root.size=Vector2i(1600,900);root.content_scale_size=Vector2i(1600,900)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--room="):room=arg.trim_prefix("--room=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out));call_deferred("run")
func run() -> void:
	var home=Home.new();root.add_child(home);await process_frame;await process_frame
	home.finish_intro();home.close_dialog();home.change_room(room,home.Rooms.data(room).spawn);home.arrival=0
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out+room+"-runtime.png")
	print("ROOM_CAPTURE ",room," player=",home.player," companions=",home.companions().size())
	home.queue_free();await process_frame;quit()
