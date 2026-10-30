extends SceneTree
const Home=preload("res://scripts/pixel_home/home.gd")
const Hud=preload("res://scripts/pixel_hyakki/battle_hud.gd")
var home
var checks=[]
var out="res://docs/feedback-room-campaign-20261029/ui-verification/"
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
func click(button:Button)->void:
	await process_frame
	var point=button.get_global_rect().get_center();var motion=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;root.push_input(motion)
	var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=point;event.global_position=point;event.pressed=true;root.push_input(event)
	event=event.duplicate();event.pressed=false;root.push_input(event);await process_frame
func run()->void:
	home=Home.new();home.profile_override=ProjectSettings.globalize_path(out+"isolated-%d.json"%Time.get_ticks_usec());root.add_child(home)
	await process_frame;await process_frame;home.finish_intro();home.close_dialog();home.set_process(false);home.arrival=0
	var view=home.battle;var g=home.gear;var m=view.model;view.sound_enabled=false;view.set_process(false)
	home.open_campaign();await process_frame;await process_frame
	var menu=home.campaign_ui
	check(menu.entries.size()==20 and menu.frontier==1,"all twenty individual authored rooms visible from start")
	check(menu.cards.size()<=8 and menu.thumbnails.limit==16,"virtualized horizontal room cards bound texture memory")
	check(not menu.start.disabled and menu.selected==1,"first room launches directly")
	menu.choose(10);check(menu.start.disabled,"future preview cannot bypass progression")
	check(menu.title.text.contains(m.level_defs[9].title),"tenth picture has own title and identity")
	menu.choose(1);await shot("01-portal-selection")
	for id in range(1,21):g.home.seen_rooms.append(id)
	for difficulty in range(1,6):g.record_level_result(2,difficulty,10,0,50,true)
	menu.refresh();menu.choose(2);menu.set_depth(10);await shot("02-room-detail")
	check(menu.status.text.contains("5 / 10") and menu.plus.disabled,"badge and ten difficulty controls are real")
	check(menu.reward.text.contains("Lv.90") and not menu.active_card_ids.is_empty(),"live gear rating and actual available cards shown")
	menu.choose(20);menu.reveal_selection();await process_frame;menu.refresh_visible_cards()
	check(20 in menu.card_ids and menu.cards.size()<=8,"final individual room reachable without allocating all cards")
	menu.choose(1);menu.set_depth(1);await click(menu.start);view.set_process(false);view.paused=true
	check(home.mode=="battle" and m.phase=="fight" and m.chapter_id()==1,"portal launches room without old selector")
	check(not view.controls.has("start") and not view.controls.has("depth"),"legacy start selector absent")
	var xs=[]
	for key in ["pause","speed","auto_next","equipment","home"]:
		xs.append(view.controls[key].position.x);check(view.controls[key].get_theme_stylebox("normal") is StyleBoxEmpty,"icon has no background "+key)
	check(xs==[26.0,110.0,194.0,278.0,362.0],"all quick icons evenly spaced")
	for u in m.units:u.charge=.5
	var entries=Hud.timeline_layout(m);check(entries.all(func(entry):return is_equal_approx(entry.center,entry.anchor)),"portraits stay on real charge with overlap")
	check(is_equal_approx(entries[0].center,entries[1].center),"equal charge can overlap")
	m.units[0].charge=.9;m.units[1].charge=.2
	var first=Hud.timeline_layout(m).filter(func(entry):return entry.uid==0)[0];var second=Hud.timeline_layout(m).filter(func(entry):return entry.uid==1)[0]
	check(first.center>second.center,"faster actor overtakes independently")
	await shot("03-battle-hud")
	view.open_equipment();await click(view.equipment_ui.controls.organize);await process_frame
	var panel=view.equipment_ui.get_children().filter(func(child):return child.get_script()==preload("res://scripts/pixel_home/salvage_ui.gd"))[0]
	for i in range(4):g.award(10,0,0)
	panel.rebuild();panel.controls.quantity.value=2;var gold=g.s.gold;await click(panel.controls.batch)
	check(g.s.gold>gold and panel.message.contains("2件"),"quantity control and batch button execute actual salvage")
	panel.controls.auto.item_selected.emit(2);check(g.salvage_rules.auto_max_quality==1,"auto quality selection persisted from UI")
	await shot("04-equipment-salvage");panel.close();await process_frame;view.close_equipment()
	var picture=m.scene_info().image;clear_wave(m);view.advance_selected()
	check(m.scene_index()==1 and not view.travel.active and m.scene_info().image==picture,"no transition between waves")
	for wave in range(1,10):
		clear_wave(m)
		if wave<9:view.advance_selected()
	view.advance_selected();check(view.travel.active,"ten waves trigger departure effect")
	view.travel.elapsed=view.travel.duration*.2;await shot("05-departure")
	var elapsed=view.travel.elapsed;view.paused=true;view._process(.1);check(view.travel.elapsed==elapsed,"pause freezes portal effect")
	view.open_equipment();view._process(.1);check(view.travel.elapsed==elapsed,"equipment freezes portal effect");view.close_equipment()
	view.paused=false;view.speed=3;view._process(.05);check(is_equal_approx(view.travel.elapsed,elapsed+.05),"combat speed does not accelerate portal")
	view.travel.tick(view.travel.duration*.5-view.travel.elapsed)
	check(view.travel.switched and view.travel.cover_alpha()>.99 and m.chapter_id()==2,"one swap at opaque midpoint")
	view.travel.tick(view.travel.duration*.3);await shot("06-arrival")
	check(view.travel.image_path(m)==m.scene_info().image and view.travel.actor_alpha(0)>0,"arrival uses destination room directly")
	view.travel.tick(2);view.build_controls();view.paused=true
	m.phase="defeat";view.build_controls();await shot("07-defeat-inline")
	check(view.controls.has("retry") and view.controls.has("rooms") and not view.controls.has("again"),"old result and selector replaced with inline actions")
	await click(view.controls.retry);view.set_process(false);view.paused=true
	check(m.phase=="fight" and m.chapter_id()==2 and m.scene_index()==0,"retry starts same room immediately")
	m.phase="victory";view.build_controls();await shot("08-victory-inline")
	await click(view.controls.rooms);home.close_dialog();home.event_open=false;g.events.pending={};home._process(.01);await process_frame
	check(home.mode=="campaign" and home.campaign_ui.entries.size()==20,"record button returns through trip save to full screen portal menu")
	root.size=Vector2i(1280,720);await process_frame;await shot("09-selection-1280")
	check(home.campaign_ui.size==Vector2(1600,900),"full canvas portal layout preserves scaling at 1280x720")
	var failures=checks.filter(func(row):return not row.pass)
	var f=FileAccess.open(out+"verification.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures,"normal_profile_used":false},"\t"));f.close()
	print("FEEDBACK_ROOM_UI ",checks.size()," checks ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
