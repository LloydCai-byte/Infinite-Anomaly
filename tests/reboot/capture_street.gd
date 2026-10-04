extends SceneTree
var game: Control
var trial: Control
var failures = 0
var output = "res://art/street-preview/captures/"

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("STREET POINTER FAIL: "+label)

func click(button: Button) -> void:
	var pos = button.get_global_rect().get_center()
	var motion = InputEventMouseMotion.new()
	motion.position = pos
	root.push_input(motion)
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = pos
	event.pressed = true
	root.push_input(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)
	await process_frame

func simulate(seconds: float) -> void:
	for i in range(roundi(seconds*60)): trial.advance(1.0/60)
	trial.refresh_hud()
	trial.queue_redraw()

func shot(name: String) -> void:
	# Manual simulation bursts are not an FPS benchmark; let the render counter settle.
	await create_timer(1.15).timeout
	trial.refresh_hud()
	trial.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+name+".png")

func run() -> void:
	root.size = Vector2i(1600,900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	game = load("res://scenes/reboot/main.tscn").instantiate()
	root.add_child(game)
	game.transient = true
	game.set_process(false)
	await process_frame
	await click(game.ui.buttons.street_preview)
	trial = game.street_preview
	check(is_instance_valid(trial),"title entry mouse hit")
	if not is_instance_valid(trial): quit(1); return
	var deadline = Time.get_ticks_msec()+30000
	while not trial.ready_for_play and Time.get_ticks_msec()<deadline: await process_frame
	check(trial.ready_for_play,"threaded assets ready")
	if not trial.ready_for_play: quit(1); return
	trial.set_process(false)
	await click(trial.controls.pause)
	check(trial.model.paused,"pause mouse hit")
	await click(trial.controls.pause)
	check(not trial.model.paused,"resume mouse hit")
	await click(trial.controls.speed)
	check(trial.model.speed==2,"speed mouse hit")
	await click(trial.controls.speed)
	trial.restart()
	simulate(2.6)
	await shot("01-running")
	simulate(3.4)
	await shot("02-first-contact")
	simulate(38)
	await shot("03-long-street")
	await click(trial.controls.boss)
	check(trial.model.remaining()==1,"boss shortcut mouse hit")
	simulate(4.7)
	await shot("04-boss")
	var info = {"renderer":RenderingServer.get_video_adapter_name(),"texture_mib":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)/1048576.0,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
	var report = FileAccess.open(output+"runtime.json",FileAccess.WRITE)
	report.store_string(JSON.stringify(info,"  "))
	report.close()
	simulate(70)
	check(trial.model.result=="victory","rendered run can finish")
	await shot("05-completed")
	await click(trial.controls.restart)
	check(trial.model.remaining()==13,"restart mouse hit")
	await click(trial.controls.exit)
	check(game.street_preview==null and game.ui_root.visible,"return mouse hit")
	print("STREET CAPTURE / POINTER ",failures," failures ",JSON.stringify(info))
	quit(1 if failures else 0)
