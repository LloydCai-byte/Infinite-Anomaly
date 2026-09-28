extends SceneTree
var checks=0
var failures=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;printerr("PACK FAIL: "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	check(ProjectSettings.get_setting("application/config/version")=="0.5.1-campaign","package version")
	check(ProjectSettings.get_setting("application/run/main_scene")=="res://scenes/reboot/main.tscn","package entry")
	check(not FileAccess.file_exists("res://tests/reboot/test_campaign.gd"),"test fixtures excluded")
	check(not FileAccess.file_exists("res://docs/reboot-war/feishu-progress.xml"),"authoring documents excluded")
	var art=load("res://scripts/reboot/art.gd");art.initialize()
	for id in art.manifest:
		if not art.manifest[id] is Dictionary or not art.manifest[id].has("frames"): continue
		for index in range(art.manifest[id].frames.size()):
			var frame=art.frame(id,index)
			check(frame!=null and frame.atlas!=null and frame.region.size.x>0 and frame.region.size.y>0,"packed animation "+id+"/"+str(index))
	for d in load("res://scripts/reboot/catalog.gd").MISSIONS: check(art.background(d.bg)!=null,"packed training background "+d.id)
	for d in load("res://scripts/reboot/war_catalog.gd").PLANETS: check(art.background(d.bg)!=null,"packed planet background "+d.id)
	var game=load("res://scenes/reboot/main.tscn").instantiate();root.add_child(game);game.set_process(false)
	game.transient=true;game.model.s.intro_done=true;game.view="base";game.page="";game.render()
	for d in load("res://scripts/reboot/catalog.gd").MISSIONS: game.model.s.wins[d.id]=8
	game.model.s.reveal_read=true
	check(game.perform("graduate"),"pack transition executes")
	for i in range(130): game.model.tick(.1);game.model.events.clear()
	check(game.model.s.war.landed>=4 and game.model.war_model().conservation(),"pack room completes first drop")
	game.open("war_rooms");check(game.ui.buttons.has("room_original"),"pack room interface loads")
	game.open("war_formation");check(game.ui.buttons.has("formation_slot_3"),"pack formation interface loads")
	game.open("war_tech");check(game.ui.buttons.has("tech_logistics"),"pack technology interface loads")
	await process_frame
	print("CAMPAIGN_PACK: ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
