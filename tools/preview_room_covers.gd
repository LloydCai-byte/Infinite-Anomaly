extends SceneTree
## Direct art review entry; always creates an isolated profile.
const Home = preload("res://scripts/pixel_home/home.gd")
var home
func _initialize() -> void:call_deferred("start")
func start() -> void:
	DisplayServer.window_set_title("无限异常 · 前十关封面预览 · 独立存档")
	home = Home.new()
	home.profile_override = OS.get_user_data_dir().path_join("cover-preview-%d.json" % Time.get_unix_time_from_system())
	root.add_child(home)
	await process_frame
	await process_frame
	home.finish_intro()
	home.close_dialog()
	home.gear.home.seen_rooms = range(1, 11)
	home.open_campaign()
	await process_frame
	home.campaign_ui.choose(1)
