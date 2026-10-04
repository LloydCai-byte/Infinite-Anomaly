extends SceneTree
const Home=preload("res://scripts/earth/home.gd")
const Assets=preload("res://scripts/earth/assets.gd")
const Model=preload("res://scripts/earth/model.gd")
var game: Control
var failures=0
var checks=0
var captures=false
func _initialize() -> void:call_deferred("run")
func ck(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL "+label)
func click(id: String) -> void:
	if not game.buttons.has(id):ck(false,"button exists: "+id);return
	var b=game.buttons[id]
	var pos=b.get_global_rect().get_center()
	var move=InputEventMouseMotion.new();move.position=pos;root.push_input(move)
	var e=InputEventMouseButton.new();e.position=pos;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true
	root.push_input(e);await process_frame
	e=e.duplicate();e.pressed=false;root.push_input(e);await process_frame
func shot(name: String) -> void:
	if not captures:return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art/earth-production/functional-070/"+name+".png")
func run() -> void:
	root.size=Vector2i(1600,900)
	captures="--capture" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute("res://art/earth-production/functional-070")
	for p in range(Home.PRESETS.size()):
		var ids=[]
		for room in Home.ROOM_IDS:ids.append_array(Home.members(p,room))
		ids.sort()
		ck(ids==["dadong","fenfen","gao","qiqi","wang","xuan"],"exactly five warriors plus host: preset "+str(p))
		for room in Home.ROOM_IDS:
			Assets.initialize()
			ck(Assets.entries.has(Home.image_id(p,room)),"tracked whole-room asset "+Home.image_id(p,room))
	var model=Model.new()
	var old=model.s.duplicate(true);old.erase("home")
	ck(model.import_state(old) and Home.valid(model.s.home),"migrate 0.6 save")
	var invalid=model.s.duplicate(true);invalid.home.preset=100
	var before=model.s.duplicate(true)
	ck(not model.import_state(invalid) and model.s==before,"bad home rejected atomically")
	ck(not model.enter_home_room("kitchen"),"no living to kitchen door")
	ck(model.enter_home_room("corridor") and model.enter_home_room("kitchen"),"connected door route")
	ck(model.enter_home_room("bedroom",true),"map fast travel")
	model.s.intro_done=true;model.depart(1)
	ck(not model.enter_home_room("living",true),"cannot teleport during battle")
	model.recall();var visits=model.s.home.visits;var last=model.s.home.preset
	model.close_result()
	ck(model.s.home.visits==visits+1 and model.s.home.preset!=last,"one reroll after recall")
	model.close_result();ck(model.s.home.visits==visits+1,"double settlement cannot reroll twice")
	game=load("res://scenes/earth/main.tscn").instantiate();root.add_child(game)
	game.transient=true;await process_frame
	await click("start");ck(game.view=="intro" and game.buttons.size()==2,"clean AVG only advance and settings")
	await click("next");ck(game.model.s.intro==1,"mouse advances one beat")
	await shot("01-avg")
	var key=InputEventKey.new();key.keycode=KEY_SPACE;key.pressed=true;root.push_input(key);await process_frame
	key=key.duplicate();key.pressed=false;root.push_input(key);await process_frame
	ck(game.model.s.intro==2,"space advances one beat")
	await click("settings");await click("skip");ck(game.view=="base","skip via settings enters home")
	game.model.s.home.preset=0;game.draw_view();await process_frame
	var stable=game.model.s.home.preset
	await shot("02-living")
	await click("door_corridor");ck(game.model.s.home.room=="corridor","click corridor opening")
	await click("door_bedroom");ck(game.model.s.home.room=="bedroom","corridor left door bedroom")
	await click("door_back");await click("door_bathroom");ck(game.model.s.home.room=="bathroom","corridor center bathroom")
	await click("door_back");await click("door_kitchen");ck(game.model.s.home.room=="kitchen","corridor right kitchen")
	await click("talk_qiqi");ck(game.view=="dialogue" and game.dialogue_id=="qiqi","person marker dialogue")
	await shot("03-dialogue")
	await click("back")
	ck(not game.buttons.has("map"),"no floorplan entry")
	await click("door_back");await click("door_back");await click("door_balcony")
	ck(game.model.s.home.room=="balcony","balcony linked to living")
	ck(game.model.s.home.preset==stable,"doors preserve assignments")
	await click("door_back");await click("door_workroom");await shot("05-workroom")
	await click("printer");ck(game.view=="printer","printer hotspot")
	await click("suits");ck(game.view=="suits","printer suit panel")
	await shot("06-suits")
	await click("back");ck(not game.buttons.has("collection"),"collection removed from decorated workroom")
	await click("door_back");await click("depart")
	ck(game.view=="missions","black door hosts anomaly archive")
	await click("next_page");await click("mission11");ck(game.buttons.open_portal.disabled,"locked portal cannot dispatch")
	await click("back");await click("door_workroom");await click("squad");ck(game.view=="squad","squad menu")
	await shot("08-squad")
	await click("member0");ck(game.view=="growth" and game.selected==0,"individual detail")
	var level=game.model.s.people[0].level
	await click("upgrade_level");ck(game.model.s.people[0].level==level+1,"growth purchase")
	await click("back");await click("settings");await click("display");await click("large")
	ck(game.settings.large,"nested display settings")
	await shot("09-settings")
	await click("back");await click("back");ck(game.view=="base","settings return")
	await click("door_back");await click("depart");await click("mission1");await click("open_portal");await create_timer(1.0).timeout
	ck(game.view=="battle" and game.model.active(),"door dispatches five warriors")
	game.set_process(false)
	for i in range(240):game.model.tick(1.0/60)
	game.battlefield.queue_redraw();game.refresh_battle();await shot("10-battle")
	await click("recall");ck(game.view=="result","recall result")
	await shot("11-result")
	visits=game.model.s.home.visits;await click("return")
	ck(game.view=="base" and game.model.s.home.visits==visits+1,"return triggers one assignment")
	# The fixture below checks gated UI actions, not natural progression or balance.
	game.model.s.credits=100000;game.model.s.alloy=10000;game.model.s.cores=100
	game.model.s.wins={"3":1,"5":1,"6":1};game.model.s.max_stage=7
	game.model.s.support={"laser":{"level":0,"enabled":false}}
	game.change_room("workroom",true);await click("printer");await click("room");await click("room_upgrade")
	ck(game.model.s.room==2,"space upgrade via printer")
	await click("back");await click("printer");await click("suits");await click("make2");await click("equip2")
	ck(game.model.s.people[0].suit==2,"whole suit manufacture and equip")
	await click("back");await click("door_back");await click("depart");await click("support");await click("buy_laser")
	ck(game.model.s.support.laser.level==1,"support purchased through portal")
	await click("toggle_laser");ck(not game.model.s.support.laser.enabled,"support toggle")
	for v in ["base","squad","printer","equipment","growth","suits","room","support","missions"]:
		game.navigate(v)
		for b in game.buttons.values():ck(Rect2(0,0,1600,900).encloses(b.get_global_rect()),v+" button within viewport: "+b.name)
	var report={"checks":checks,"failures":failures,"captures":captures,"fixture_currency":"only gated UI tests; progression has separate no-injection simulation"}
	var file=FileAccess.open("res://docs/asset-replacement/home-flow-test.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("EARTH HOME FLOW ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
