extends SceneTree
var failures=0
func ck(ok: bool,label: String) -> void:
	if not ok:failures+=1;printerr("FAIL "+label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	ck(ProjectSettings.get_setting("application/config/version")=="0.11.0-earth-kaidan","package version")
	var game=load("res://scenes/earth/main.tscn").instantiate()
	root.add_child(game);game.transient=true
	await process_frame
	ck(game.buttons.has("start") and game.shots.size()==31,"pack title and opening")
	game.new_game(1);game.finish_intro();game.deploy(1);game.set_process(false)
	for role in range(5):
		var path=game.battlefield.actor_path(role,1)
		ck(path.ends_with("temp-test/sprite_frames.tres"),"temporary person packed")
		var frames=load(path) as SpriteFrames
		ck(frames.get_frame_count("move")==8 and frames.get_frame_texture("move",7)!=null,"packed animation dependencies")
	ck(is_equal_approx(game.battlefield.street_width(),10730.0*900/724),"packed continuous panorama")
	if "--capture" in OS.get_cmdline_user_args():
		root.size=Vector2i(1920,1080)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("D:/无限异常/art/earth-production/kaidan-integration-011/captures/package-first-stage.png")
	for i in range(60*120):game.model.tick(1.0/60)
	ck(game.model.s.result.get("reason","")=="victory","packed battle victory")
	game.navigate("result")
	ck(game.buttons.has("return"),"result UI")
	ck(game.buttons.has("continue_next") and not game.buttons.continue_next.disabled,"continue battle in packaged UI")
	ck(game.model.s.inventory.size()==1 and game.model.s.result.loot.size()==1,"new loot system packed")
	game.open_equipment("result")
	game.model.equip_item(1,game.loot_selected)
	game.draw_view()
	ck(game.model.gear_spirits().size()==1,"packed equipped familiar")
	ck(ResourceLoader.exists("res://scenes/reboot/main.tscn"),"legacy entry retained")
	ck(FileAccess.file_exists("res://assets/earth/asset_registry.json"),"replacement manifest packed")
	var assets=load("res://scripts/earth/assets.gd")
	ck(assets.path("menu")=="res://assets/earth/replacements/menu.png","new cel menu actually selected")
	ck(assets.texture("opening.03").get_size()==Vector2(1920,1080),"guide-redrawn master in release")
	for person in ["dadong","fenfen","gao","wang","qiqi","xuan","antagonist"]:
		ck(assets.texture("portrait."+person) is AtlasTexture,"latest portrait dependencies packed "+person)
	for room in ["living","workroom","kitchen","bathroom","bedroom","balcony","corridor"]:
		ck(ResourceLoader.exists("res://assets/earth/home/"+room+".png"),"room packed "+room)
	for i in range(6):ck(assets.texture("equipment."+str(i))!=null,"inventory icon packed "+str(i))
	ck(not FileAccess.file_exists("res://art/earth-production/motion/fenfen-t1-request.json"),"private production request excluded")
	game.model.close_result();game.navigate("base")
	game.change_room("workroom",true)
	ck(game.model.s.home.room=="workroom" and game.buttons.has("printer"),"packed home interaction")
	ck(not game.buttons.has("collection") and not game.buttons.has("map"),"removed UI entries absent from release")
	if "--capture" in OS.get_cmdline_user_args():
		game.change_room("living",true);game.selected_stage=1;game.navigate("missions")
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("D:/无限异常/art/earth-production/kaidan-integration-011/captures/package-portal-original.png")
	var report=FileAccess.open("D:/无限异常/docs/kaidan-integration-011/package-regression.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"version":ProjectSettings.get_setting("application/config/version"),"failures":failures,"packaged_assets":true},"  "));report.close()
	print("EARTH RELEASE PACKAGE: ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
