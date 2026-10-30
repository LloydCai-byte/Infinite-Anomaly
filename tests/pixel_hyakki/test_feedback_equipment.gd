extends SceneTree
const Home=preload("res://scripts/pixel_home/home.gd")
const Gear=preload("res://scripts/pixel_home/gear.gd")
var out="res://docs/feedback-revision-20261028/verification/equipment/"
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
	home.battle.equipment_ui.queue_redraw();await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out+name+".png")
func run() -> void:
	home=Home.new();root.add_child(home);await process_frame;await process_frame
	home.finish_intro();home.close_dialog();home.open_overlay("equipment")
	var gear=home.gear;var ui=home.battle.equipment_ui;gear.s.equipped=[{},{},{},{},{}]
	var set_items=[]
	for i in range(4):set_items.append(gear.award(6,0,4,62+i))
	check(gear.equipped_look(0)==-1,"owning full set in backpack does not change appearance")
	for i in range(3):gear.equip(set_items[i].id,0,gear.G.SET_TYPES[i])
	check(gear.equipped_look(0)==-1,"three pieces do not activate full-set appearance")
	gear.equip(set_items[3].id,0,"boots")
	check(gear.equipped_look(0)==0,"four actually equipped matching pieces activate appearance")
	var before=gear.snapshot();var candidate=gear.award(5,1,4,66)
	var equipped=gear.s.equipped.duplicate(true);var look=gear.equipped_looks()
	gear.preview(candidate.id,0,"head")
	check(gear.s.equipped==equipped and gear.equipped_looks()==look,"comparison cannot change equipped set or active appearance")
	gear.equip(candidate.id,0,"head")
	check(gear.equipped_look(0)==-1,"mixing sets removes old appearance")
	gear.equip(set_items[0].id,0,"head");gear.equip(set_items[3].id,1,"boots")
	check(gear.equipped_look(0)==-1 and gear.equipped_look(1)==-1,"transferring one piece recalculates both owners")
	gear.equip(set_items[3].id,0,"boots");set_items[0].locked=true
	ui.hero=0;ui.selected=set_items[0].id;ui.refresh()
	check(not ui.controls.has("discovered_look") and not gear.set_look(0,1),"manual appearance action removed from UI and model")
	var standard=ui.actor_bounds.fenfen.size.y*ui.preview_scale()
	for hero in range(5):
		ui.hero=hero;ui.refresh();await shot("preview-%d"%hero)
		check(absf(ui.actor_bounds[ui.IDS[hero]].size.y*ui.preview_scale()-standard)<3,"hero %d has Fenfen-standard visible height"%hero)
	ui.hero=0;ui.refresh();await shot("locked-set")
	check(ui.controls.salvage.disabled and not gear.salvage(set_items[0].id),"locked equipped item remains protected")
	check(gear.persist(),"new appearance uses same atomic save")
	var loaded=Gear.new();loaded.open_profile(home.battle.profile_path)
	check(loaded.equipped_look(0)==0 and loaded.s.equipped==gear.s.equipped,"full-set appearance restored from actual equipment")
	home.battle.close_equipment();await process_frame
	check(home.battle.model.looks_live==gear.equipped_looks(),"battle appearance refreshes on closing equipment")
	home.queue_free();await process_frame
	var failed=checks.filter(func(c):return not c.pass)
	var file=FileAccess.open(out+"rules-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failed":failed.size()},"  "));file.close()
	print("FEEDBACK_EQUIPMENT ",checks.size()," checks, ",failed.size()," failures");quit(0 if failed.is_empty() else 1)
