extends Node
signal changed
signal event(kind: String)
const Model = preload("res://scripts/campaign/model.gd")
const Store = preload("res://scripts/home/checkpoints.gd")
var model = Model.new()
var storehouse = Store.new("user://campaign_v3/checkpoint.json")
var s: Dictionary:
	get: return model.s
var started = false
var paused = false
var fault = ""
var recovered = false
var has_save = false
var saved_state: Dictionary = {}
var since_save = 0.0
var auto_result = 0.0
var transient = false
var last_save_held = false

func _ready() -> void:
	transient = "--campaign-test" in OS.get_cmdline_user_args() or "--campaign-capture" in OS.get_cmdline_user_args()
	get_tree().auto_accept_quit = false
	if transient: return
	var backup_index = 0
	for candidate in storehouse.backups():
		var validator = Model.new()
		if validator.restore(candidate.state):
			saved_state = candidate.state
			has_save = true
			recovered = candidate.path != storehouse.path
			break
		backup_index += 1
	if storehouse.exists() and not has_save: fault = "当前存档与三个备份均未通过校验。文件已保留，可开启新故事。"

func start_new() -> void:
	model.new_game()
	started = true
	paused = false
	since_save = 0
	fault = ""
	s.intro = true
	if not persist(): return
	event.emit("new")
	changed.emit()

func resume_save() -> bool:
	if not has_save or not model.restore(saved_state): return false
	started = true
	paused = false
	since_save = 0
	apply_settings()
	event.emit("resume")
	changed.emit()
	return true

func _process(delta: float) -> void:
	if not started or paused: return
	var kind = model.tick(delta)
	if kind != "":
		event.emit(kind)
		changed.emit()
	if s.mode == "RESULT" and s.auto:
		auto_result += delta
		if auto_result >= 4:
			auto_result = 0
			model.advance_auto()
			event.emit("auto_next")
			changed.emit()
	else: auto_result = 0
	if s.mode not in ["WAIT","RESULT","ENDING","GAMEOVER"]:
		since_save += delta
		if since_save >= 1200:
			if persist() and not last_save_held: event.emit("saved")

func persist() -> bool:
	last_save_held = false
	if not started or s.mode == "GAMEOVER": return false
	if transient: return true
	# Keep a playable checkpoint when neither another trip nor resupply is affordable.
	if has_save and s.frontier<model.nodes.size() and s.food<=5 and s.xp<3:
		last_save_held=true
		since_save=0
		event.emit("checkpoint_held")
		return true
	s.saved_at = Time.get_datetime_string_from_system().replace("T"," ")
	if not storehouse.save(s):
		fault = storehouse.error
		paused = true
		event.emit("save_error")
		return false
	saved_state = s.duplicate(true)
	has_save = true
	since_save = 0
	fault = ""
	return true

func reload_checkpoint() -> bool:
	if transient:
		model.new_game()
		s.intro = true
		return true
	for backup in storehouse.backups():
		if model.restore(backup.state):
			saved_state = backup.state.duplicate(true)
			paused = false
			since_save = 0
			apply_settings()
			event.emit("resume")
			changed.emit()
			return true
	fault = "没有可读取的有效存档。原文件已保留。"
	return false

func apply_settings() -> void:
	AudioServer.set_bus_volume_db(0,linear_to_db(float(s.volume)))
	if not transient:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if s.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and started:
		paused = true
		event.emit("pause")
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if not started or s.mode == "GAMEOVER" or persist(): get_tree().quit()
