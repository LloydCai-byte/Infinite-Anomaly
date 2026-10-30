extends SceneTree
const Home=preload("res://scripts/pixel_home/home.gd")
const Campaign=preload("res://scripts/pixel_home/campaign.gd")
var checks=[]
var home
var out="res://docs/room-campaign-2000-20261029/scale-verification/"
func check(ok:bool,label:String)->void:
	checks.append({"pass":ok,"name":label})
	if not ok:push_error(label)
func _initialize()->void:
	root.size=Vector2i(1600,900);root.content_scale_size=Vector2i(1600,900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out));call_deferred("run")
func run()->void:
	home=Home.new();home.profile_override=ProjectSettings.globalize_path(out+"fixture-%d.json"%Time.get_ticks_usec());root.add_child(home)
	await process_frame;await process_frame;home.finish_intro();home.close_dialog();home.set_process(false)
	var g=home.gear;var m=home.battle.model;home.battle.set_process(false);var source=m.level_defs.duplicate(true)
	var definitions=[]
	for id in range(1,2001):
		var level=source[(id-1)%source.size()].duplicate(true)
		level.id=id;level.campaign_id=id;level.room_id=id;level.title="规模测试房间 %04d"%id;level.test_only=true
		definitions.append(level)
	var start=Time.get_ticks_usec();m.configure_levels(definitions)
	var configure_ms=(Time.get_ticks_usec()-start)/1000.0
	var correct=true;start=Time.get_ticks_usec()
	for stage in range(20000):
		correct=correct and m.level_index(stage)==int(stage/10) and m.level_offset(int(stage/10))==int(stage/10)*10
	var lookup_ms=(Time.get_ticks_usec()-start)/1000.0
	check(correct and m.stage_count()==20000,"all twenty thousand wave offsets resolve to correct room")
	# Unlock fixture uses actual rule masks; no manufactured content is registered.
	var sample=Campaign.initial()
	for d in range(1,11):Campaign.apply_result(sample,1,d,10,0,1.0,true)
	for id in range(1,1001):g.campaign.levels[Campaign.key(id)]=sample.levels.R0001.duplicate(true)
	g.campaign.phase="cosmos";g.campaign.graduation_seen=true;g.campaign.story_seen=["graduation"];g.Cosmos.unlock(g.cosmos)
	while g.story_waiting():
		g.prepare_story();g.complete_story(g.narrative.pending.id)
	g.home.seen_rooms=range(1,2001)
	start=Time.get_ticks_usec();home.open_campaign();var menu=home.campaign_ui
	await process_frame;await process_frame
	var open_ms=(Time.get_ticks_usec()-start)/1000.0
	check(menu.entries.size()==2000 and menu.cards.size()<=12,"two thousand encountered rooms use at most twelve live cards")
	check(menu.grid.get_child_count()==menu.cards.size(),"offscreen room cards are not allocated")
	check(menu.cards[0].get_node("FirstScene").texture!=null,"visible room thumbnail loads")
	var max_cards=0;var max_thumbnails=0;var max_bytes=0
	for fraction in [0.0,.1,.3,.5,.7,.9,1.0,.4,0.0]:
		menu.scroll.scroll_vertical=roundi((menu.scroll.get_v_scroll_bar().max_value-menu.scroll.get_v_scroll_bar().page)*fraction)
		for frame in range(7):await process_frame
		max_cards=maxi(max_cards,menu.cards.size());max_thumbnails=maxi(max_thumbnails,menu.thumbnails.textures.size());max_bytes=maxi(max_bytes,menu.thumbnails.resident_bytes)
		check(menu.cards.size()<=12 and menu.thumbnails.textures.size()<=16,"scroll keeps bounded cards and image cache at "+str(fraction))
		for card in menu.cards:
			var image=card.get_node("FirstScene")
			check(image.texture!=null and image.texture.get_width()<=400 and image.texture.get_height()<=400,"live thumbnail decoded at bounded resolution")
		if fraction==1.0:check(2000 in menu.card_ids,"last room is reachable by normal scroll range")
	menu.scroll.scroll_vertical=int(menu.scroll.get_v_scroll_bar().max_value);await process_frame
	menu.choose(2000);check(menu.selected==2000 and menu.detail.text.contains("2000") and not menu.start.disabled,"last room can be selected and launched")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(out+"last-room.png")==OK,"render last-room scroll fixture")
	for definition in source:
		home.battle.backgrounds.get_texture(definition.scenes[0].image)
		check(home.battle.backgrounds.textures.size()<=3,"background cache evicts old full-size images")
	check(home.battle.backgrounds.resident_bytes<24*1024*1024,"full-size room cache remains below 24 MiB with current source images")
	check(max_bytes<=16*400*400*4,"thumbnail texture budget is independent of room count")
	var first=source[0].scenes[0].image;var texture=home.battle.backgrounds.get_texture(first)
	check(texture!=null and home.battle.backgrounds.has(first),"evicted background reloads when revisiting a room")
	var failures=checks.filter(func(row):return not row.pass)
	var report={"checks":checks,"failures":failures,"normal_profile_used":false,"test_only_definitions":2000,"real_image_sources":source.size(),"configure_ms":configure_ms,"lookup_20000_ms":lookup_ms,"open_ms_including_two_frames":open_ms,"max_live_cards":max_cards,"max_thumbnail_count":max_thumbnails,"max_thumbnail_bytes":max_bytes,"background_bytes":home.battle.backgrounds.resident_bytes}
	var file=FileAccess.open(out+"verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("ROOM_SCALE ",checks.size()," checks ",failures.size()," failures; timings ",configure_ms," / ",lookup_ms," / ",open_ms)
	home.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
