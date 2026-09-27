extends SceneTree
var failures = 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL STAGE2_PACK: "+label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	check(ProjectSettings.get_setting("application/config/version") == "0.2.2-stage2","new release version")
	for name in ["Game","Home","Journey"]:
		check(not root.has_node(name),"no old autoload " + name)
	for id in ["entry","reading","tea","peephole"]:
		check(load("res://assets/continuity/companion/"+id+".png") is Texture2D,"companion asset " + id)
	for id in ["quiet-room","bell"]:
		check(load("res://assets/continuity/audio/"+id+".wav") is AudioStreamWAV,"audio asset " + id)
	var game = load("res://scenes/continuity/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	await process_frame
	for action in ["depart","down","paper","read_note","continue","quiet","take_card","put_away","start_auto","room_bedroom"]:
		game.perform(action)
	game.tick_simulation(180)
	check(game.model.s.idle.settled == 3 and game.model.s.inbox.paper == 6,"three rounds in actual pack")
	game.perform("room_entry")
	game.perform("peek")
	check(game.content.get_node_or_null("IdleShot") != null,"pack peephole view")
	game.perform("claim")
	check(game.model.s.bag.paper == 6 and game.model.s.inbox.is_empty(),"pack claim")
	game.queue_free()
	await process_frame
	print("STAGE2_PACK_VERIFY ",failures," failures")
	quit(1 if failures else 0)
