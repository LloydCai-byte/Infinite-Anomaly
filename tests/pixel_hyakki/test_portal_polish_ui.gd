extends SceneTree
const Home=preload("res://scripts/pixel_home/home.gd")
const Confirm=preload("res://scripts/pixel_home/salvage_confirm.gd")
const Campaign=preload("res://scripts/pixel_home/campaign.gd")
var home
var checks=[]
var out="res://docs/feedback-portal-polish-20261030/ui-verification/"
func check(ok:bool,label:String)->void:
	checks.append({"pass":ok,"name":label})
	if not ok:push_error(label)
func _initialize()->void:
	root.size=Vector2i(1600,900);root.content_scale_size=Vector2i(1600,900);DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out));call_deferred("run")
func shot(name:String)->void:
	if DisplayServer.get_name()=="headless":return
	home.queue_redraw();home.battle.queue_redraw();await process_frame;await process_frame;await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(out+name+".png")==OK,"capture "+name)
func mouse(point:Vector2,pressed:bool)->void:
	var motion=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;root.push_input(motion)
	var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=point;event.global_position=point;event.pressed=pressed;root.push_input(event)
	await process_frame
func click(button:Button)->void:
	await process_frame
	var point=button.get_global_rect().get_center();await mouse(point,true);await mouse(point,false);await process_frame
func drag(from:Vector2,to:Vector2)->void:
	await mouse(from,true)
	for i in range(1,7):
		var event=InputEventMouseMotion.new();event.position=from.lerp(to,float(i)/6);event.global_position=event.position;event.button_mask=MOUSE_BUTTON_MASK_LEFT;root.push_input(event);await process_frame
	await mouse(to,false);await process_frame
func modal():
	var panels=home.battle.equipment_ui.get_children().filter(func(child):return child.get_script()==Confirm)
	return panels[0] if not panels.is_empty() else null
func clear_wave(m)->void:
	for enemy in m.units.slice(5):m.damage(-1,enemy.uid,enemy.max_hp+100,"test")
	m.advance(.02)
