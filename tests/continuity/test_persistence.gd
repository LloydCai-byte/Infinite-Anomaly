extends SceneTree
const Model = preload("res://scripts/continuity/model.gd")
const Store = preload("res://scripts/save_store.gd")

func _initialize() -> void:
	var m = Model.new()
	var storehouse = Store.new("res://.local/stage1-cross-process.json")
	if "--write" in OS.get_cmdline_user_args():
		for action in ["depart","down","paper","read_note","continue"]:
			m.act(action)
		if not storehouse.save(m.export_state()):
			quit(1)
			return
		print("STAGE1_PERSIST wrote doors + clue")
	else:
		if not m.restore(storehouse.load_primary()) or m.s.node != "doors" or not m.s.flags.has("rule"):
			printerr("FAIL: cross-process restore")
			quit(1)
			return
		m.act("quiet")
		m.act("take_card")
		if m.s.cards.size() != 1 or m.s.mode != "reward":
			quit(1)
			return
		print("STAGE1_PERSIST restored and completed")
	quit()
