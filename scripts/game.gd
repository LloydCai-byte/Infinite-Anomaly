extends Node
signal changed
signal fault(message: String)
const Model = preload("res://scripts/model.gd")
const Store = preload("res://scripts/save_store.gd")

var model = Model.new()
var store = Store.new()
var debug_enabled: bool = false
var recovery_needed: bool = false
var error_message: String = ""
var last_ticks: int = 0
var save_elapsed: float = 0.0
var pulse_elapsed: float = 0.0
var transient: bool = false

func _ready() -> void:
	# Retained for the first prototype's regression suite; inactive in the apartment game.
	if not "--legacy-tests" in OS.get_cmdline_user_args():
		set_process(false)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false
	transient = "--smoke" in OS.get_cmdline_user_args() or "--capture" in OS.get_cmdline_user_args() or "--test-ui" in OS.get_cmdline_user_args()
	var errors: Array[String] = model.content.validate()
	if not errors.is_empty():
		recovery_needed = true
		error_message = "内容校验失败：" + " / ".join(errors)
	elif not transient:
		var saved: Dictionary = store.load_primary()
		if not saved.is_empty() and model.restore(saved):
			pass
		elif store.exists():
			recovery_needed = true
			error_message = "主存档无法读取。可恢复最近备份，原文件不会被自动覆盖。"
	last_ticks = Time.get_ticks_msec()

func _process(delta: float) -> void:
	pulse_elapsed += delta
	if pulse_elapsed < 0.25:
		return
	pulse_elapsed = 0.0
	pulse()

func pulse() -> void:
	var now: int = Time.get_ticks_msec()
	var elapsed: float = maxf(0.0, (now - last_ticks) / 1000.0)
	last_ticks = now
	if recovery_needed:
		return
	var before: Dictionary = model.export_state()
	var settlements: int = model.tick(elapsed)
	save_elapsed += elapsed
	if settlements > 0 or save_elapsed >= 12.0:
		if not persist():
			model.restore(before)
	changed.emit()

func persist() -> bool:
	if transient:
		return true
	model.s.last_checkpoint_utc = int(Time.get_unix_time_from_system())
	if store.save(model.export_state()):
		save_elapsed = 0.0
		return true
	recovery_needed = true
	error_message = store.error
	fault.emit(error_message)
	return false

func act(action: String, argument: String = "", extra: String = "") -> bool:
	pulse()
	if recovery_needed:
		return false
	var before: Dictionary = model.export_state()
	var success: bool = false
	match action:
		"tutorial": success = model.complete_tutorial()
		"dispatch": success = model.dispatch(argument, extra)
		"buy": success = model.buy(argument)
		"retry": success = model.retry()
		"stop": success = model.stop()
		"read":
			model.read_comic(argument)
			success = true
		"card_read":
			model.s.unread_cards.erase(argument)
			success = true
		"switch_preference":
			model.s.skip_switch_warning = argument == "true"
			success = true
		"step":
			if debug_enabled:
				model.tick(float(model.s.remaining) + 0.001, 1)
				success = true
		"resources":
			if debug_enabled:
				model.s.credits += 200
				model.s.energy += 100
				model.event("开发模式：增加测试资源。")
				success = true
	if success and not persist():
		model.restore(before)
		success = false
	changed.emit()
	return success

func recover_backup() -> bool:
	var recovered: Dictionary = store.load_backup()
	if recovered.is_empty() or not model.restore(recovered):
		error_message = "没有可用的备份，请保留存档文件以便检查。"
		return false
	recovery_needed = false
	last_ticks = Time.get_ticks_msec()
	var ok: bool = persist()
	changed.emit()
	return ok

func _notification(what: int) -> void:
	if not "--legacy-tests" in OS.get_cmdline_user_args():
		return
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		pulse()
		if not recovery_needed and persist():
			get_tree().quit()
		elif recovery_needed:
			fault.emit(error_message + "\n运行已暂停。可以保留文件后退出。")
