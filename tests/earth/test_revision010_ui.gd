extends SceneTree
const Main=preload("res://scripts/earth/main.gd")
const Loot=preload("res://scripts/earth/loot.gd")
const OUT="res://art/earth-production/revision-010/captures/"
var game: Control
var checks=0
var failures=0
var capture=false
func _initialize() -> void:call_deferred("run")
func ck(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL "+label)
func click(id: String) -> void:
	ck(game.buttons.has(id),"control exists "+id)
	if not game.buttons.has(id):return
	var pos=game.buttons[id].get_global_rect().get_center()
	var move=InputEventMouseMotion.new();move.position=pos;root.push_input(move)
	var e=InputEventMouseButton.new();e.position=pos;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true
	root.push_input(e);await process_frame
	e=e.duplicate();e.pressed=false;root.push_input(e);await process_frame
func shot(name: String) -> void:
	if not capture:return
	game.battlefield.queue_redraw()
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")
func run() -> void:
	capture="--capture" in OS.get_cmdline_user_args()
	root.size=Vector2i(1600,900)
	game=Main.new();root.add_child(game);game.transient=true
	await process_frame
	game.set_process(false)
	await shot("01-menu")
	game.model.s.intro_done=true;game.navigate("base")
	await process_frame
	ck(not game.buttons.has("map") and game.buttons.has("squad"),"home removes floorplan and retains squad")
	await shot("02-living")
	await click("door_corridor");await shot("03-corridor")
	await click("door_kitchen");await shot("04-kitchen")
	await click("door_back");await click("door_bathroom");await shot("05-bathroom")
	await click("door_back");await click("door_bedroom");await shot("06-bedroom")
	await click("door_back");await click("door_back");await click("door_balcony");await shot("07-balcony")
	await click("door_back");await click("door_workroom")
	ck(not game.buttons.has("collection") and game.buttons.has("printer"),"workroom decoration has no collection action")
	await shot("08-workroom")
	await click("printer");await shot("09-printer")
	await click("back");await click("door_back");await click("depart")
	ck(game.view=="missions","black door opens portal selector")
	await click("mission2")
	ck(game.buttons.open_portal.disabled and not game.model.active(),"locked destination inspectable but cannot enter")
	await shot("10-locked-portal")
	await click("mission1")
	ck(not game.model.active(),"selection alone does not dispatch")
	await shot("11-portal")
	await click("open_portal")
	ck(game.portal_opening,"door animation starts")
	await create_timer(.45).timeout
	await shot("12-door-opening")
	await create_timer(.8).timeout
	ck(game.view=="battle" and game.model.active(),"door leads to chosen battle")
	for i in range(18000):
		game.model.tick(1.0/60)
		if not game.model.active():break
	game.navigate("result")
	ck(game.model.s.result.get("reason")=="victory","natural first fight reaches result")
	await shot("13-victory-loot")
	await click("loot");await shot("14-equipment-before")
	await click("person1");await click("equip_loot")
	ck(game.model.item_owner(game.loot_selected)==1,"UI equips helmet to Fenfen")
	await shot("15-equipment-equipped")
	await click("back");await click("continue_next")
	ck(game.view=="battle" and game.model.s.battle.stage==2,"result continue actual click")
	game.model.spawn_encounter()
	for u in game.model.alive(1):u.hp=10000;u.max_hp=10000
	for i in range(310):game.model.tick(1.0/60)
	game.refresh_battle();await shot("16-spirit-battle")
	await click("recall");ck(game.buttons.continue_next.disabled,"recall cannot skip next stage")
	await shot("17-recall")
	await click("repeat");ck(game.view=="battle" and game.model.s.battle.stage==2,"repeat actual click")
	await click("recall");var visits=game.model.s.home.visits;await click("return")
	ck(game.view=="base" and game.model.s.home.visits==visits+1,"explicit return settles once")
	await click("squad");await shot("18-squad")
	await click("equipment");await click("back");ck(game.view=="squad","equipment return preserves origin")
	game.navigate("support");await shot("19-support")
	game.navigate("growth");await shot("20-growth")
	game.navigate("suits");await shot("21-suits")
	game.navigate("room");await shot("22-space")
	game.navigate("base");game.open_settings();await shot("23-settings")
	for v in ["base","squad","equipment","printer","growth","suits","room","support","missions"]:
		game.navigate(v)
		for b in game.buttons.values():ck(Rect2(0,0,1600,900).encloses(b.get_global_rect()),"button fits "+v+"/"+b.name)
	game.settings.large=true
	for v in ["equipment","missions","growth","support"]:
		game.navigate(v);await process_frame
		for b in game.buttons.values():ck(Rect2(0,0,1600,900).encloses(b.get_global_rect()),"large type fits "+v+"/"+b.name)
	var f=FileAccess.open("res://docs/revision-20261002/ui-test.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures,"capture":capture,"input":"Godot viewport mouse events"},"  "));f.close()
	print("REVISION010 UI ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
