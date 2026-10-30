extends SceneTree
const Home=preload("res://scripts/pixel_home/home.gd")
const Campaign=preload("res://scripts/pixel_home/campaign.gd")
const ChapterHud=preload("res://scripts/pixel_hyakki/chapter_hud.gd")
var home
var checks=[]
var out="res://docs/room-campaign-2000-20261029/ui-verification/"
func check(ok:bool,label:String)->void:
	checks.append({"pass":ok,"name":label})
	if not ok:push_error(label)
func _initialize()->void:
	root.size=Vector2i(1600,900);root.content_scale_size=Vector2i(1600,900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out));call_deferred("run")
func shot(name:String)->void:
	if DisplayServer.get_name()=="headless":return
	home.queue_redraw();home.battle.queue_redraw();await process_frame;await process_frame;await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(out+name+".png")==OK,"capture "+name)
func clear_wave(m)->void:
	for enemy in m.units.slice(5):m.damage(-1,enemy.uid,enemy.max_hp+100,"test")
	m.advance(.02)
func run()->void:
	home=Home.new();home.profile_override=ProjectSettings.globalize_path(out+"isolated-%d.json"%Time.get_ticks_usec());root.add_child(home)
	await process_frame;await process_frame;home.finish_intro();home.close_dialog();home.set_process(false);home.arrival=0
	var view=home.battle;var g=home.gear;var m=view.model;view.sound_enabled=false;view.set_process(false)
	check(m.level_defs.size()==20 and m.scene_count()==10,"home loads twenty ten-wave rooms")
	home.open_campaign();await process_frame
	var menu=home.campaign_ui
	check(menu.entries.is_empty() and menu.frontier==1 and menu.new_mission.visible,"fresh selection only offers first new room")
	menu.launch_new();view.set_process(false);view.paused=true
	check(home.mode=="battle" and m.chapter_id()==1 and m.phase=="fight","new mission launches room one")
	check(g.home.seen_rooms==[1],"first room encounter recorded")
	var image=m.scene_info().image;var clock=m.time
	view._process(.5);check(m.time==clock and not view.travel.active,"pause freezes battle and wave advance")
	check(ChapterHud.theme({"chapter":1})==ChapterHud.theme({"chapter":1001}),"all themes use same generic progress")
	var header=view.travel.header(m)
	check(header.room and header.count==10 and header.index==0 and header.enemies==5 and header.difficulty==1,"HUD derives real room wave enemy count and difficulty")
	await shot("01-room-wave-one")
	clear_wave(m);view.advance_selected()
	check(m.scene_index()==1 and not view.travel.active and m.scene_info().image==image,"view advances wave without teleport or image swap")
	view.growth_ui.tab=2;view.open_growth()
	check(not view.growth_ui.editable(),"skill and card changes locked inside ten-wave run")
	await shot("02-room-records");view.close_growth()
	for i in range(1,10):
		clear_wave(m)
		if i<9:view.advance_selected()
	check(g.campaign.levels.has("R0001") and m.scene_index()==9,"real UI route saves complete room")
	view.advance_selected();check(view.travel.active,"tenth wave starts room teleport")
	view.paused=true;var elapsed=view.travel.elapsed;view._process(.3)
	check(view.travel.elapsed==elapsed and m.chapter_id()==1,"paused teleport cannot switch room")
	view.paused=false;view.speed=3
	for i in range(2):view._process(.10)
	check(view.travel.active and not view.travel.switched and is_equal_approx(view.travel.elapsed,.20),"combat speed does not accelerate blackout")
	for i in range(2):view._process(.10)
	check(m.chapter_id()==2 and m.scene_info().image!=image,"next picture switches once under black")
	for i in range(4):view._process(.10)
	check(not view.travel.active and m.phase=="fight","new room resumes combat after fade")
	view.paused=true;await shot("03-next-room")
	home.return_home();home.finish_return();home.close_dialog();home.event_open=false;g.events=g.Events.initial(10);home.arrival=0
	# Badge examples are isolated UI fixtures, never normal player achievements.
	for id in [1,2,3]:
		for difficulty in range(1,4 if id==1 else 6 if id==2 else 11):g.record_level_result(id,difficulty,10,0,60.0,true)
	g.home.seen_rooms=[1,2,3]
	home.open_campaign();await process_frame;menu=home.campaign_ui
	check(menu.entries==[1,2,3] and menu.cards.size()==3,"selection contains only visited rooms")
	check(menu.shimmer_badges.size()==1,"only ten-difficulty room has shimmer animation")
	menu.choose(2);menu.set_depth(10)
	check(menu.depth_value==10 and menu.plus.disabled and not menu.minus.disabled,"difficulty selection capped at ten")
	check(menu.detail.text.contains("金标") and menu.detail.text.contains("5/10") and not menu.detail.text.contains("无人倒下"),"detail shows distinct difficulty badge rule")
	check(menu.frontier==4 and menu.new_mission.visible,"new mission follows next uncleared room")
	check(menu.cards[0].get_node("FirstScene").get_meta("source")==m.level_defs[0].scenes[0].image and menu.cards[0].get_node("FirstScene").texture.get_width()<=400,"room thumbnail matches source with bounded resolution")
	await shot("04-badges-and-selection")
	home.close_campaign();home.open_overlay("equipment")
	check(view.equipment_ui.skin.texture.get_size()==Vector2(1774,887),"equipment reference skin preserved")
	await shot("05-equipment-preserved")
	view.close_equipment();home._process(0)
	check(home.life.atlas.xuan.frames.size()==36 and home.current_room=="living","latest Xuan motion and home retained")
	var failures=checks.filter(func(entry):return not entry.pass)
	var file=FileAccess.open(out+"verification.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"normal_profile_used":false,"badge_screenshot_is_fixture":true},"\t"));file.close()
	print("ROOM_UI %d checks %d failures"%[checks.size(),failures.size()]);home.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
