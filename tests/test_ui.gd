extends SceneTree
## Drives actual Control hit testing and signals in the engine viewport.
var checks: int = 0
var failures: Array[String] = []
var main
var game

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("UI FAIL: " + message)

func click_control(control: Control) -> void:
	if not is_instance_valid(control):
		check(false,"click target exists")
		return
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = control.get_global_rect().get_center()
	event.pressed = true
	control.get_viewport().push_input(event,true)
	await process_frame
	event.pressed = false
	if is_instance_valid(control):
		control.get_viewport().push_input(event,true)
	else:
		root.push_input(event,true)
	await process_frame

func named(name_value: String) -> Control:
	return main.find_child(name_value,true,false) as Control

func run() -> void:
	game = root.get_node("Game")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	check(main.progress.get_rect().end.y < main.countdown_label.position.y,"progress indicator does not overlap countdown")
	await click_control(named("BeginGame"))
	check(game.model.s.tutorial and main.page=="missions","tutorial button registers first card and opens missions")
	await click_control(named("Dispatch_A01"))
	check(game.model.s.mode=="PUSH" and main.page=="","dispatch button starts exploration")
	await click_control(named("Nav_cards"))
	check(main.page=="cards","navigation opens collection")
	var timer_before: float = game.model.s.remaining
	game.last_ticks -= 1500
	game.pulse()
	check(game.model.s.remaining < timer_before-1,"management panel leaves timer running")
	await click_control(named("Card_A01_01"))
	check(main.page=="card_detail" and "A01_01" not in game.model.s.unread_cards,"card click opens detail and marks read")
	var credits_before: int = game.model.s.credits
	main.open_page("comics")
	main.turn_page(0)
	check(game.model.s.credits==credits_before,"comic navigation cannot award resources")
	var key = InputEventKey.new()
	key.keycode = KEY_F3
	key.pressed = true
	root.push_input(key,true)
	await process_frame
	check(main.page=="debug" and game.debug_enabled,"F3 enables development controls")
	for i in range(3):
		await click_control(named("DebugStep"))
	check(game.model.s.target=="A01_FRONT" and game.model.s.blocked=="A01_S4","UI reaches failure fallback after first three stages")
	await click_control(named("Nav_upgrades"))
	await click_control(named("Buy_action"))
	check(game.model.power()==2 and game.model.s.mode=="FARM","upgrade button purchases without automatic retry")
	await click_control(main.retry_button)
	check(game.model.s.target=="A01_S4","retry button resumes frontier")
	main.open_page("debug")
	for i in range(3):
		await click_control(named("DebugStep"))
	check(game.model.s.target=="A01_END" and "A01_08" in game.model.s.cards,"boss first-clear reached via UI")
	for i in range(15):
		await click_control(named("DebugStep"))
	check("A01" in game.model.s.completed,"full UI loop reaches gold collection")
	await click_control(named("Nav_cards"))
	await click_control(named("ReadEnding"))
	check(main.page=="ending","gold collection opens case resolution")
	await click_control(named("Nav_upgrades"))
	await click_control(named("Buy_living"))
	check(game.model.s.upgrades.living==1 and main.room.upgrades.living==1,"living upgrade changes actual room")
	main.close_page()
	check(main.room.is_visible_in_tree() and main.state_label.is_visible_in_tree(),"return to room retains task visibility")
	# Background elapsed time is measured independently of frame delta.
	var remaining_before: float = game.model.s.remaining
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
		await create_timer(1.2).timeout
		game.pulse()
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		check(game.model.s.remaining < remaining_before-0.8,"minimized game continues elapsed time")
	# Exercise transaction rollback, using only an intentionally invalid test path.
	var before: Dictionary = game.model.export_state()
	game.transient = false
	game.store = load("res://scripts/save_store.gd").new("res://data/content.json/not_a_directory.json")
	var purchased: bool = game.act("buy","display")
	check(not purchased and game.recovery_needed,"save failure pauses rather than committing")
	check(game.model.s.upgrades.display==before.upgrades.display and game.model.s.credits==before.credits,"failed purchase restores wallet and upgrade atomically")
	game.transient = true
	game.recovery_needed = false
	var file = FileAccess.open("res://.local/ui_test_report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty()},"  "))
	file.close()
	print("UI TEST RESULT: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
