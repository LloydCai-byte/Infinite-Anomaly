extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var ok = ProjectSettings.get_setting("application/config/version")=="0.5.3-street"
	ok = ok and not FileAccess.file_exists("res://art/character-sequences/20260928/three-characters-v01/frames/male-heavy/move/0000.png")
	var game = load("res://scenes/reboot/main.tscn").instantiate()
	root.add_child(game)
	game.transient = true
	game.start_street_preview()
	var deadline = Time.get_ticks_msec()+30000
	while not game.street_preview.ready_for_play and Time.get_ticks_msec()<deadline: await process_frame
	var preview = game.street_preview
	ok = ok and preview.ready_for_play and preview.sheets.size()==3 and preview.tiles.size()==5
	if preview.ready_for_play:
		preview.set_process(false)
		preview.jump_to_boss()
		for i in range(60*90): preview.advance(1.0/60)
		ok = ok and preview.model.result=="victory"
		preview.controls.exit.pressed.emit()
		ok = ok and game.street_preview==null and game.ui.buttons.has("street_preview")
	print("STREET RELEASE PACKAGE: ","PASS" if ok else "FAIL")
	quit(0 if ok else 1)
