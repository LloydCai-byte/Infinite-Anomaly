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
		printerr("FAIL STAGE1: " + message)

func _initialize() -> void:
	call_deferred("run")

func route(m: RefCounted) -> void:
	for action in ["depart","down","paper","read_note","continue"]:
		check(not m.act(action).is_empty(),"valid route action " + action)

func model_checks() -> void:
	var m = Model.new()
	check(m.story.nodes.size() == 5,"exactly five full-scene story images")
	check(m.act("take_card").is_empty(),"cannot collect reward before story")
	check(m.act("quiet").is_empty(),"cannot jump to exit from home")
	route(m)
	check(m.s.node == "doors" and m.s.flags.has("rule"),"observation recorded")
	var snapshot = m.export_state()
	m.act("open_lit")
	check(m.s.mode == "dead" and m.s.deaths == 1,"wrong door causes death")
	check(m.s.cards.is_empty(),"death gives no card")
	check(m.act("open_lit").is_empty() and m.s.deaths == 1,"death cannot settle twice")
	check(Model.new().restore(m.export_state()),"death state is resumable")
	m.act("wake")
	check(m.s.mode == "home","wake returns home without legacy gameover")
	route(m)
	m.act("force")
	check(m.s.mode == "dead","low ability cannot force door")
	m.act("wake")
	route(m)
	m.act("quiet")
	check(m.s.node == "threshold","observation path succeeds with base ability")
	check(m.s.seen.size() == 5,"success path shows all five scenes")
	var reward = m.act("take_card")
	check(reward.first_card and m.s.cards.size() == 1,"first reward is one card")
	check(m.act("take_card").is_empty(),"double click cannot grant another settlement")
	m.act("put_away")
	route(m)
	m.act("quiet")
	reward = m.act("enter_home")
	check(not reward.first_card and m.s.cards.size() == 1 and m.s.completed_runs == 2,"replay remains one unique card")
	m.act("put_away")
	route(m)
	m.act("open_lit")
	check(m.s.cards.size() == 1,"death preserves previously collected card")
	m.act("wake")
	m.s.skills.nerve = 5
	route(m)
	m.act("force")
	check(m.s.node == "threshold","higher ability changes forced-action outcome")
	var restored = Model.new()
	check(restored.restore(snapshot),"saved scene and clue restore")
	check(restored.s.node == "doors" and restored.s.flags.has("rule"),"restore retains route position")
	for mutation in ["version","node","mode","cards","flags","skills","seen","muted","runs"]:
		var bad = snapshot.duplicate(true)
		bad[mutation] = "invalid"
		var previous = restored.export_state()
		check(not restored.restore(bad),"reject malformed " + mutation)
		check(restored.s == previous,"invalid restore is nonmutating " + mutation)
	for node_id in m.story.nodes:
		var node = m.story.nodes[node_id]
		check(ResourceLoader.exists(node.image),"scene asset " + node_id)
		for spot in node.spots:
			var r = Rect2(spot.rect[0],spot.rect[1],spot.rect[2],spot.rect[3])
			check(Rect2(0,0,1920,1080).encloses(r),"hotspot inside scene " + spot.id)
	var save = Store.new("res://.local/stage1-test-save.json")
	check(save.save(snapshot),"atomic save first write")
	m.act("take_card")
	check(save.save(m.export_state()),"atomic save replaces previous file")
	check(Model.new().restore(save.load_primary()),"primary checksum/restore")
	var backup = Model.new()
	check(backup.restore(save.load_backup()) and backup.s.node == "doors" and backup.s.runs == 1 and backup.s.flags.has("rule"),"backup preserves prior checkpoint")
	var file = FileAccess.open(save.path,FileAccess.WRITE)
	file.store_string("broken test file")
	file.close()
	check(save.load_primary().is_empty(),"corrupt primary rejected")
	check(Model.new().restore(save.load_backup()),"corrupt primary has usable backup")

func click(id: String) -> void:
	var b = game.find_child(id,true,false)
	check(b is Button,"UI button exists " + id)
	if not b is Button:
		return
	await process_frame
	var pos = b.get_global_rect().get_center()
	var motion = InputEventMouseMotion.new()
	motion.position = pos
	root.push_input(motion,true)
	for pressed in [true,false]:
		var event = InputEventMouseButton.new()
		event.position = pos
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame

func key(code: Key) -> void:
	var event = InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event,true)
	await process_frame

func run() -> void:
	model_checks()
	for name in ["Game","Home","Journey"]:
		check(not root.get_node(name).is_processing(),"legacy autoload inactive " + name)
	game = load("res://scenes/continuity/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	await process_frame
	await process_frame
	check(game.model.s.mode == "home","UI starts at home")
	check(game.content.get_node("FullScene").size == Vector2(1920,1080),"one full-screen background")
	await key(KEY_TAB)
	check(game.model.s.show_hints,"Tab reveals actual scene hotspots")
	await click("Depart")
	check(game.model.s.node == "landing" and game.model.s.mode == "story","mouse hit opens door")
	await click("down")
	check(game.model.s.node == "stranger","stairs hotspot transitions")
	await click("stranger")
	check(game.model.s.flags.has("asked"),"NPC observation works")
	check(is_instance_valid(game.bubble_label) and game.bubble_label.text.contains("看看"),"speech changes near NPC")
	await click("paper")
	await click("read_note")
	check(game.model.s.flags.has("rule"),"paper click reveals clue")
	check(game.content.get_node_or_null("PaperText") != null,"clue rendered on image separately")
	await key(KEY_ESCAPE)
	check(game.modal == "pause","Escape opens pause")
	await click("continue")
	check(game.model.s.node == "note","pause blocks background clicks")
	await click("Resume")
	await click("continue")
	check(game.model.s.node == "doors","continue reaches choices")
	await click("lit_door")
	check(game.modal == "choices","door opens local actions")
	await click("open_lit")
	check(game.modal == "death" and game.model.s.deaths == 1,"death overlay follows real clicks")
	await click("Wake")
	check(game.model.s.mode == "home","wake hotspot returns to room")
	for id in ["Depart","down","paper","continue","dark_door","quiet","take_card"]:
		await click(id)
	check(game.model.s.mode == "reward" and game.modal == "reward","successful clicks reveal card")
	await click("PutAway")
	await click("Collection")
	check(game.modal == "collection" and game.model.s.cards.size() == 1,"home cabinet contains collected card")
	await click("CloseCollection")
	await click("Pause")
	await click("Mute")
	check(game.model.s.muted,"sound setting toggles")
	await click("Resume")
	# Check logical canvas and interaction survive another aspect ratio.
	root.size = Vector2i(1280,800)
	await process_frame
	await click("Depart")
	await click("Replay")
	check(game.model.s.mode == "story","resized viewport remains interactive")
	game.queue_free()
	await process_frame
	print("STAGE1_TEST ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
