extends SceneTree
const Home=preload("res://scripts/pixel_home/home.gd")
const G=preload("res://scripts/turnbased/gear.gd")
var out="res://docs/equipment-reference-20261028/verification/"
var checks=[]
var home
var ui
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--reference-output="):out=arg.trim_prefix("--reference-output=").trim_suffix("/")+"/"
	root.size=Vector2i(1600,900);root.content_scale_size=Vector2i(1600,900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out));call_deferred("run")
func check(ok:bool,caption:String)->void:
	checks.append({"pass":ok,"name":caption})
	if not ok:push_error(caption)
func shot(name:String)->void:
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out+name+".png")
func click(control:Control)->void:
	var point=control.get_global_rect().get_center()
	var motion=InputEventMouseMotion.new();motion.position=point;root.push_input(motion)
	var event=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;root.push_input(event)
	event=event.duplicate();event.pressed=false;root.push_input(event);await process_frame
func run()->void:
	home=Home.new();root.add_child(home);await process_frame;await process_frame
	home.finish_intro();home.close_dialog();home.arrival=0;home.open_overlay("equipment");ui=home.battle.equipment_ui
	await shot("01-fresh-profile")
	check(home.battle.profile_path.contains("equipment-reference-20261028"),"isolated test profile")
	var g=home.gear;g.s.inventory=[];g.s.equipped=[{},{},{},{},{}];g.s.loot_log=[];g.s.gold=6152;g.s.level=10
	var rng=RandomNumberGenerator.new();rng.seed=47
	var bases=[62,20,12,8,38,1,12,1,44,63,20,56,50,56,64,8,65,1,8,16,32,62,64,50,26,20,32,32,8,38,56,8,62,38,65]
	for n in range(53):
		var item=G.make(rng,53-n,37-n%37,0,[4,2,1,5,5,1,2][n%7],bases[n%bases.size()])
		g.s.inventory.append(item)
	g.s.next_id=54
	var sword=g.s.inventory[5];sword.base=1;sword.level=34;sword.quality=1;sword.affixes={"fire":9.0,"hp":50.6};sword.power=""
	for i in range(9):
		var item=g.s.inventory[44+i];item.base=[0,20,26,32,38,44,50,56,56][i];g.equip(item.id,0,G.SLOTS[i])
	var restored=g.get_script().new();check(restored.restore(g.snapshot()),"reference fixture is a valid reloadable equipment state")
	ui.hero=0;ui.selected=sword.id;ui.refresh();await shot("02-reference-layout")
	check(ui.page_size()==35 and ui.items().size()==53,"seven by five inventory with real 53-item fixture")
	check(ui.skin.texture.get_size()==Vector2(1774,887),"exact user reference atlas loaded")
	check(ui.r(0,0,1774,887).size.is_equal_approx(Vector2(1600,800)),"reference aspect ratio preserved")
	await click(ui.controls.next);check(ui.page==1,"next page by actual mouse");await shot("03-last-page")
	await click(ui.controls.prev);check(ui.page==0,"previous page by actual mouse")
	check(not ui.controls.has("view_list") and not ui.controls.has("view_grid") and ui.page_size()==35,"grid-only inventory keeps 35 cells")

	for h in range(5):
		await click(ui.controls["hero_%d"%h]);check(ui.hero==h,"hero tab %d mouse hit target"%h)
	await shot("05-other-hero")
	await click(ui.controls.hero_0);ui.choose(sword.id)
	await click(ui.controls.equip);check(g.s.equipped[0].weapon==sword.id,"equip executes existing model")
	await click(ui.controls.unequip);check(g.owner(sword.id)==-1,"unequip returns item")
	await click(ui.controls.lock);check(sword.locked and ui.controls.salvage.disabled,"lock disables destructive action")
	await shot("06-locked");await click(ui.controls.lock)
	var before=g.s.inventory.size();await click(ui.controls.salvage);check(g.s.inventory.size()==before,"salvage first click only confirms")
	var confirm_panel=ui.get_children().filter(func(child):return child.get_script()==preload("res://scripts/pixel_home/salvage_confirm.gd"))[0]
	await click(confirm_panel.controls.confirm);check(g.s.inventory.size()==before-1,"confirmed salvage removes only selected item")
	ui.type_filter=1;ui.quality_filter=1;ui.page=9;ui.refresh()
	check(ui.items().is_empty() and ui.page==0,"empty filter clamps page")
	check(ui.controls.equip.disabled and ui.controls.salvage.disabled,"empty detail has no stale action")
	await shot("07-empty-filter")
	ui.type_filter=0;ui.quality_filter=0;ui.sort_mode=1;ui.refresh()
	var sorted=ui.items();check(G.score(sorted[0])>=G.score(sorted[-1]),"score sorting remains functional")
	ui.choose(sorted[0].id);ui.toast_time=0
	ui.controls.details_body.get_v_scroll_bar().value=10000
	await process_frame
	check(ui.controls.details_body.get_v_scroll_bar().value>0,"long affixes and powers remain scrollable")
	await shot("11-long-details-scrolled")
	root.size=Vector2i(1280,720);await shot("08-1280x720")
	root.size=Vector2i(1920,1080);await shot("09-1920x1080")
	root.size=Vector2i(1600,900);await click(ui.controls.back);check(home.battle.screen!="equipment","close returns to room")
	home.depart(0);home.battle.paused=true;home.battle.open_equipment();ui.toast_time=0;await shot("10-battle-overlay")
	check(home.battle.screen=="equipment" and home.battle.paused,"same UI opens above paused battle")
	await click(ui.controls.back);check(home.battle.screen=="battle" and home.battle.paused,"close preserves preexisting pause")
	home.queue_free();await process_frame
	var failed=checks.filter(func(c):return not c.pass)
	var file=FileAccess.open(out+"verification.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failed":failed.size()},"  "));file.close()
	print("REFERENCE_UI ",checks.size()," checks ",failed.size()," failures");quit(0 if failed.is_empty() else 1)
