extends SceneTree
var failures=0
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1920,1080)
	var game=load("res://scenes/earth/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	if not (game.stage01_preview and game.transient and game.view=="battle" and game.model.active()):
		failures+=1;printerr("FAIL preview flag / transient / direct stage entry")
	for i in range(5):
		if not game.buttons.has("preview_segment_%d"%i): failures+=1
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("D:/无限异常/art/earth-production/revision-010/captures/package-preview-entry.png")
	var report=FileAccess.open("D:/无限异常/docs/revision-20261002/preview-entry-test.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"version":ProjectSettings.get_setting("application/config/version"),"failures":failures,"preview":game.stage01_preview,"transient":game.transient,"view":game.view},"  "));report.close()
	print("FIRST STAGE LAUNCHER: ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
