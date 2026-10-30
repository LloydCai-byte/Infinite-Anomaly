extends SceneTree
const Home = preload("res://scripts/pixel_home/home.gd")
const Covers = preload("res://scripts/pixel_home/room_covers.gd")
var home
var checks: Array = []
var out = "res://docs/room-covers-first10-20261030/runtime/"
func check(ok: bool, name: String) -> void:
	checks.append({"pass":ok,"name":name})
	if not ok:push_error(name)
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cover-output="):out = arg.trim_prefix("--cover-output=").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	root.size = Vector2i(1600,900)
	root.content_scale_size = Vector2i(1600,900)
	call_deferred("run")
func shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":return
	home.queue_redraw()
	home.battle.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(out+name+".png") == OK,"capture "+name)
func run() -> void:
	home = Home.new()
	home.profile_override = ProjectSettings.globalize_path(out+"isolated-%d.json" % Time.get_ticks_usec())
	root.add_child(home)
	await process_frame
	await process_frame
	home.finish_intro()
	home.close_dialog()
	home.set_process(false)
	home.arrival = 0
	home.battle.set_process(false)
	home.battle.sound_enabled = false
	var levels = home.battle.model.level_defs
	var before = levels.duplicate(true)
	home.open_campaign()
	await process_frame
	await process_frame
	var menu = home.campaign_ui
	check(menu.covers.rooms.size() == 10,"ten explicit room cover pairs loaded")
	check(menu.all_entries.size() == 20 and menu.groups == [0],"cover catalog does not expose new rooms or ranges")
	menu.choose(10)
	check(menu.start.disabled,"unreached covered room remains locked on fresh save")
	home.gear.home.seen_rooms = range(1,11)
	menu.refresh()
	await process_frame
	await process_frame
	var unique: Dictionary = {}
	for id in range(1,11):
		var level = levels[menu.content_index(id)]
		var paths: Dictionary = {}
		for kind in ["portrait","landscape"]:
			var path: String = menu.covers.path_for(id,level.scenes[0].image,kind)
			check(path != level.scenes[0].image and not unique.has(path),"R%04d %s independent asset" % [id,kind])
			unique[path] = true
			var img = Image.load_from_file(path)
			check(img != null,"R%04d %s packaged image decodes" % [id,kind])
			if img == null:continue
			var aspect = float(img.get_width()) / img.get_height()
			check(absf(aspect - (.6 if kind == "portrait" else 16.0/9.0)) < .025,"R%04d %s cover aspect" % [id,kind])
			paths[kind] = path
		menu.choose(id)
		menu.reveal_selection()
		await process_frame
		await process_frame
		menu.refresh_visible_cards()
		var index: int = menu.card_ids.find(id)
		check(index >= 0 and menu.cards[index].get_node("FirstScene").get_meta("source") == paths.landscape,"R%04d thumbnail switches to wide cover" % id)
		var texture = menu.portals.get_texture(paths.portrait)
		var target: Rect2 = menu.r(529,105,286,481)
		var crop: Rect2 = Covers.source_rect(texture.get_size(),target.size)
		check(crop.position.x >= 0 and crop.position.y >= 0 and crop.end.x <= texture.get_width()+.01 and crop.end.y <= texture.get_height()+.01 and absf(crop.size.x/crop.size.y-target.size.x/target.size.y)<.001,"R%04d portrait aspect-preserving crop inside image" % id)
		check(menu.start.disabled == false,"R%04d reached room retains launch" % id)
		await shot("room-%02d" % id)
	var fallback: String = levels[menu.content_index(11)].scenes[0].image
	check(menu.covers.path_for(11,fallback,"portrait") == fallback and menu.covers.path_for(11,fallback,"landscape") == fallback,"room eleven keeps existing art")
	check(menu.covers.path_for(1,fallback,"portrait") == fallback,"mismatched content identity never receives another room cover")
	var temporarily_missing = menu.covers.rooms.R0001.erase("portrait")
	check(temporarily_missing and menu.covers.path_for(1,levels[0].scenes[0].image,"portrait") == levels[0].scenes[0].image,"missing cover falls back to original scene")
	menu.covers = Covers.new()
	for cycle in range(3):
		for id in range(20,0,-1):
			menu.choose(id)
			menu.reveal_selection()
			await process_frame
			menu.refresh_visible_cards()
			menu.portals.get_texture(menu.covers.path_for(id,levels[menu.content_index(id)].scenes[0].image,"portrait"))
	check(menu.cards.size() <= 8 and menu.portals.textures.size() <= 3 and menu.thumbnails.textures.size() <= 16,"repeated scrolling keeps bounded cards and caches")
	check(levels == before,"selection never alters battle images or room definitions")
	menu.choose(1)
	menu.reveal_selection()
	root.size = Vector2i(1280,720)
	await shot("room-01-1280")
	menu.launch()
	home.battle.set_process(false)
	check(home.mode == "battle" and home.battle.model.scene_info().image == before[0].scenes[0].image,"launch uses original battle background")
	var failures = checks.filter(func(row):return not row.pass)
	var file = FileAccess.open(out+"verification.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"normal_profile_used":false,"unique_images":unique.size()},"\t"))
	file.close()
	print("ROOM_COVERS ",checks.size()," checks ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
