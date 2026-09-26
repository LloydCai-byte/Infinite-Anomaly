extends SceneTree
var checks=0
var failures=0
var game: Control
var journey: Node

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL UI: "+message)

func press(id: String) -> void:
	var b=game.find_child(id,true,false)
	check(b is Button,"button exists: "+id)
	if b is Button:
		check(not b.disabled,"button available: "+id)
		if not b.disabled: b.pressed.emit()

func _initialize() -> void: call_deferred("run")

func run() -> void:
	journey=root.get_node("Journey")
	game=load("res://scenes/campaign/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	check(game.page=="title","starts at title")
	press("NewGame")
	check(game.modal=="intro" and journey.paused,"intro paused")
	press("Begin")
	check(game.modal=="" and not journey.paused,"begins in apartment")
	journey.paused=true
	for room in ["entry","hall","kitchen","bathroom","bedroom","desk","balcony"]:
		game.change_room(room)
		check(journey.s.room==room,"room navigation: "+room)
		check(game.spots.size()>0,"interactive objects in "+room)
	game.change_room("entry")
	game.activate("door")
	press("Manual")
	await create_timer(1.2).timeout
	check(journey.s.mode=="EXPLORE" and game.page=="explore","door enters actual outside scene")
	game.inspect_point(0)
	game.inspect_point(1)
	journey.s.timer=3
	press("Choose")
	check(game.modal=="choices","action choices after inspection")
	press("Choice_perception")
	check(journey.s.mode=="RESULT" and game.modal=="result","success returns with memory")
	press("ResultContinue")
	check(journey.s.mode=="HOME" and journey.s.selected==1,"continue returns home and selects frontier")
	press("Phone")
	var previous: Button = null
	for skill in ["perception","combat","survival"]:
		var upgrade: Button = game.find_child("Upgrade_"+skill,true,false)
		if previous: check(upgrade.position.y >= previous.position.y + previous.size.y,"phone upgrades have separate clickable rows")
		previous = upgrade
	press("Upgrade_perception")
	check(journey.model.stat("perception")==2,"upgrade applied from phone")
	press("ClosePhone")
	game.show_door()
	press("Stage0")
	press("Auto")
	check(journey.s.mode=="AUTO","known stage auto starts")
	journey.model.tick(15)
	journey.event.emit("result")
	check(game.modal=="result","auto result displayed")
	game.show_pause()
	press("Resume")
	check(game.modal=="result","resuming pause restores outstanding result")
	journey.paused=true
	journey.model.advance_auto()
	journey.event.emit("auto_next")
	check(journey.s.mode=="WAIT","auto stops at unseen second scene")
	game.show_monitor()
	press("TakeControl")
	check(game.page=="explore" and journey.s.mode=="EXPLORE","monitor transfers to first-person exploration")
	game.confirm_withdraw()
	press("Retreat")
	check(journey.s.mode=="HOME","withdrawal usable")
	journey.s.xp=12
	journey.s.food=50
	game.show_supply()
	press("Supply")
	check(journey.s.food==85 and journey.s.xp==9,"supply purchase from fridge")
	press("CloseSupply")
	game.show_memories(0)
	check(game.modal=="memories","physical memory book")
	press("CloseMemories")
	game.show_pause()
	press("TextSpeed")
	check(journey.s.text_speed==0,"instant text option")
	press("Motion")
	check(not journey.s.motion,"reduced motion option")
	press("Resume")
	check(not journey.paused and game.modal=="","resume from pause")
	journey.paused=true
	journey.s.mode="GAMEOVER"
	game.show_gameover()
	press("Reload")
	check(journey.s.mode=="HOME","gameover reload works")
	journey.s.mode="ENDING";journey.s.frontier=9
	game.show_ending()
	for i in 4: press("EndingNext")
	check(journey.s.ending_seen and game.modal=="credits","one conclusion plus credits")
	print("CAMPAIGN_UI ",checks," checks; ",failures," failures")
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
