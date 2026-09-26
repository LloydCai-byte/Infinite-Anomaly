extends Node
signal changed
signal event(kind: String)
const Model = preload("res://scripts/home/model.gd")
const Store = preload("res://scripts/home/checkpoints.gd")
var model = Model.new()
var store = Store.new()
var transient: bool = false
var paused: bool = false
var fault: String = ""
var save_elapsed: float = 0.0
var pulse: float = 0.0
var last_save: String = ""
var low_warning: int = 0
var invalid_checkpoint: bool = false

func _ready() -> void:
	if str(ProjectSettings.get_setting("application/run/main_scene", "")).contains("campaign") and not "--home-test" in OS.get_cmdline_user_args() and not "--home-smoke" in OS.get_cmdline_user_args() and not "--home-capture" in OS.get_cmdline_user_args():
		set_process(false)
		return
	transient = "--home-test" in OS.get_cmdline_user_args() or "--home-capture" in OS.get_cmdline_user_args() or "--home-smoke" in OS.get_cmdline_user_args()
	if not transient:
		var saved: Dictionary = store.read_latest()
		if not saved.is_empty() and model.restore(saved):
			last_save = "已读取最近存档"
		elif store.exists():
			invalid_checkpoint = true
			fault = "存档无法读取。请从备份恢复，原文件已保留。"
		else:
			persist()
	get_tree().auto_accept_quit = false

func _process(delta: float) -> void:
	if paused or fault != "" or not model.s.intro:
		return
	var was_active: bool = model.can_act()
	var result: String = model.tick(delta)
	if result != "":
		event.emit(result)
	if was_active and model.s.mode != "GAMEOVER":
		save_elapsed += delta
		if save_elapsed >= 1200.0:
			persist()
	var level: int = 2 if model.s.food <= 10 else (1 if model.s.food <= 25 else 0)
	if level > low_warning and model.can_act():
		event.emit("critical" if level == 2 else "low")
	low_warning = level
	pulse += delta
	if pulse >= 0.2:
		pulse = 0.0
		changed.emit()

func persist() -> bool:
	if transient:
		return true
	if invalid_checkpoint:
		fault = "请先恢复可用备份，原存档不会被新状态覆盖。"
		event.emit("fault")
		return false
	if model.s.mode == "GAMEOVER":
		return false
	var before: int = int(model.s.checkpoint)
	model.s.checkpoint = int(Time.get_unix_time_from_system())
	if not store.save(model.export_state()):
		model.s.checkpoint = before
		fault = store.error
		event.emit("fault")
		return false
	save_elapsed = 0.0
	last_save = Time.get_time_string_from_system().substr(0,5)
	event.emit("saved")
	return true

func reload_checkpoint() -> bool:
	if transient:
		model.new_game()
		model.s.intro = true
		fault = ""
		invalid_checkpoint = false
		paused = false
		save_elapsed = 0.0
		low_warning = 0
		event.emit("restored")
		changed.emit()
		return true
	for backup in store.backups():
		var candidate = Model.new()
		if candidate.restore(backup.state):
			model = candidate
			invalid_checkpoint = false
			fault = ""
			paused = false
			save_elapsed = 0
			low_warning = 0
			event.emit("restored")
			changed.emit()
			return true
	fault = "没有可恢复的存档。原文件已保留，请检查存档目录。"
	event.emit("fault")
	return false

func action(id: String, argument: String = "") -> bool:
	if fault != "" or paused:
		return false
	var ok: bool = false
	match id:
		"depart": ok = model.depart()
		"auto": ok = model.set_auto(not model.s.auto)
		"focus": ok = model.set_focus(argument)
		"upgrade": ok = model.upgrade(argument)
		"absorb": ok = model.absorb(argument, true) > 0
		"absorb_all":
			for card in model.s.cards.keys():
				ok = model.absorb(card, true) > 0 or ok
		"supply": ok = model.supply()
		"stage": ok = model.select_stage(int(argument))
		"intro":
			model.s.intro = true
			ok = true
	if ok:
		event.emit("departed" if id == "depart" else id)
		changed.emit()
	return ok

func quit_safely() -> void:
	if transient or model.s.mode == "GAMEOVER" or (fault == "" and persist()):
		get_tree().quit()
	elif fault != "":
		event.emit("fault")

func _notification(what: int) -> void:
	if not is_processing(): return
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_safely()
