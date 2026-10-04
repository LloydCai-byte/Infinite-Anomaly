extends SceneTree
const DOC="D:/无限异常/docs/kaidan-integration-011/"
const OUT="D:/无限异常/art/earth-production/kaidan-integration-011/captures/"
var checks=0
var failures=0
func _initialize() -> void:call_deferred("run")
func ck(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL "+label)
func run() -> void:
	root.size=Vector2i(1600,900)
	ck(ProjectSettings.get_setting("application/config/version")=="0.11.0-earth-kaidan","root launcher selects 0.11 release")
	ck(OS.get_executable_path().replace("\\","/").contains("builds/InfiniteAnomaly-Earth-0.11.0/"),"packaged executable launched by CMD")
	var scene=ProjectSettings.get_setting("application/run/main_scene")
	ck(scene=="res://scenes/earth/main.tscn","default entry is Earth game")
	var game=load(scene).instantiate();root.add_child(game)
	await process_frame;await process_frame;game.set_process(false)
	var tag="root-entry"
	if "--earth-stage01-preview" in OS.get_cmdline_user_args():
		tag="first-stage-entry"
		ck(game.stage01_preview and game.transient and game.view=="battle" and game.model.s.battle.stage==1,"old first-stage launcher and temporary state")
		for i in range(5):ck(game.buttons.has("preview_segment_%d"%i),"first-stage segment control")
	else:
		ck(game.view=="title" and game.buttons.has("start") and not game.kaidan_preview,"normal entry displays title")
	await process_frame;await RenderingServer.frame_post_draw
	var im=root.get_texture().get_image();im.save_png(OUT+tag+".png")
	var f=FileAccess.open(DOC+tag+".json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"executable":OS.get_executable_path(),"main_scene":scene,"view":game.view,"transient":game.transient,"preview":game.stage01_preview,"size":[im.get_width(),im.get_height()]} ,"  "));f.close()
	print("ACTUAL CMD ENTRY ",tag,": ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
