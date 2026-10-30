extends SceneTree
const View=preload("res://scripts/pixel_hyakki/view.gd")
const Gear=preload("res://scripts/pixel_hyakki/progression/gear.gd")
var v
var checks=[]
var out="res://docs/progression-research-20261026/ui-captures/"
var report="res://docs/progression-research-20261026/runtime-ui-verification.json"
func _initialize()->void:call_deferred("run")
func check(ok:bool,title:String)->void:
	checks.append({"pass":ok,"name":title})
	if not ok:push_error(title)
func click(control:Control)->void:
	var point=control.get_global_rect().get_center()
	var motion=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;root.push_input(motion)
	var e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=point;e.global_position=point;e.pressed=true;root.push_input(e)
	e=e.duplicate();e.pressed=false;root.push_input(e);await process_frame
func growth_key()->void:
	var event=InputEventKey.new();event.keycode=KEY_G;event.physical_keycode=KEY_G;event.pressed=true;root.push_input(event)
	event=event.duplicate();event.pressed=false;root.push_input(event);await process_frame
func shot(name:String)->void:
	v.queue_redraw();await process_frame;await process_frame;await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(out+name+".png")==OK,"capture "+name)
func run()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):out=arg.trim_prefix("--output=")
		if arg.begins_with("--report="):report=arg.trim_prefix("--report=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	root.size=Vector2i(1600,900);root.content_scale_size=Vector2i(1600,900)
	v=View.new();v.save_disabled=true;v.event_audio=false;v.equipment=Gear.new(71);root.add_child(v);await process_frame;v.set_process(false)
	var g=v.equipment;var ui=v.growth_ui
	check(v.controls.depth.max_value==1,"new player starts with strength one")
	await shot("01-select")
	await growth_key()
	check(v.screen=="growth" and v.paused,"G opens growth and pauses battle without removed toolbar button")
	check(ui.controls.skill_0_0.disabled and ui.controls.skill_0_1.disabled,"skills locked until level three")
	g.s.level=20;ui.refresh();await process_frame
	await click(ui.controls.skill_0_1);await click(ui.controls.skill_4_1)
	check(g.mode(0)==1 and g.mode(4)==1,"mouse changes two independent skill branches")
	await shot("02-skills")
	for id in g.Builds.CARD_IDS:g.discover(id,true)
	await click(ui.controls.tab_1)
	check(g.growth.slots.size()==3,"first acquired cards occupy three slots")
	var before=g.growth.slots.duplicate();await click(ui.controls.card_kappa)
	check(g.growth.slots==before,"fourth card cannot exceed slot capacity")
	await click(ui.controls.card_tengu);await click(ui.controls.card_kappa)
	check("tengu" not in g.growth.slots and "kappa" in g.growth.slots,"mouse replaces an equipped card")
	check(v.model.preview_stats(0).hp>g.stats(0).hp+220,"card HP appears in equipment preview")
	var equips=g.s.equipped.duplicate(true);var compare=v.model.preview_equipment(6,0,"head")
	check(not compare.is_empty() and g.s.equipped==equips,"card-aware item comparison restores all equipment")
	await shot("03-cards")
	await click(ui.controls.tab_2);await shot("04-records-empty")
	await click(ui.controls.back);check(v.screen=="battle" and not v.paused,"growth return restores pause state")
	g.record_clear("hyakki","R02-S10",1,true);v.build_controls();await process_frame
	check(v.controls.depth.max_value==4,"real chapter record expands strength selector")
	v.controls.depth.value=4;await click(v.controls.start)
	check(v.model.depth==4 and v.model.encounter_rating()==31,"selected strength reaches real battle formula")
	await growth_key()
	var saved=g.snapshot();ui.choose_skill(0,0);ui.toggle_card("tengu")
	check(g.snapshot()==saved and ui.controls.tab_0!=null,"battle guard blocks edits even through direct callbacks")
	await click(ui.controls.tab_0);check(ui.controls.skill_0_0.disabled,"fight skill controls disabled")
	await shot("05-readonly")
	await click(ui.controls.back)
	v.toggle_pause();var time=v.model.time;v._process(.1)
	check(v.model.time==time,"pause freezes model")
	v.toggle_pause();v.speed=3;v._process(.1)
	check(v.model.time>time+.28,"three times speed advances simulation")
	# A fresh profile completes the real two-world campaign through its natural attacks.
	v.equipment=Gear.new(71);g=v.equipment;ui.gear=g;v.equipment_ui.gear=g;v.model.attach(g);v.selected_depth=1;v.begin_level(0)
	while v.model.phase in ["fight","clear"] and v.model.time<2000:
		if v.model.phase=="clear":v.model.advance_stage()
		else:v.model.advance(.25)
	check(v.model.phase=="victory" and v.model.kills==100,"natural full twenty-scene campaign victory")
	v.build_controls();v.open_growth();ui.tab=2;ui.refresh();await shot("06-records-complete")
	check(g.growth.scenes.size()==20 and g.owned_card_count()>=2,"growth screen uses accumulated campaign records")
	v.close_growth();v.restart();v.selected_depth=1;v.repeat_run=true;v.begin_level(0)
	while not (v.model.phase=="clear" and v.model.is_level_end()) and v.model.time<2000:
		if v.model.phase=="clear":v.model.advance_stage()
		else:v.model.advance(.25)
	v.prev_phase=v.model.phase;v.end_clock=4;v._process(.02)
	check(v.travel.active,"loop restarts through a teleport")
	while v.travel.active:v._process(.05)
	check(v.model.phase=="fight" and v.model.level_index()==0 and v.model.depth==1 and v.model.scene_index()==0,"loop repeats selected chapter without raising difficulty")
	check(v.controls.has("stop_repeat"),"active loop has visible stop control")
	await click(v.controls.stop_repeat);check(not v.repeat_run,"mouse stops loop")
	v.repeat_run=true
	for hero in v.model.units.slice(0,5):v.model.damage(-1,hero.uid,100000000,"test")
	v._process(.02)
	check(v.model.phase=="defeat" and not v.repeat_run,"defeat stops optional loop")
	check(g.s.level>1 and g.growth.scenes.size()==20,"defeat preserves all accumulated growth")
	await shot("07-defeat")
	var failures=checks.filter(func(c):return not c.pass)
	var f=FileAccess.open(report,FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures,"normal_save_loaded":false,"renderer":RenderingServer.get_video_adapter_name()},"\t"));f.close()
	print("PROGRESSION_UI %d checks %d failures"%[checks.size(),failures.size()]);quit(0 if failures.is_empty() else 1)
