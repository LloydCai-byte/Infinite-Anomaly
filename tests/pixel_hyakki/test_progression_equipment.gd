extends SceneTree
const View=preload("res://scripts/pixel_hyakki/view.gd")
const Gear=preload("res://scripts/pixel_hyakki/progression/gear.gd")
const OldGear=preload("res://scripts/turnbased/model.gd")
const Battle=preload("res://scripts/pixel_hyakki/progression/battle.gd")
var v
var checks=0
var failures=[]
var out="res://docs/progression-research-20261026/equipment-captures/"
var report="res://docs/progression-research-20261026/equipment-verification.json"
var profile="user://progression-equipment-test.json"
func check(ok:bool,reason:String)->void:
	checks+=1
	if not ok:failures.append(reason);printerr("FAIL ",reason)
func _initialize()->void:call_deferred("run")
func click(control:Control)->void:
	var point=control.get_global_rect().get_center()
	var move=InputEventMouseMotion.new();move.position=point;move.global_position=point;root.push_input(move)
	var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=point;event.global_position=point;event.pressed=true;root.push_input(event)
	event=event.duplicate();event.pressed=false;root.push_input(event);await process_frame
func shot(name:String)->void:
	v.queue_redraw();v.equipment_ui.queue_redraw();await process_frame;await process_frame;await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(out+name+".png")==OK,"capture "+name)
func text_tree(node:Node)->String:
	var value=""
	if node is Label or node is Button or node is RichTextLabel:value+=node.text+"\n"
	for child in node.get_children():value+=text_tree(child)
	return value
