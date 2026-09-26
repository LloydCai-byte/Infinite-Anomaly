extends SceneTree
var failures: Array[String] = []
var checks: int = 0
var app

func _initialize() -> void:
	call_deferred("run")

func verify(value: bool, text: String) -> void:
	checks+=1
	if not value:
		failures.append(text)
		printerr("UI FAIL: "+text)

func frame() -> void:
	await process_frame
	await process_frame

func press_named(id: String) -> bool:
	var node = app.find_child(id,true,false)
	if node is Button and not node.disabled:
		node.pressed.emit()
		await frame()
		return true
	return false

func key(value: Key) -> void:
	var event=InputEventKey.new()
	event.keycode=value
	event.pressed=true
	app._unhandled_key_input(event)
	await frame()

func run() -> void:
	var home=root.get_node("Home")
	home.set_process(false)
	home.model.new_game()
	app=load("res://scenes/home/main.tscn").instantiate()
	root.add_child(app)
	await frame()
	verify(app.overlay_kind=="intro","opening explains the home")
	verify(await press_named("Begin"),"start button connected")
	verify(home.model.s.intro and app.overlay_kind=="","start clears overlay")
	for id in app.Room.ROOMS:
		app.change_room(id,false)
		await frame()
		verify(app.room.background.texture!=null,"room texture "+id)
		verify(app.room.spots().size()>0,"room has navigation "+id)
	app.change_room("entry",false)
	await key(KEY_P)
	verify(app.overlay_kind=="phone","P opens phone")
	verify(await press_named("PhoneTab_skills"),"phone growth tab")
	verify(app.overlay.page=="skills","growth page selected")
	verify(not await press_named("Skill_perception_0"),"unaffordable node disabled")
	home.model.s.xp=20
	app.overlay.render()
	verify(await press_named("Skill_perception_0"),"affordable growth node")
	verify(home.model.s.skills.perception==1 and home.model.s.xp==17,"upgrade affects gameplay once")
	verify(await press_named("Focus_combat"),"select alternative route")
	verify(home.model.s.focus=="combat","route focus binding")
	await key(KEY_P)
	verify(app.overlay_kind=="","P closes phone")
	app.activate("door","")
	await frame()
	verify(app.overlay_kind=="door","door click opens memory reader")
	verify(await press_named("Depart"),"departure button connected")
	verify(home.model.s.mode=="MEMORY" and home.model.s.generation==2,"departure starts a prior-self memory")
	verify(app.overlay_kind=="" and app.room.room_id=="entry","departure returns to home viewpoint")
	home.model.tick(50)
	home.event.emit("settled")
	await frame()
	verify(home.model.s.cards.R01==1,"first failure yields retained memory")
	app.open_phone()
	await frame()
	await press_named("PhoneTab_memories")
	verify(await press_named("Memory_R01"),"owned memory opens detail")
	verify(app.overlay.selected=="R01","detail bound to selected memory")
	verify(not await press_named("AbsorbSelected"),"unique memory cannot be consumed")
	home.model.s.cards.R01=3
	app.overlay.render()
	verify(await press_named("AbsorbSelected"),"duplicate absorption button connected")
	verify(home.model.s.cards.R01==1,"absorption keeps final copy")
	app.overlay.memory_requested.emit(0)
	await frame()
	verify(app.overlay_kind=="door" and app.overlay.selected_index==0,"card opens archived memory")
	verify(app.overlay.caption.text==home.model.s.result.text,"archive text matches its own memory")
	app.open_phone()
	await frame()
	await press_named("PhoneTab_supply")
	home.model.s.food=55.0
	home.model.s.xp=3
	app.overlay.render()
	verify(await press_named("Supply"),"supply button connected")
	verify(home.model.s.food==80 and home.model.s.xp==0,"supply spends and replenishes exact values")
	await key(KEY_ESCAPE)
	await key(KEY_ESCAPE)
	verify(app.overlay_kind=="pause" and home.paused,"Escape pause freezes simulation")
	verify(await press_named("Resume"),"resume button")
	verify(not home.paused,"resume unpauses")
	home.model.s.food=0.001
	home._process(1.0)
	await frame()
	verify(app.overlay_kind=="gameover","resource zero opens Game Over")
	verify(await press_named("LoadCheckpoint"),"checkpoint recovery button")
	verify(home.model.s.food==100 and app.overlay_kind=="","isolated recovery returns playable home")
	home.model.new_game()
	home.event.emit("restored")
	await frame()
	verify(app.overlay_kind=="intro","initial checkpoint restores its opening flow")
	verify(await press_named("Begin") and home.model.s.intro,"initial checkpoint can resume time")
	app.clear_overlay()
	app.queue_free()
	await frame()
	var f=FileAccess.open("res://.local/home_ui_report.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	f.close()
	print("HOME UI: %d checks, %d failures"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
