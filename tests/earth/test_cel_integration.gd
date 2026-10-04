extends SceneTree
const Assets=preload("res://scripts/earth/assets.gd")
const C=preload("res://scripts/earth/catalog.gd")
const Model=preload("res://scripts/earth/model.gd")
const Home=preload("res://scripts/earth/home.gd")
const OUTPUT="res://art/earth-production/integration-080/captures/"
var game: Control
var checks=0
var failures=0
var captures=false
func _initialize() -> void:call_deferred("run")
func ck(value: bool,label: String) -> void:
	checks+=1
	if not value:failures+=1;printerr("FAIL "+label)
func click(id: String) -> void:
	ck(game.buttons.has(id),"interactive control exists "+id)
	if not game.buttons.has(id):return
	var pos=game.buttons[id].get_global_rect().get_center()
	var move=InputEventMouseMotion.new();move.position=pos;root.push_input(move)
	var event=InputEventMouseButton.new();event.position=pos;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true
	root.push_input(event);await process_frame
	event=event.duplicate();event.pressed=false;root.push_input(event);await process_frame
func shot(name: String) -> void:
	if not captures:return
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT+name+".png")
func run() -> void:
	captures="--capture" in OS.get_cmdline_user_args()
	root.size=Vector2i(1600,900)
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	Assets.initialize()
	ck(Assets.texture("menu").get_size()==Vector2(1920,1080),"menu delivery size")
	for id in ["dadong","fenfen","gao","wang","qiqi","xuan","antagonist"]:
		var tex=Assets.texture("portrait."+id)
		ck(tex is AtlasTexture,"portrait binds existing cel source "+id)
		ck(tex.get_width()==tex.get_height(),"square portrait "+id)
		ck(Rect2(Vector2.ZERO,tex.atlas.get_size()).encloses(tex.region),"portrait region inside original "+id)
	var m=Model.new();var before=m.s.duplicate(true)
	var growth=m.preview_growth(0,"level");var gear=m.preview_growth(0,"equipment");var talent=m.preview_growth(0,"talent")
	ck(growth.hp>m.stats(0).hp and growth.atk>m.stats(0).atk,"personal growth visible")
	ck(gear.armor>m.stats(0).armor,"equipment shows defense growth")
	ck(talent.skill_factor>m.stats(0).skill_factor and talent.atk==m.stats(0).atk,"talent distinct from base attack")
	ck(m.preview_suit(1,2).weapon==C.SUITS[1].weapons[1],"suit preview includes bound weapon")
	ck(m.s==before,"viewing previews cannot spend or mutate player state")
	m.upgrade(0,"level");ck(m.stats(0)==growth,"preview matches purchased stats")
	m.s.people[0].level=m.s.room*15
	ck(m.preview_growth(0,"level").is_empty(),"no next preview beyond room cap")
	game=load("res://scenes/earth/main.tscn").instantiate();root.add_child(game);game.transient=true
	await process_frame;await shot("01-menu")
	await click("start")
	for i in range(game.shots.size()):
		game.model.s.intro=i;game.draw_view();await process_frame
		var s=game.shots[i]
		ck(game.buttons.size()==2,"AVG controls remain minimal "+s.id)
		if s.get("presentation","")!="time_card":
			var id=s.get("fallback_asset","opening."+s.id)
			ck(Assets.texture(id)!=null,"every beat resolves image "+s.id)
			ck(not Assets.path(id).begins_with("res://assets/earth/opening/"),"no accidental old lineart "+s.id)
		if s.id=="27":ck(s.fallback_asset=="room.workroom","removed antagonist never reappears in shot27")
		if s.id in ["01","03","06","12","13","16","27","29b","30"]:await shot("intro-"+s.id)
	await click("next");ck(game.view=="base","final beat enters home")
	game.model.s.home.preset=0;game.draw_view()
	for id in Home.ROOM_IDS:
		game.change_room(id,true);await process_frame
		ck(game.model.s.home.room==id,"all seven room destinations "+id)
		await shot("room-"+id)
	game.change_room("living",true);await process_frame
	var pos=game.buttons.door_corridor.get_global_rect().get_center()
	var hover=InputEventMouseMotion.new();hover.position=pos;root.push_input(hover);await process_frame
	ck(game.hotspot_hint.text=="进入走廊","hover gives correct destination")
	await click("door_corridor");ck(game.model.s.home.room=="corridor","actual corridor opening enters corridor")
	await click("door_kitchen");ck(game.model.s.home.room=="kitchen","kitchen right door route")
	await click("door_back");await click("door_bathroom");ck(game.model.s.home.room=="bathroom","bathroom central door route")
	await click("door_back");await click("door_bedroom");ck(game.model.s.home.room=="bedroom","bedroom left door route")
	game.change_room("living",true);game.transient=false;game.fade_room();game.transient=true
	await create_timer(.3).timeout
	ck(game.transition_cover.modulate.a<.01,"room transition finishes without blocking inputs")
	await click("squad");await shot("02-squad")
	await click("member0");await shot("03-growth")
	game.model.s.credits=10000;game.model.s.alloy=1000;game.model.s.cores=100
	game.model.s.wins={"3":1,"5":1,"6":1};game.model.s.max_stage=7;game.model.s.room=3
	game.model.s.support={"laser":{"level":0,"enabled":false},"regen":{"level":0,"enabled":false},"bomb":{"level":0,"enabled":false}}
	game.change_room("workroom",true);await click("printer");await click("suits");await shot("04-suit-comparison")
	await click("make2");await click("equip2")
	ck(game.model.stats(0).weapon==C.SUITS[1].weapons[0],"manufactured whole suit equips its own weapon")
	game.navigate("support")
	for id in ["laser","regen","bomb"]:await click("buy_"+id)
	await shot("05-support")
	game.change_room("living",true);await click("depart");await shot("06-missions")
	await click("mission1");await click("open_portal");await create_timer(1.0).timeout;game.set_process(false)
	ck(game.battle_labels.has("support_laser") and game.battle_labels.has("support_regen") and game.battle_labels.has("support_bomb"),"all enabled devices have battlefield timers")
	for i in range(350):game.model.tick(1.0/60)
	game.battlefield.queue_redraw();game.refresh_battle();await shot("07-battle")
	await click("recall");await shot("08-result")
	var visits=game.model.s.home.visits
	await click("return_grow")
	ck(game.view=="growth" and game.model.s.home.visits==visits+1 and game.model.s.result.is_empty(),"result-to-growth settles once and assigns home")
	var report={"checks":checks,"failures":failures,"captures":captures,"fixture":"only UI/preview tests grant resources; natural progression tested separately"}
	var f=FileAccess.open("res://art/earth-production/integration-080/test-report.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
	print("CEL INTEGRATION ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
