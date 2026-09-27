extends SceneTree
const Model = preload("res://scripts/continuity/model.gd")
const Store = preload("res://scripts/save_store.gd")
var checks = 0
var failures = 0
var game: Control

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL STAGE2: " + message)

func _initialize() -> void:
	call_deferred("run")

func complete(m: RefCounted) -> void:
	for action in ["depart","down","paper","read_note","continue","quiet","take_card","put_away"]:
		m.act(action)

func model_checks() -> void:
	var m = Model.new()
	check(m.act("start_auto").is_empty(),"auto locked before first clear")
	check(m.act("peek").is_empty(),"peephole not an alternate first-clear shortcut")
	complete(m)
	check(m.s.cards.has("stair"),"first clear unlocks repeat")
	check(m.act("start_auto").get("changed",false),"start repeat")
	check(m.act("depart").is_empty(),"manual exploration cannot duplicate an active task")
	m.advance(11)
	check(m.idle_node_id() == "landing","first scene timing")
	m.advance(1)
	check(m.idle_node_id() == "stranger","second scene on boundary")
	m.act("room_bedroom")
	m.advance(12)
	check(m.idle_node_id() == "note" and m.s.room == "bedroom","room change preserves task")
	m.act("peek")
	m.advance(24)
	check(m.idle_node_id() == "threshold","five-shot loop progresses while watched")
	m.act("room_entry")
	check(m.s.idle.elapsed == 48,"closing peephole preserves elapsed")
	m.advance(132)
	check(m.s.idle.settled == 3 and m.s.box_rounds == 3 and m.s.idle.next_round == 4,"three rounds settle exactly once")
	check(m.s.inbox.get("paper") == 6 and m.s.inbox.get("brass") == 3 and m.s.inbox.get("button") == 1,"expected three-round delivery")
	check(m.s.idle.active and m.s.idle.elapsed == 0,"automatically starts next round")
	var prior = m.export_state()
	check(not m.settle_round(3) and not m.settle_round(5),"duplicate and future settlement ids refused")
	check(m.s == prior,"refused settlement cannot mutate rewards")
	m.act("claim")
	check(m.s.box_rounds == 0 and m.s.inbox.is_empty() and m.s.bag.paper == 6,"claim moves items atomically")
	check(m.s.idle.active,"claim never recalls male character")
	check(m.act("claim").is_empty() and m.s.bag.paper == 6,"double claim cannot duplicate")
	m.advance(19.5)
	m.act("recall")
	check(m.s.idle.active and m.s.idle.stop_after,"recall finishes current round")
	m.advance(40.5)
	check(not m.s.idle.active and m.s.idle.settled == 4 and m.s.box_rounds == 1,"recall includes final round then stops")
	m.advance(180)
	check(m.s.idle.settled == 4,"no reward while stopped")
	m.act("start_auto")
	m.advance(60)
	check(m.s.idle.settled == 5 and m.s.idle.next_round == 6,"restart uses next unique round")
	var resumer = Model.new()
	check(resumer.restore(m.export_state()),"idle state valid after restarts")
	var version_one = m.export_state()
	version_one.version = 1
	for field in ["room","idle","inbox","bag","box_rounds","claimed_rounds","companion_time","music_on","ambience_on","pomo"]:
		version_one.erase(field)
	check(resumer.restore(version_one),"stage one migration accepted")
	check(resumer.s.cards.has("stair") and not resumer.s.idle.active and resumer.s.inbox.is_empty(),"migration preserves card without inventing rewards")
	var bad_values = [
		["room","unknown"],["idle",null],["pomo",[]],["inbox",{"fake":1}],["bag",{"paper":-1}],
		["box_rounds",-1],["claimed_rounds",999],["music_on",2],["ambience_on","yes"],["companion_time",INF]
	]
	for pair in bad_values:
		var bad = m.export_state()
		bad[pair[0]] = pair[1]
		var before = resumer.export_state()
		check(not resumer.restore(bad),"reject malformed " + pair[0])
		check(resumer.s == before,"failed load nonmutating " + pair[0])
	for pair in [["elapsed",NAN],["elapsed",60],["elapsed",-1],["next_round",5],["settled",-1],["active","true"],["stop_after",1]]:
		var bad = m.export_state()
		bad.idle[pair[0]] = pair[1]
		check(not resumer.restore(bad),"reject invalid task " + pair[0])
	m.act("pomo_5")
	m.act("pomo_toggle")
	m.advance(300)
	check(m.s.pomo.phase == "break" and m.s.pomo.completed == 1 and m.s.pomo.remaining == 300,"focus ends once into five-minute break")
	m.advance(300)
	check(m.s.pomo.phase == "focus" and m.s.pomo.remaining == 300,"timer begins next focus automatically")
	m.act("pomo_toggle")
	var rounds_before = m.s.idle.settled
	m.advance(60)
	check(m.s.pomo.remaining == 300 and m.s.idle.settled == rounds_before+1,"timer pause does not pause exploration")
	m.act("pomo_25")
	check(m.s.pomo.remaining == 1500 and not m.s.pomo.running,"changing duration resets stopped focus")
	var before_bad_time = m.export_state()
	for delta in [-1,NAN,INF]:
		m.advance(delta)
	check(m.s == before_bad_time,"invalid elapsed time refused")
	check(Model.new().restore(m.export_state()),"long-running combined state still valid")

