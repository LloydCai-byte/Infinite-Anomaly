extends SceneTree
const C=preload("res://scripts/reboot/catalog.gd")
const Story=preload("res://scripts/reboot/story_catalog.gd")
var game: Control
var checks=0
var failures=0
class FailingStore:
	extends RefCounted
	var error="simulated disk failure"
	func save(_snapshot: Dictionary) -> bool: return false
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;printerr("WAR POINTER FAIL: "+label)
func point(pos: Vector2) -> void:
	var motion=InputEventMouseMotion.new();motion.position=pos;motion.global_position=pos
	root.push_input(motion,true)
	for pressed in [true,false]:
		var e=InputEventMouseButton.new();e.position=pos;e.global_position=pos
		e.button_index=MOUSE_BUTTON_LEFT;e.pressed=pressed;root.push_input(e,true)
		await process_frame
func click(id: String) -> void:
	check(game.ui.buttons.has(id),"button exists "+id)
	if game.ui.buttons.has(id): await point(game.ui.buttons[id].get_global_rect().get_center())
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1280,720)
	game=load("res://scenes/reboot/main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.transient=true
	game.model.import_state(str_to_var(FileAccess.get_file_as_string("res://.local/war-production/graduated-natural.save")))
	game.model.s.phase="training";game.model.s.war={};game.model.s.reveal_read=false
	game.view="base";game.page="";game.render()
	await click("base_graduation");await click("read_graduation")
	for line in Story.STORIES.graduation: await click("story_next")
	await click("handoff_confirm")
	check(not game.model.in_war(),"first handoff pointer only opens confirmation")
	# Transition must be atomic: a failed disk write cannot duplicate people.
	game.slot=1;game.transient=false;game.store=FailingStore.new()
	var training=game.committed.duplicate(true)
	await click("handoff_confirm")
	check(game.page=="save_error" and game.model.s==training and not game.model.in_war(),"failed handoff restores entire training snapshot")
	game.transient=true;game.slot=0;game.page="handoff";game.payload={"confirm":true};game.render()
	await click("handoff_confirm")
	check(game.view=="war" and game.model.s.war.generated==4,"retry transfers exactly four original identities")
	await click("war_speed");check(game.model.s.speed==2,"war speed hit test")
	await click("war_rooms");await click("room_group_1");await click("room_auto")
	check(not game.model.s.war.auto_send[1],"room network button toggles intended group")
	var phases=game.model.s.war.streams.duplicate(true)
	await point(Vector2(1540,868))
	check(game.page=="war_rooms" and game.model.s.war.streams==phases,"modal blocks underlying civilization navigation")
	await click("back");await click("war_formation");await click("formation_slot_0")
	check(game.model.s.war.formations[1][0]==1,"formation button changes one slot")
	await click("back");await click("war_retreat");await click("war_retreat_confirm")
	check(game.page=="war_result" and not game.model.s.war.active,"retreat confirms and settles")
	await click("war_result_return");await click("war_map");await click("planet_0");await click("planet_launch")
	check(game.model.s.war.active and game.page=="","map launches correct next planet")
	await click("war_retreat");await click("war_retreat_confirm");await click("war_result_return")
	game.open("war_history");await click("enter_history")
	check(game.view=="base" and game.model.s.history_active,"historical replay pointer route")
	await click("leave_history")
	check(game.view=="war" and not game.model.s.history_active,"history returns to real war")
	game.model.s.settings.large=true;game.render();await click("war_soldiers")
	await click("soldier_records");check(game.page=="war_ledger","large-font nested ledger remains clickable")
	# Mutation failure also restores room schedules, army and resources.
	game.go_base();game.commit();var before=game.model.s.duplicate(true)
	game.slot=1;game.transient=false;game.store=FailingStore.new()
	game.war_action("auto_send",0)
	check(game.page=="save_error" and game.model.s==before,"failed war order rolls back complete network")
	print("WAR_POINTER: ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
