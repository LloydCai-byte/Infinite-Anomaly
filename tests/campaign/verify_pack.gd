extends SceneTree
var failed=false

func _initialize() -> void: call_deferred("run")

func run() -> void:
	if root.has_node("Game") or root.has_node("Home") or not root.has_node("Journey"):
		printerr("FAIL PACK: release project configuration was not loaded")
		failed=true
	if FileAccess.file_exists("res://art/production-v3/prompts.json"):
		printerr("FAIL PACK: development references are visible")
		failed=true
	var manifest=JSON.parse_string(FileAccess.get_file_as_string(OS.get_executable_path().get_base_dir().path_join("files.json")))
	for path in manifest:
		if not FileAccess.file_exists(path):
			printerr("FAIL PACK: missing "+path)
			failed=true
		if path.ends_with(".png") or path.ends_with(".wav"):
			if ResourceLoader.load(path)==null:
				printerr("FAIL PACK: resource failed "+path)
				failed=true
	print("CAMPAIGN_PACK ",manifest.size()," files verified; ","FAILED" if failed else "OK")
	quit(1 if failed else 0)