func click(id: String) -> void:
	var target = game.find_child(id,true,false)
	check(target is Button,"button exists " + id)
	if not target is Button:
		return
	await process_frame
	var point = target.get_global_rect().get_center()
	var motion = InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion,true)
	for pressed in [true,false]:
		var event = InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame

func keyboard(code: Key) -> void:
	var event = InputEventKey.new()
	event.pressed = true
	event.keycode = code
	root.push_input(event,true)
	await process_frame

func ui_checks() -> void:
	game = load("res://scenes/continuity/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	await process_frame
	complete(game.model)
	game.render()
	await click("Depart")
	check(game.modal == "dispatch","cleared doorway offers repeat")
	await click("StartAuto")
	check(game.model.s.idle.active,"actual click starts auto")
	game.tick_simulation(8)
	await click("ToBedroom")
	check(game.model.s.room == "bedroom" and game.model.s.idle.elapsed == 8,"room navigation preserves progress")
	await click("Heroine")
	check(is_instance_valid(game.bubble_label) and game.bubble_label.text.contains("陪你"),"heroine speaks near her face")
	await click("Heroine")
	check(game.content.find_children("SpeechBubble","",false,false).size() == 1,"repeated dialogue replaces bubble")
	game.tick_simulation(20)
	check(game.content.get_node("FullScene").texture.resource_path.ends_with("tea.png"),"daily pose changes without navigation")
	await click("Radio")
	check(game.modal == "radio","radio physical hotspot works")
	await click("MusicToggle")
	check(not game.model.s.music_on,"music toggle works")
	await click("AmbienceToggle")
	check(not game.model.s.ambience_on,"ambience independent toggle works")
	game.tick_simulation(32)
	check(game.model.s.idle.settled == 1,"radio panel does not block settlement")
	await keyboard(KEY_ESCAPE)
	await click("Timer")
	await click("Pomo5")
	await click("PomoToggle")
	game.tick_simulation(10)
	check(game.model.s.pomo.remaining == 290 and game.model.s.idle.elapsed == 10,"timer and auto run while timer panel open")
	await keyboard(KEY_ESCAPE)
	await click("BackEntry")
	await click("Peephole")
	check(game.model.s.room == "peephole" and not game.caption.visible,"actual peephole gives unobstructed split view")
	game.tick_simulation(16)
	check(game.content.get_node("IdleShot").texture.resource_path.ends_with("03.png"),"peephole advances current story shot")
	await click("Pause")
	var paused = game.model.export_state()
	game.tick_simulation(100)
	check(game.model.s == paused,"explicit pause stops both clocks and settlement")
	await click("Resume")
	await click("LeavePeephole")
	check(game.model.s.idle.elapsed == 26,"leaving peephole does not restart run")
	await click("Collection")
	game.tick_simulation(94)
	check(game.model.s.idle.settled == 3,"collection panel keeps repeat task alive")
	await click("CloseCollection")
	await click("Delivery")
	check(game.modal == "delivery" and game.model.s.box_rounds == 3,"box accessible while male away")
	await click("Claim")
	check(game.model.s.claimed_rounds == 3 and game.model.s.bag.button == 1,"actual claim includes three unique rounds")
	check(game.modal_layer.find_child("Claim",true,false).disabled,"empty box disables repeated claim")
	game.tick_simulation(60)
	check(game.model.s.box_rounds == 1 and not game.modal_layer.find_child("Claim",true,false).disabled,"open box updates when another round arrives")
	await keyboard(KEY_ESCAPE)
	await click("Depart")
	await click("Recall")
	check(game.model.s.idle.stop_after,"actual recall marks end-of-round return")
	game.tick_simulation(60)
	check(not game.model.s.idle.active and game.model.s.room == "entry","actual scheduled return")
	root.size = Vector2i(1280,800)
	await process_frame
	await click("ToBedroom")
	await click("Timer")
	check(game.modal == "timer","physical objects work after aspect-ratio change")
	game.close_modal()
	# Exercise the production frame clock instead of only stepping it directly.
	game.perform("start_auto")
	game.set_process(true)
	var frame_start = game.model.s.idle.elapsed
	await create_timer(1.2).timeout
	game.set_process(false)
	check(game.model.s.idle.elapsed > frame_start + .5,"production frame loop advances independently")
	game.perform("recall")
	game.tick_simulation(60)
	# Simulate write failure, then verify reward rollback and a visible stop.
	game.transient = false
	var block = FileAccess.open("res://.local/stage2-not-a-directory",FileAccess.WRITE)
	block.store_string("file")
	block.close()
	game.store = Store.new("res://.local/stage2-not-a-directory/checkpoint.json")
	game.last_committed = game.model.export_state()
	game.perform("start_auto")
	check(game.modal == "fault" and not game.model.s.idle.active,"failed start save rolls back and blocks play")
	game.fault = ""
	game.transient = true
	game.render()
	game.perform("start_auto")
	game.tick_simulation(59)
	var committed = game.model.export_state()
	game.transient = false
	game.tick_simulation(1)
	check(game.modal == "fault" and game.model.s == committed,"failed delivery save restores last committed state")
	check(game.model.s.idle.elapsed == 59,"failed delivery can retry same final second")
	game.queue_free()
	await process_frame

func run() -> void:
	model_checks()
	await ui_checks()
	print("STAGE2_TEST ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
