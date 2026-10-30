extends SceneTree
const Home=preload("res://scripts/pixel_home/home.gd")
const Hud=preload("res://scripts/pixel_hyakki/battle_hud.gd")
var out="res://docs/feedback-revision-20261028/verification/battle-ui/"
var checks=[]
var home
func check(ok:bool,label:String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--feedback-test-output="):out=arg.trim_prefix("--feedback-test-output=").trim_suffix("/")+"/"
	root.size=Vector2i(1600,900);root.content_scale_size=Vector2i(1600,900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out));call_deferred("run")
func shot(name:String) -> void:
	home.battle.queue_redraw();await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out+name+".png")
func run() -> void:
	home=Home.new();root.add_child(home);await process_frame;await process_frame
	home.finish_intro();home.close_dialog();home.depart(0)
	var view=home.battle;var model=view.model;view.set_process(false)
	check(view.controls.keys()==["pause","speed","auto_next","equipment","home"],"only retained toolbar controls are visible")
	for unit in model.units:unit.charge=0
	for fill in [0.0,1.0]:
		for unit in model.units:unit.charge=fill
		for side in [0,1]:
			var entries=Hud.timeline_layout(model,side);var valid=entries.size()==5
			for i in range(entries.size()):
				valid=valid and entries[i].rect.position.x>=990 and entries[i].rect.end.x<=1490
				if i>0:valid=valid and not entries[i].rect.intersects(entries[i-1].rect)
			check(valid,"crowded rail fits all five non-overlapping portraits at charge %s side %d"%[fill,side])
	model.begin_action(0);model.ready_queue=[1,2,3,4,5,6,7,8,9]
	var entries=Hud.timeline_layout(model,0)
	check(entries.filter(func(e):return e.active).size()==1 and entries.all(func(e):return e.anchor==1474),"active and waiting icons retain exact full-charge anchors")
	await shot("crowded")
	model.units[9].hp=0
	check(Hud.timeline_layout(model,1).size()==4,"dead enemy removed from action rail")
	model.reset();model.start()
	var before=model.units[5].hp;model.damage(0,5,23,"slash")
	check(model.units[5].hp<before and Hud.hp_label(model.units[5])=="%d / %d"%[model.units[5].hp,model.units[5].max_hp],"head display follows actual equipment damage result")
	view.paused=true;var clock=model.time;var hp=model.units[5].hp
	for i in range(30):view._process(.05)
	check(model.time==clock and model.units[5].hp==hp,"pause freezes battle and HP values")
	view.paused=false;model.finish("clear")
	var previous_stage=model.stage;var start_total=model.time
	view.advance_selected();var saved=model.units.duplicate(true)
	check(view.travel.active and model.stage==previous_stage,"next scene starts a teleport before advancing")
	view.advance_selected();check(model.stage==previous_stage,"repeated next request cannot skip a scene")
	for frame in range(40):
		view._process(.04)
		if frame in [0,10,16,25]:await shot("teleport-%03d"%frame)
		if view.travel.active:check(model.time==start_total,"combat clock frozen during teleport") if frame==14 else null
	check(not view.travel.active and model.time>start_total,"combat resumes only after arrival")
	check(model.units[0].home==saved[0].home,"teleport never changes approved formation")
	model.finish("clear");view.advance_selected();view.paused=true
	var travel_time=view.travel.elapsed
	for i in range(30):view._process(.1)
	check(view.travel.elapsed==travel_time,"pause freezes teleport")
	view.open_equipment();view._process(.1);check(view.travel.elapsed==travel_time,"equipment freezes transition")
	view.close_equipment();view.begin_level(0)
	check(not view.travel.active and model.stage==0,"fresh departure clears transition state")
	view.paused=true;root.size=Vector2i(1280,720);await shot("battle-1280")
	home.finish_return();home.close_dialog();home.queue_free();await process_frame
	var failed=checks.filter(func(c):return not c.pass)
	var file=FileAccess.open(out+"verification.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failed":failed.size()},"  "));file.close()
	print("FEEDBACK_BATTLE ",checks.size()," checks, ",failed.size()," failures");quit(0 if failed.is_empty() else 1)
