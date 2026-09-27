extends RefCounted
## Write the whole snapshot, with checksum, flush and atomic replacement.
var path: String
var error: String = ""

func _init(save_path: String = "res://.local/player_save.json") -> void:
	path = ProjectSettings.globalize_path(save_path)

func read_path(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {}
	var parser = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(file_path)) != OK:
		return {}
	var envelope = parser.data
	if not envelope is Dictionary or not envelope.get("payload", null) is String:
		return {}
	var payload: String = envelope.payload
	if payload.sha256_text() != envelope.get("sha256", ""):
		return {}
	if envelope.get("encoding","")=="variant64":
		var decoded=bytes_to_var(Marshalls.base64_to_raw(payload))
		return decoded if decoded is Dictionary else {}
	if parser.parse(payload) != OK:
		return {}
	return parser.data if parser.data is Dictionary else {}

func load_primary() -> Dictionary:
	return read_path(path)

func load_backup() -> Dictionary:
	return read_path(path + ".bak")

func exists() -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak")

func save(snapshot: Dictionary) -> bool:
	error = ""
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if directory_error != OK:
		error = "无法创建存档目录：" + error_string(directory_error)
		return false
	# Variant bytes preserve integer types and exact IEEE float bits across a save.
	# bytes_to_var does not allow object deserialization.
	var payload: String = Marshalls.raw_to_base64(var_to_bytes(snapshot))
	var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		error = "无法写入临时存档：" + error_string(FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify({"encoding":"variant64","payload": payload, "sha256": payload.sha256_text()}))
	file.flush()
	file.close()
	if read_path(path + ".tmp").is_empty():
		error = "临时存档校验失败，原存档保留。"
		return false
	if not read_path(path).is_empty():
		var backup_error: Error = DirAccess.copy_absolute(path, path + ".bak")
		if backup_error != OK:
			error = "备份失败，取消本次保存：" + error_string(backup_error)
			return false
	var rename_error: Error = DirAccess.rename_absolute(path + ".tmp", path)
	if rename_error != OK:
		error = "存档替换失败：" + error_string(rename_error)
		return false
	return true

