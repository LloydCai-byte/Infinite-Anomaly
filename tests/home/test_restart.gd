extends SceneTree
const Store = preload("res://scripts/home/checkpoints.gd")
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func verify(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("RESTART FAIL: " + message)

func run() -> void:
	var home = root.get_node("Home")
	home.set_process(false)
	var token: String = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--checkpoint-test="):
			token = arg.trim_prefix("--checkpoint-test=")
	if token.is_empty() or not token.is_valid_int():
		printerr("RESTART FAIL: isolated test token required")
		quit(1)
		return
	home.store = Store.new("res://.local/restart-home-" + token + "/checkpoint.json")
	home.transient = false
	home.model.new_game()
	home.paused = false
	if "--save-session" in OS.get_cmdline_user_args():
		home.model.s.intro = true
		home.model.s.xp = 12
		home.model.upgrade("perception")
		home.model.depart()
		home.model.tick(7.0)
		home.model.s.room = "balcony"
		verify(home.persist(),"first process writes in-flight memory")
		verify(home.store.read_latest().remaining == 15.0,"checkpoint keeps exact remaining time")
	else:
		verify(home.reload_checkpoint(),"second process reads checkpoint")
		verify(home.model.s.room == "balcony" and home.model.s.intro,"restores current viewpoint and opening state")
		verify(home.model.s.mode == "MEMORY" and home.model.s.remaining == 15.0,"does not advance or restart memory while closed")
		verify(home.model.s.xp == 9 and home.model.s.skills.perception == 1,"restores paid growth exactly")
		verify(home.model.s.snapshot.stats.perception == 2,"restores departure capability snapshot")
		home.model.tick(14.9)
		verify(home.model.s.cards.is_empty(),"does not pay out early after restart")
		home.model.tick(0.2)
		verify(home.model.s.cards.get("R01",0) == 1 and home.model.s.xp == 14,"settles restored memory once")
		verify(not home.model.settle() and home.model.s.xp == 14,"restart cannot duplicate settlement")
		verify(home.persist(),"second process can save again")
		for suffix in ["", ".bak1", ".bak2", ".bak3", ".tmp"]:
			if FileAccess.file_exists(home.store.path + suffix):
				DirAccess.remove_absolute(home.store.path + suffix)
	print("HOME RESTART: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
