extends SceneTree
const Model = preload("res://scripts/model.gd")
const Store = preload("res://scripts/save_store.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var store = Store.new("res://.local/session_test.json")
	var model = Model.new()
	if "--save-session" in OS.get_cmdline_user_args():
		model.new_game(1337)
		model.complete_tutorial()
		model.dispatch("A01")
		model.tick(12.5)
		if not store.save(model.export_state()):
			printerr("SESSION FAIL: initial save")
			quit(1)
			return
		print("SESSION SAVE: stage 2, 17.5 seconds remaining, 20 credits")
		quit(0)
		return
	var ok: bool = model.restore(store.load_primary())
	ok = ok and model.s.target=="A01_S2" and is_equal_approx(model.s.remaining,17.5) and model.s.credits==20
	model.tick(17.5)
	ok = ok and model.s.target=="A01_S3" and model.s.credits==40 and model.s.energy==10
	ok = ok and model.s.claimed.count("A01_S1")==1 and model.s.claimed.count("A01_S2")==1
	ok = ok and not model.settle(int(model.s.settled_serial))
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(store.path+suffix):
			DirAccess.remove_absolute(store.path+suffix)
	print("SESSION RESTORE: preserved partial progress, no offline credit, no duplicate rewards" if ok else "SESSION FAIL: restore mismatch")
	quit(0 if ok else 1)