func run()->void:
	home=Home.new();home.profile_override=ProjectSettings.globalize_path(out+"isolated-%d.json"%Time.get_ticks_usec());root.add_child(home)
	await process_frame;await process_frame;home.finish_intro();home.close_dialog();home.set_process(false);home.arrival=0
	var view=home.battle;var g=home.gear;var m=view.model;view.sound_enabled=false;view.set_process(false)
	home.open_campaign();await process_frame;await process_frame;var menu=home.campaign_ui
	check(menu.groups==[0] and menu.all_entries.size()==20,"fresh save hides later range tabs and keeps twenty authored rooms")
	menu.choose(2);check(menu.start.disabled,"unreached room cannot launch from preview")
	menu.choose(1);var selected=menu.selected
	await drag(menu.scroll.global_position+Vector2(750,60),menu.scroll.global_position+Vector2(250,60))
	check(menu.scroll.scroll_horizontal>200 and menu.selected==selected,"mouse dragging scrolls room cards without selecting or launching")
	check(menu.cards.size()<=8 and menu.thumbnails.textures.size()<=16,"drag keeps bounded card and texture caches")
	menu.scroll.scroll_horizontal=0;await process_frame;menu.refresh_visible_cards()
	await click(menu.cards[1]);check(menu.selected==2,"room remains clickable after a drag")
	g.home.seen_rooms=[1,2];menu.refresh();menu.choose(2);menu.set_depth(2);await shot("01-single-door-live")
	menu.choose(1);menu.set_depth(1);await click(menu.start);view.set_process(false);view.paused=true
	check(home.mode=="battle" and m.phase=="fight","real mouse launches selected room")
	print("LAUNCH_STATE ",home.mode," ",m.phase," arrival=",view.enemy_arrival.active," selected=",view.selected_depth)
	check(view.enemy_arrival.active and view.enemy_arrival.alpha(1)<.01,"enemy wave begins with hidden monsters")
	var battle_time=m.time;var elapsed=view.enemy_arrival.elapsed;view._process(.1)
	check(view.enemy_arrival.elapsed==elapsed and m.time==battle_time,"pause holds arrival and combat")
	view.open_equipment();view._process(.1);check(view.enemy_arrival.elapsed==elapsed,"equipment freezes arrival")
	var ui=view.equipment_ui
	check(not ui.controls.has("view_list") and not ui.controls.has("view_grid"),"obsolete list switch has no live hit targets")
	var item=g.s.inventory.filter(func(entry):return g.owner(entry.id)<0 and not entry.get("locked",false))[0]
	ui.choose(item.id);var count=g.s.inventory.size();var gold=g.s.gold
	await click(ui.controls.salvage);var confirmation=modal()
	check(confirmation!=null and confirmation.plan.ids==[item.id],"single salvage opens exact one-item confirmation")
	print("SALVAGE_STATE ",modal()," selected=",ui.selected," wanted=",item.id," disabled=",ui.controls.salvage.disabled," children=",ui.get_child_count())
	check(g.s.inventory.size()==count and g.s.gold==gold,"opening confirmation performs no salvage")
	if confirmation!=null:
		await shot("02-salvage-one");await click(confirmation.controls.cancel);check(g.s.inventory.size()==count,"cancel keeps inventory")
	await click(ui.controls.organize);await process_frame
	var panel=ui.get_children().filter(func(child):return child.get_script()==preload("res://scripts/pixel_home/salvage_ui.gd"))[0]
	var q=int(item.quality);panel.quality=q;panel.rebuild();panel.controls.quantity.value=2
	var planned=g.salvage_plan(q,2);count=g.s.inventory.size();gold=g.s.gold
	await click(panel.controls.batch);confirmation=modal()
	check(confirmation!=null and confirmation.plan.ids==planned.ids and g.s.inventory.size()==count,"batch confirmation snapshots chosen quantity before mutation")
	if confirmation!=null:
		await shot("03-salvage-quantity");await click(confirmation.controls.confirm)
	check(g.s.inventory.size()==count-planned.ids.size() and g.s.gold==gold+planned.gold,"confirmed batch removes exact preview and grants exact gold")
	panel.close();await process_frame;await shot("04-floating-equipment");view.close_equipment();view.set_process(false)
	view.paused=false;view.speed=3;elapsed=view.enemy_arrival.elapsed;view._process(.1)
	check(is_equal_approx(view.enemy_arrival.elapsed,elapsed+.1) and m.time==battle_time,"arrival uses real time and holds ATB at triple speed")
	view.enemy_arrival.elapsed=.35;view.paused=true;await shot("05-enemy-arrival")
	view.enemy_arrival.tick(1);view.paused=false;view._process(.05);check(m.time>battle_time,"combat resumes after monsters finish arriving")
	clear_wave(m);m.units[0].hp-=20;m.units[0].charge=.57;m.shields[0]=9
	var hp=m.units[0].hp;var picture=m.scene_info().image;view.advance_selected()
	check(view.enemy_arrival.active and not view.travel.active and m.scene_info().image==picture,"next wave teleports enemies on same map")
	check(m.units[0].hp==hp and is_equal_approx(m.units[0].charge,.57) and m.shields[0]==9,"enemy arrival preserves party wave health charge and shield")
	view.enemy_arrival.active=false;view.paused=true;m.phase="defeat";view.build_controls();await shot("06-defeat")
	await click(view.controls.retry);view.set_process(false);view.paused=true
	check(m.phase=="fight" and m.scene_index()==0 and view.enemy_arrival.active,"styled retry returns to first wave with arrival")
	# A test-only large catalog exercises boundaries; no new production art or save data.
	home.mode="home";home.close_dialog();var source=m.level_defs.duplicate(true);var definitions=[]
	for id in range(1,2001):
		var level=source[(id-1)%source.size()].duplicate(true);level.id=id;level.campaign_id=id;level.room_id=id;level.title="测试房间 %04d"%id;level.test_only=true;definitions.append(level)
	m.configure_levels(definitions);g.home.seen_rooms=range(1,51);home.open_campaign();await process_frame;await process_frame;menu=home.campaign_ui
	check(menu.groups==[0],"reaching room 50 alone does not reveal second range")
	g.home.seen_rooms.append(51);menu.refresh();await process_frame;await process_frame
	check(menu.groups==[0,1],"reaching room 51 reveals second range")
	menu.set_group(1);await process_frame;await process_frame
	check(menu.entries[0]==51 and menu.entries[-1]==100,"50~100 label maps to distinct rooms 51 through 100")
	g.home.seen_rooms=range(1,302);menu.refresh();await process_frame;await process_frame
	menu.set_group(0);await process_frame;await process_frame
	var group_index=menu.group_ids.find(5);await click(menu.group_buttons[group_index]);await process_frame;await process_frame
	check(menu.current_group==5 and menu.entries[0]==251 and menu.selected==251,"click 250~300 switches thumbnails to its own first room")
	check(absf(menu.group_scroll.scroll_horizontal-menu.groups.find(5)*menu.GROUP_WIDTH)<=1,"selected range shifts to left edge")
	check(menu.group_buttons.size()<=10 and menu.cards.size()<=8,"range switching does not allocate the whole catalog")
	await shot("07-range-switch-test-fixture")
	var state=Campaign.initial()
	for d in range(1,11):Campaign.apply_result(state,1,d,10,0,1,true)
	for id in range(1,1001):g.campaign.levels[Campaign.key(id)]=state.levels.R0001.duplicate(true)
	g.campaign.phase="cosmos";g.campaign.graduation_seen=true;g.home.seen_rooms=range(1,2001);menu.refresh();menu.choose(2000);menu.reveal_selection();await process_frame;await process_frame;menu.refresh_visible_cards()
	check(menu.selected==2000 and 2000 in menu.card_ids and menu.groups.size()==40,"all 2000 test rooms reachable in forty groups")
	check(menu.portals.textures.size()<=3 and menu.thumbnails.textures.size()<=16,"full catalog preserves bounded image memory")
	root.size=Vector2i(1280,720);await process_frame;await shot("08-layout-1280-test-fixture")
	var failures=checks.filter(func(row):return not row.pass);var file=FileAccess.open(out+"verification.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"normal_profile_used":false,"source_revision":225},"\t"));file.close()
	print("PORTAL_POLISH_UI ",checks.size()," checks ",failures.size()," failures");quit(0 if failures.is_empty() else 1)

