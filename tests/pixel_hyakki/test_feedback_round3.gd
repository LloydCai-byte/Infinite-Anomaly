extends SceneTree
const Home=preload("res://scripts/pixel_home/home.gd")
const Gear=preload("res://scripts/pixel_home/gear.gd")
var out="res://docs/feedback-round3-20261028/verification/"
var checks=[]
var home
func _initialize() -> void:
	root.size=Vector2i(1600,900);root.content_scale_size=Vector2i(1600,900)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--feedback-test-output="):out=arg.trim_prefix("--feedback-test-output=").trim_suffix("/")+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out));call_deferred("run")
func check(ok:bool,label:String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
func shot(name:String) -> void:
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out+name+".png")
func click(control:Control) -> void:
	var point=control.get_global_rect().get_center()
	var motion=InputEventMouseMotion.new();motion.position=point;root.push_input(motion)
	var event=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;root.push_input(event)
	event=event.duplicate();event.pressed=false;root.push_input(event);await process_frame
func visible_text(node:Node) -> String:
	var result=""
	if node is Control and not node.is_visible_in_tree():return result
	if node is Label or node is Button:result+=node.text+"\n"
	for child in node.get_children():result+=visible_text(child)
	return result
func run() -> void:
	home=Home.new();root.add_child(home);await process_frame;await process_frame
	home.finish_intro();home.close_dialog();home.arrival=0
	var g=home.gear;var view=home.battle;var defs=view.model.level_defs.duplicate(true)
	check(view.profile_path.contains("feedback-round3-20261028"),"isolated profile is explicit")
	check(g.encountered_levels(defs).is_empty(),"fresh profile has no imaginary visited chapters")
	home.open_campaign();await process_frame;var menu=home.campaign_ui
	check(menu.entries.is_empty() and menu.frontier==1 and menu.new_mission.visible,"fresh player has a first expedition without a future catalogue")
	check(not visible_text(menu).contains("星球") and not visible_text(menu).contains("300") and not visible_text(menu).contains("周目"),"selection contains no future chapter totals or cycle spoilers")
	await shot("01-fresh-selection")
	await click(menu.new_mission);view.paused=true;view.build_controls()
	check(home.mode=="battle" and view.model.phase=="fight" and g.encountered_levels(defs)==[1],"mouse first expedition starts actual battle and records only reached chapter")
	check(view.hud_skin.plate.get_size()==Vector2(1536,1024) and view.hud_skin.icons.get_size()==Vector2(1536,1024),"generated pixel atlases decoded at original size")
	for id in ["pause","speed","auto_next","equipment","home"]:
		check(view.controls.has(id) and view.controls[id].position.y==124,"toolbar under chapter: "+id)
	check(view.controls.pause.text=="" and view.controls.equipment.text=="" and view.controls.home.text=="","toolbar uses image icons without button captions")
	await shot("02-battle-hud")
	await click(view.controls.speed);check(view.speed==2 and view.controls.speed.text=="× 2.0","speed icon button changes actual speed and label")
	await click(view.controls.auto_next);check(not view.auto_next,"automatic progression toggles by mouse")
	await click(view.controls.pause);check(not view.paused,"play icon resumes battle")
	await click(view.controls.pause);check(view.paused,"pause icon stops battle")
	await click(view.controls.equipment);check(view.screen=="equipment","backpack image opens real equipment")
	check(view.equipment_ui.skin.texture.get_size()==Vector2(1774,887) and view.equipment_ui.page_size()==35,"equipment retains exact reference atlas and 35 functional slots")
	await shot("03-equipment-reference");view.close_equipment()
	var item=g.award(5,0,2,56);var drag=view.equipment_ui.drag;var slot=view.equipment_ui.slot_rect(view.equipment_ui.G.SLOTS.find("ring_b"))
	check(drag.slot_at(slot.get_center()+Vector2(slot.size.x*.5+14,0),item.id)=="","14px outside no longer snaps")
	check(drag.slot_at(slot.get_center()+Vector2(slot.size.x*.5+3,0),item.id)=="ring_b","3px beside correct slot snaps")
	view.notices.clear();view.notices.push("获得 戒指",item);view.notices.push("河童观察 +1")
	view.set_process(false);var before=view.notices.entries.duplicate(true);view._process(.1)
	check(view.notices.entries==before,"paused battle freezes notice duration")
	view.open_equipment();view._process(.1);check(view.notices.entries==before,"equipment overlay freezes notice duration");view.close_equipment()
	await shot("04-loot-and-observation")
	view.notices.tick(1.5);check(view.notices.entries.size()==2 and view.notices.offset(view.notices.entries[0])==0,"both notices stay beneath action rail during hold")
	view.notices.tick(.35);check(view.notices.offset(view.notices.entries[0])>0,"notices exit toward right")
	await shot("05-notices-slide-right")
	view.notices.tick(.16);check(view.notices.entries.is_empty(),"notices are removed after two seconds")
	view.notices.push("观察 +1");view.notices.push("观察 +2");view.notices.push("观察 +3");view.notices.push("观察 +4")
	view.notices.tick(2.01);check(view.notices.entries.size()==1 and view.notices.entries[0].age==0,"queued overflow gets its own full display duration");view.notices.clear()
	await click(view.controls.home);check(home.mode=="retreat","room icon opens existing retreat confirmation")
	home.finish_return();home.close_dialog();home.arrival=0;g.events=Gear.Events.initial(714);home.event_open=false
	home.open_campaign();await process_frame;menu=home.campaign_ui
	check(menu.entries==[1] and menu.cards.size()==1 and not menu.new_mission.visible,"only actually reached chapter appears after retreat")
	check(menu.cards[0].get_node("FirstScene").texture==view.texture(defs[0].scenes[0].image),"selection card uses the chapter's first scene image")
	check(menu.cards[0].get_node("FirstScene").size==Vector2(400,222),"thumbnail keeps intended card size without expanding to native scene resolution")
	check(menu.start.text=="消灭异常" and menu.minus.disabled,"requested action wording and strength lower bound")
	check(menu.detail.text.contains("五人小队连续挑战10景。"),"existing chapter description retained")
	await shot("06-visited-selection")
	var initial=g.snapshot();var original_defs=view.model.level_defs.duplicate(true)
	# Synthetic entries are isolated UI fixtures, never a production content claim.
	var many=[];g.home.seen_levels=[]
	for id in range(1,15):
		var level=defs[(id-1)%2].duplicate(true);level.id=id;level.campaign_id=id;level.title="滚动测试 %02d"%id;many.append(level);g.home.seen_levels.append(id)
	view.model.level_defs=many;menu.refresh();await process_frame;await process_frame
	var wheel=InputEventMouseButton.new();wheel.position=Vector2(500,500);wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN;wheel.pressed=true
	for i in range(10):root.push_input(wheel);await process_frame
	check(menu.scroll.scroll_vertical>0 and menu.cards.size()==14,"mouse wheel scrolls a growing list continuously without pagination")
	await shot("07-scroll-fixture-only")
	view.model.level_defs=original_defs;g.restore(initial);home.close_campaign();await process_frame
	home.change_room("bathroom",home.Rooms.data("bathroom").spawn);home.arrival=0;await shot("08-bathroom")
	check(home.Rooms.image_path("bathroom").contains("feedback-round3") and home.Rooms.image_path("living").contains("feedback-round2"),"only bathroom plate replaced; approved living room retained")
	home.work_menu();var text=visible_text(home.dialog)
	check(not text.contains("星际") and not text.contains("轮回") and not text.contains("共鸣"),"early workroom exposes no future systems")
	home.close_dialog();home.open_cosmos();check(home.mode=="home" and not home.dialog.visible,"locked cosmic shortcut cannot leak future text")
	home.story_journal();check(not home.dialog_text.text.contains("星球") and not home.dialog_text.text.contains("地球考验"),"empty journal does not reveal future campaign")
	home.close_dialog();var legacy=initial.duplicate(true);legacy.home.erase("seen_levels");legacy.growth.scenes={"sleepbeast:test-scene":{"clears":1,"best_depth":1}}
	var migration=Gear.new(73);check(migration.restore(legacy) and 2 in migration.encountered_levels(defs),"legacy scene receipts migrate visited state without enumerating future stages")
	var bad=initial.duplicate(true);bad.home.seen_levels=[1,1];check(not migration.restore(bad),"duplicate discovery entries rejected")
	bad=initial.duplicate(true);bad.home.seen_levels=[601];check(not migration.restore(bad),"out of range discovery rejected")
	g.restore(initial);g.persist();var disk=Gear.new(7);disk.open_profile(view.profile_path)
	check(disk.encountered_levels(defs)==[1] and disk.s.inventory==g.s.inventory,"visited state and existing inventory survive reload")
	var failed=checks.filter(func(c):return not c.pass)
	var file=FileAccess.open(out+"verification.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failed":failed.size(),"normal_save_used":false},"  "));file.close()
	print("FEEDBACK_ROUND3 ",checks.size()," checks, ",failed.size()," failures")
	home.queue_free();await process_frame;quit(0 if failed.is_empty() else 1)
