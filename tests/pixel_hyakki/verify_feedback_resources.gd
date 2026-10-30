extends SceneTree
func _initialize()->void:
	var input="";var output=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--resources="):input=arg.trim_prefix("--resources=")
		if arg.begins_with("--resource-output="):output=arg.trim_prefix("--resource-output=")
	var files=JSON.parse_string(FileAccess.get_file_as_string(input));var hashes={};var missing=[]
	for path in files:
		if FileAccess.file_exists(path):hashes[path]=FileAccess.get_sha256(path)
		else:missing.append(path)
	var f=FileAccess.open(output,FileAccess.WRITE);f.store_string(JSON.stringify({"hashes":hashes,"missing":missing},"\t"));f.close()
	print("PACK_RESOURCES ",hashes.size()," found ",missing.size()," missing");quit(0 if missing.is_empty() else 1)
