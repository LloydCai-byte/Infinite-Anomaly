extends SceneTree
const C=preload("res://scripts/reboot/catalog.gd")
const Story=preload("res://scripts/reboot/story_catalog.gd")
const Store=preload("res://scripts/reboot/save_store.gd")
var game: Control
var checks=0
var failures=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;printerr("CAMPAIGN UI FAIL: "+label)
func press(id: String) -> void:
	check(game.ui.buttons.has(id),"exists: "+id)
	if game.ui.buttons.has(id):
		check(not game.ui.buttons[id].disabled,"enabled: "+id)
		game.ui.buttons[id].pressed.emit()
func scan(node: Node) -> void:
	if node is Button:
		for state in ["normal","hover","pressed","disabled","focus"]:
			check(node.get_theme_stylebox(state) is StyleBoxTexture,"texture "+node.name+"/"+state)
		var rect=node.get_global_rect()
		check(rect.position.x>=0 and rect.position.y>=0 and rect.end.x<=1602 and rect.end.y<=902,"inside viewport: "+node.name)
		var planned=node.get_meta("layout_rect",Rect2())
		check(node.size.x<=planned.size.x+1 and node.size.y<=planned.size.y+1,"button text fits designed area: "+node.name+" "+str(node.size)+" vs "+str(planned.size))
	if node is TextureRect: check(node.texture!=null,"loaded artwork")
	for child in node.get_children(): scan(child)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	game=load("res://scenes/reboot/main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.transient=true
	game.model.s.intro_done=true;game.model.s.tier=3
	game.model.s.credits=99999;game.model.s.alloy=999
	for d in C.MISSIONS: game.model.s.wins[d.id]=8
	game.view="base";game.page=""
	game.render()
	press("nav_missions");press("missions_next");press("mission_M10")
	check(game.model.s.selected_mission=="M10","M10 reachable in mission selector")
	press("prepare");press("depart")
	check(game.model.active(),"late mission starts from real button")
	game.model.recall();game.go_base();game.open("skills")
	press("second_slot");press("module_regen");press("module_upgrade")
	check(game.ui.buttons.module_equip.disabled,"first learned module is already equipped")
	press("module_beam");press("module_upgrade");press("module_equip")
	press("module_regen");press("module_equip")
	check(game.model.s.people[0].module=="regen","second ability learned and equipped through UI")
	game.go_base();press("base_graduation");press("read_graduation")
	for line in Story.STORIES.graduation: press("story_next")
	check(game.page=="handoff" and not game.model.in_war(),"reading alone doesn't transition")
	press("handoff_confirm")
	check(game.page=="handoff" and game.payload.confirm and not game.model.in_war(),"first confirmation previews permanent transition")
	press("handoff_confirm")
	check(game.view=="war" and game.model.in_war(),"final confirmation begins real war")
	check(game.model.s.war.generated==4,"no free replacement army on transition")
	game.model.war_model().tick(12.1);game.model.events.clear()
	game.open("war_soldiers")
	var actor=game.model.s.war.army[0]
	game.model.war_model().damage_army(1e9,[actor]);game.model.war_model().update_originals();game.ui.refresh()
	check(game.ui.live.soldier_people[0].name.text.contains("阵亡") and game.ui.live.soldier_people[0].bar.value==0,"open soldier page refreshes permanent casualty")
	game.model.s.war.story_queue.clear()
	var before=game.model.s.war.duplicate(true)
	game.open("pause");game._process(.2)
	check(game.model.s.war==before,"pause freezes entire network")
	game.back();game.open("war_rooms");press("room_group_2");press("room_auto")
	check(not game.model.s.war.auto_send[2],"group dispatch toggle")
	game.open("war_formation");press("formation_group_1");press("formation_slot_0")
	check(game.model.s.war.formations[1][0]==1,"group formation edit")
	game.open("war_tech");game.model.s.war.science=100;press("tech_weapons")
	check(game.model.s.war.tech.weapons==1 and game.model.s.war.science==60,"research exact cost")
	game.open("war_retreat");press("war_retreat_confirm")
	check(game.page=="war_result" and not game.model.s.war.active,"retreat UI keeps result")
	press("war_result_return");game.open("war_history");press("enter_history")
	check(game.model.s.history_active and game.view=="base","historical room route")
	var snapshot=game.model.s.war.duplicate(true)
	game.model.tick(50)
	check(game.model.s.war==snapshot,"training time cannot run war")
	press("leave_history")
	check(game.view=="war" and not game.model.s.history_active,"return to unchanged war")
	# Every new page in both font sizes, including page two and full completion.
	var pages=["war_map","war_rooms","war_formation","war_tech","war_soldiers","war_cards","war_ledger","war_history","journal","pause"]
	for mode in [false,true]:
		game.model.s.settings.large=mode
		for page in pages:
			game.open(page);await process_frame;scan(game.ui_root);scan(game.overlay)
	game.model.s.war.occupied=12;game.model.s.war.ending=true
	for d in preload("res://scripts/reboot/war_catalog.gd").PLANETS: game.model.s.war.cards.append(d.id)
	game.open("war_ending");await process_frame;scan(game.overlay)
	press("ending_story")
	for line in Story.STORIES.sector_12: press("story_next")
	check(game.model.s.war.ending_read and game.page=="war_ending","ending closes and remains accessible")
	game.perform("history",true)
	game.model.s.tier=4
	for mode in [false,true]:
		game.model.s.settings.large=mode
		for page in ["missions","cards","facility","modules","printer","graduation","handoff","journal"]:
			game.payload={};game.open(page);await process_frame;scan(game.ui_root);scan(game.overlay)
	game.model.s.settings.large=false
	game.perform("history",false)
	var save=Store.new("user://campaign-ui-resume.json")
	check(save.save(game.model.s),"war state atomically saved")
	var reloaded=preload("res://scripts/reboot/model.gd").new()
	check(reloaded.import_state(save.load_primary()),"war state loaded")
	check(reloaded.s.war.ending_read and reloaded.s.war.tech.weapons==1,"ending and research survive save")
	print("CAMPAIGN_UI: ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
