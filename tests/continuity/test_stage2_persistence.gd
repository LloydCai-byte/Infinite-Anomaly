extends SceneTree
const Model = preload("res://scripts/continuity/model.gd")
const Store = preload("res://scripts/save_store.gd")
var errors = 0

func check(ok: bool, label: String) -> void:
	if not ok:
		errors += 1
		printerr("FAIL STAGE2_PERSIST: "+label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var old_store = Store.new("user://continuity_stage1/checkpoint.json")
	if "--seed-old" in OS.get_cmdline_user_args():
		var m = Model.new()
		for id in ["depart","down","paper","continue","quiet","take_card","put_away"]:
			m.act(id)
		var old = m.export_state()
		old.version = 1
		for field in ["room","idle","inbox","bag","box_rounds","claimed_rounds","companion_time","music_on","ambience_on","pomo"]:
			old.erase(field)
		check(old_store.save(old),"prepare real stage-one save")
	else:
		var original = FileAccess.get_file_as_bytes(old_store.path)
		var game = load("res://scenes/continuity/main.tscn").instantiate()
		root.add_child(game)
		game.set_process(false)
		await process_frame
		check(game.fault == "" and not game.transient,"normal production persistence active")
		if "--write" in OS.get_cmdline_user_args():
			check(game.model.s.cards.has("stair") and game.model.s.version == 2,"migrated first-clear card")
			game.model.act("start_auto")
			game.model.advance(119.75)
			game.model.act("peek")
			game.model.act("pomo_5")
			game.model.act("pomo_toggle")
			game.model.act("music")
			check(game.save_progress(),"write mid-round with pending delivery")
			check(game.model.s.idle.settled == 1 and game.model.s.idle.elapsed == 59.75,"save exact round boundary remainder")
		elif "--read" in OS.get_cmdline_user_args():
			check(game.model.s.room == "peephole" and game.model.s.idle.elapsed == 59.75,"restore viewing position and elapsed time")
			check(game.model.s.box_rounds == 1 and game.model.s.inbox.paper == 2,"first round already delivered exactly once")
			check(not game.model.s.music_on and game.model.s.pomo.running,"restore audio and running timer")
			game.tick_simulation(.25)
			check(game.model.s.idle.settled == 2 and game.model.s.box_rounds == 2 and game.model.s.inbox.paper == 4,"next quarter second delivers only second round")
			game.perform("claim")
			check(game.model.s.bag.paper == 4 and game.model.s.box_rounds == 0,"claim persisted through actual UI transaction")
		elif "--verify-claim" in OS.get_cmdline_user_args():
			check(game.model.s.bag.paper == 4 and game.model.s.claimed_rounds == 2 and game.model.s.inbox.is_empty(),"claimed inventory persists without re-delivery")
			check(game.model.s.idle.elapsed == 0 and game.model.s.pomo.remaining == 299.75,"no fabricated offline time on new process")
			game.tick_simulation(60)
			check(game.model.s.idle.settled == 3 and game.model.s.inbox.paper == 2 and game.model.s.inbox.button == 1,"third round uses correct next id after two restarts")
		check(FileAccess.get_file_as_bytes(old_store.path) == original,"old stage-one file untouched")
		game.queue_free()
		await process_frame
	print("STAGE2_PERSIST ",OS.get_cmdline_user_args(),"; ",errors," failures")
	quit(1 if errors else 0)