func run()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):out=arg.trim_prefix("--output=")
		if arg.begins_with("--report="):report=arg.trim_prefix("--report=")
		if arg.begins_with("--profile="):profile=arg.trim_prefix("--profile=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	root.size=Vector2i(1600,900);root.content_scale_size=Vector2i(1600,900)
	v=View.new();v.equipment=Gear.new(901);v.save_disabled=true;v.event_audio=false;root.add_child(v);await process_frame;v.set_process(false)
	var g=v.equipment
	await click(v.controls.equipment)
	var ui=v.equipment_ui
	check(v.screen=="equipment" and v.paused,"mouse opens equipment and pauses")
	check(not ui.controls.has("forge") and not ui.controls.has("look_0") and not ui.controls.has("discovered_look"),"no forge or undiscovered collection controls")
	check("碎片" not in text_tree(ui.layer) and "锻造" not in text_tree(ui.layer) and "收集" not in text_tree(ui.layer),"no removed UI labels")
	await shot("01-initial")
	var max_error=0.0
	for base in range(g.G.bases.size()):
		var item={"base":base};var area=ui.icon_area(ui.cell_rect(base%35));var dest=ui.art.destination(item,area)
		max_error=maxf(max_error,dest.get_center().distance_to(area.get_center()))
		check(area.grow(.75).encloses(dest),"icon fits cell "+str(base))
	check(max_error<=.72,"all 74 equipment bases visually centered within rounding tolerance")
	var saved_equips=g.s.equipped.duplicate(true);g.preview(6,0,"head");check(g.s.equipped==saved_equips,"preview does not mutate equipment")
	ui.choose(6);await process_frame;await click(ui.controls.equip)
	check(g.s.equipped[0].get("head")==6,"mouse equips helmet")
	check(ui.controls.salvage.disabled,"equipped item cannot be salvaged")
	await click(ui.controls.unequip);check(g.owner(6)==-1,"mouse unequips helmet")
	await click(ui.controls.lock);check(g.item_by_id(6).locked and ui.controls.salvage.disabled,"mouse lock protects item")
	await click(ui.controls.lock)
	var gold=g.s.gold;var expected=g.salvage_gold(g.item_by_id(6))
	await click(ui.controls.salvage);check(not g.item_by_id(6).is_empty(),"salvage confirmation retains item")
	await click(ui.controls.salvage);check(g.item_by_id(6).is_empty() and g.s.gold==gold+expected and g.s.materials==0,"salvage gives gold only")
	var ring_ids=[]
	for item in g.s.inventory:
		if g.G.type_of(item)=="ring":ring_ids.append(item.id)
	ui.choose(ring_ids[0]);await process_frame;await click(ui.controls.ring_b);await click(ui.controls.equip)
	ui.choose(ring_ids[1]);await process_frame;await click(ui.controls.ring_a);await click(ui.controls.equip)
	check(g.s.equipped[0].ring_a==ring_ids[1] and g.s.equipped[0].ring_b==ring_ids[0],"independent two ring slots")
	await click(ui.controls.hero_1);await click(ui.controls.equip)
	check(g.owner(ring_ids[1])==1 and not g.s.equipped[0].has("ring_a"),"transfer clears former owner")
	ui.choose(1);await process_frame;check(ui.controls.equip.disabled,"wrong class weapon disabled")
	await shot("02-class-restriction")
	var before=g.snapshot();check(g.forge(0).is_empty() and g.snapshot()==before,"removed forge cannot create items or consume currency")
	await click(ui.controls.back);check(v.screen=="battle" and not v.paused,"return restores battle")
	# Real reward path: all boss items, including sets, must originate in enemy death.
	var boss_sets=0;var first_id=g.s.next_id
	for i in range(80):
		var battle=Battle.new();battle.attach(g);battle.stage=4;battle.spawn_stage()
		var count=g.s.inventory.size();battle.damage(-1,7,100000,"test")
		check(g.s.inventory.size()==count+1,"boss guaranteed item "+str(i))
		var item=g.s.inventory.back()
		if item.quality==4:boss_sets+=1
		check(item.origin.type=="monster" and not battle.run_loot.is_empty(),"drop provenance and feedback "+str(i))
		battle.damage(-1,7,100000,"test");check(g.s.inventory.size()==count+1,"dead enemy cannot drop twice "+str(i))
	check(boss_sets>0,"set items really drop from monsters")
	check(g.s.loot_log.size()==40 and g.s.materials==0,"bounded loot history and no shard income")
	var ordinary=0
	for i in range(80):
		var battle=Battle.new();battle.attach(g);battle.start();var count=g.s.inventory.size();battle.damage(-1,5,100000,"test")
		ordinary+=g.s.inventory.size()-count
	check(ordinary>0 and ordinary<80,"ordinary enemies probabilistic loot")
	# Natural full campaign run, no manual damage calls or injected equipment.
	v.equipment=Gear.new(1001);g=v.equipment;ui.gear=g;ui.toast_time=0;v.model.attach(g);v.begin_level(0);await process_frame
	var count=g.s.inventory.size();var currency=g.s.gold;var captured=false
	for i in range(100000):
		v.model.advance(.1)
		if not captured and not v.model.run_loot.is_empty():
			await shot("03-monster-drop");captured=true
		if v.model.phase=="clear":v.model.advance_stage()
		if v.model.phase in ["victory","defeat"]:break
	check(v.model.phase=="victory" and v.model.kills==100,"two ten-scene levels naturally complete")
	check(g.s.inventory.size()>count and g.s.gold>currency,"natural monster rewards enter inventory")
	check(g.s.inventory.size()-count==v.model.run_loot.size(),"each drop credited exactly once")
	v.open_equipment();ui.hero=0;ui.type_filter=0;ui.quality_filter=0;ui.sort_mode=0;ui.page=0
	var legendary=g.s.inventory.filter(func(i):return i.quality in [3,5])
	ui.choose(legendary[0].id if not legendary.is_empty() else g.s.inventory.back().id);await process_frame
	await shot("04-loot-inventory")
	check(not ui.controls.has("forge") and not ui.controls.has("look_0"),"removed controls stay absent after drops")
	await click(ui.controls.recent);check(ui.selected==g.s.loot_log.back().id,"recent drop selects real inventory object")
	var unowned=g.s.inventory.filter(func(i):return i.id>=18 and g.G.type_of(i)!="weapon")[0]
	ui.choose(unowned.id);await process_frame;await click(ui.controls.equip);check(g.owner(unowned.id)==0,"dropped equipment is wearable")
	ui.quality_filter=5;ui.refresh();await process_frame;var sets=ui.items()
	if not sets.is_empty():ui.choose(sets[0].id);await process_frame;await shot("05-discovered-set")
	ui.type_filter=1;ui.quality_filter=5;ui.refresh();await process_frame;check(ui.items().is_empty(),"empty set-weapon filter");await shot("06-empty-filter")
	ui.type_filter=0;ui.quality_filter=0;ui.refresh();await process_frame
	await click(ui.controls.next);check(ui.page==1,"mouse next inventory page")
	await click(ui.controls.prev);check(ui.page==0,"mouse previous inventory page")
	# Compatibility migration: retain inventory, money and historical shard value without enabling it.
	var old=OldGear.new(22);old.s.materials=137;old.s.gold=987
	var migrated=Gear.new(33);check(migrated.restore(old.snapshot()),"legacy profile loads")
	check(migrated.s.inventory==old.s.inventory and migrated.s.equipped==old.s.equipped and migrated.s.gold==987 and migrated.s.retired_materials==137 and migrated.s.materials==0,"legacy items money and historical value preserved")
	var saved=Gear.new();saved.open_profile(profile);saved.s=g.s.duplicate(true);check(saved.persist(),"save real dropped equipment")
	var loaded=Gear.new();loaded.open_profile(profile);check(loaded.s==g.s,"reload exact inventory ownership and loot history")
	var current_stats=v.model.stats_live[0].duplicate(true);g.train(0);check(v.model.stats_live[0]==current_stats,"battle gear stats are stable until next scene")
	v.model.spawn_stage();check(v.model.units[0].max_hp==roundi(v.model.preview_stats(0).hp),"gear stats apply on next scene")
	ui.choose(unowned.id);ui.quality_filter=0;ui.refresh();await process_frame
	root.size=Vector2i(1280,720);await process_frame;await process_frame;await shot("07-1280x720")
	root.size=Vector2i(1600,900)
	var result={"checks":checks,"failures":failures,"renderer":RenderingServer.get_video_adapter_name(),"boss_set_drops":boss_sets,"ordinary_drops_of_80":ordinary,"natural_kills":v.model.kills,"natural_drop_count":v.model.run_loot.size(),"max_icon_center_error_px":max_error,"skin":"image_gen clean plate plus live native UI","test_data":"isolated; player profile unchanged"}
	var file=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "));file.close();print("GOTHIC EQUIPMENT ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
