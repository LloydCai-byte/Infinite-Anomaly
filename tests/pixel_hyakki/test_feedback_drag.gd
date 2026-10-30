extends SceneTree
const Home=preload("res://scripts/pixel_home/home.gd")
var out="res://docs/feedback-revision-20261028/verification/drag/"
var checks=[]
var home
var ui
func check(ok:bool,label:String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--feedback-test-output="):out=arg.trim_prefix("--feedback-test-output=").trim_suffix("/")+"/"
	root.size=Vector2i(1600,900);root.content_scale_size=Vector2i(1600,900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out));call_deferred("run")
func mouse(point:Vector2,button:int=-1) -> void:
	var event
	if button<0:event=InputEventMouseMotion.new();event.position=point;event.global_position=point
	else:event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=button==1;event.position=point;event.global_position=point
	Input.parse_input_event(event);await process_frame
func bag_point(id:int) -> Vector2:
	var index=ui.items().find(ui.gear.item_by_id(id));ui.page=int(index/35);ui.refresh();return ui.cell_rect(index%35).get_center()
func drag_to(id:int,target:Vector2) -> void:
	var start=bag_point(id);await mouse(start);await mouse(start,1);await mouse(start+Vector2(12,0));await mouse(target);await mouse(target,0);await process_frame
func shot(name:String) -> void:
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out+name+".png")
func run() -> void:
	home=Home.new();root.add_child(home);await process_frame;await process_frame
	home.finish_intro();home.close_dialog();home.open_overlay("equipment");ui=home.battle.equipment_ui
	var g=home.gear;var ring=g.award(5,0,2,56);var next_ring=g.award(5,0,2,57)
	ui.hero=0;ui.refresh()
	check(ui.drag.eligible_slots(ring.id)==["ring_a","ring_b"],"both legal ring destinations highlighted")
	var a=ui.slot_rect(ui.G.SLOTS.find("ring_a"));var b=ui.slot_rect(ui.G.SLOTS.find("ring_b"))
	var near=b.get_center()+Vector2(b.size.x*.5+14,0)
	await drag_to(ring.id,near)
	check(g.s.equipped[0].get("ring_b",0)!=ring.id,"14px outside slot does not attract equipment")
	await drag_to(ring.id,b.get_center()+Vector2(b.size.x*.5+3,0))
	check(g.s.equipped[0].get("ring_b",0)==ring.id,"mouse drag snaps only 3px beside ring B")
	await drag_to(next_ring.id,a.get_center())
	check(g.s.equipped[0].get("ring_a",0)==next_ring.id and g.s.equipped[0].ring_b==ring.id,"drag preserves independent rings")
	var before=g.s.equipped.duplicate(true)
	await drag_to(ring.id,Vector2(810,840));check(g.s.equipped==before and not ui.drag.active,"invalid drop leaves all equipment unchanged")
	var sword=g.award(5,0,2,0);ui.hero=1;ui.refresh()
	check(ui.drag.eligible_slots(sword.id).is_empty(),"incompatible class has no highlighted slot")
	await drag_to(sword.id,ui.slot_rect(0).get_center());check(g.s.equipped==before,"wrong-class drag cannot equip")
	ui.hero=1;ui.refresh();await drag_to(ring.id,b.get_center())
	check(g.owner(ring.id)==1 and not g.s.equipped[0].has("ring_b"),"dragging already worn item transfers ownership")
	var start=bag_point(next_ring.id);await mouse(start);await mouse(start,1);await mouse(a.get_center()+Vector2(12,0))
	await shot("drag-highlight-and-snap")
	check(ui.drag.active and ui.drag.hover_slot=="ring_a","active pointer shows snapped ghost and highlights legal slot")
	var key=InputEventKey.new();key.keycode=KEY_ESCAPE;key.pressed=true;Input.parse_input_event(key);await process_frame
	check(not ui.drag.active and home.battle.screen=="equipment" and g.owner(next_ring.id)==0,"Escape cancels only drag, preserving equipment and page")
	key.pressed=false;Input.parse_input_event(key);await mouse(a.get_center(),0)
	start=bag_point(ring.id);await mouse(start);await mouse(start,1);await mouse(start,0)
	check(ui.selected==ring.id and g.owner(ring.id)==1,"normal click still selects without unintended equip")
	var restored=g.get_script().new();restored.open_profile(home.battle.profile_path)
	check(restored.s.equipped==g.s.equipped,"drag equipment survives isolated save reload")
	home.battle.close_equipment();home.queue_free();await process_frame
	var failed=checks.filter(func(c):return not c.pass)
	var file=FileAccess.open(out+"verification.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failed":failed.size()},"  "));file.close()
	print("FEEDBACK_DRAG ",checks.size()," checks, ",failed.size()," failures");quit(0 if failed.is_empty() else 1)
