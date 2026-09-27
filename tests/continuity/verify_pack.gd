extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var failures = 0
	if not str(ProjectSettings.get_setting("application/run/main_scene")).contains("continuity"):
		failures += 1
	for name in ["Game","Home","Journey"]:
		if root.has_node(name):
			failures += 1
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/continuity/floor.json"))
	if not data is Dictionary:
		quit(1)
		return
	for node in data.nodes.values():
		var texture = load(node.image)
		if not texture is Texture2D or texture.get_width() < 1600:
			failures += 1
	var game = load("res://scenes/continuity/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	for action in ["depart","down","paper","read_note","continue","quiet","take_card","put_away"]:
		game.perform(action)
		await process_frame
	if game.model.s.mode != "home" or not game.model.s.cards.has("stair"):
		failures += 1
	game.queue_free()
	await process_frame
	print("STAGE1_PACK_VERIFY ",failures," failures")
	quit(1 if failures else 0)
