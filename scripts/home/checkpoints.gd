extends RefCounted
const LegacyStore = preload("res://scripts/save_store.gd")
var path: String
var error: String = ""
func _init(location: String = "user://home_v2/checkpoint.json") -> void:
	path = ProjectSettings.globalize_path(location)

func read_path(file_path: String) -> Dictionary:
	return LegacyStore.new(file_path).read_path(file_path)

func exists() -> bool:
	for suffix in ["",".bak1",".bak2",".bak3"]:
		if FileAccess.file_exists(path + suffix):
			return true
	return false

func read_latest() -> Dictionary:
	return read_path(path)

func backups() -> Array:
	var result: Array = []
	for suffix in ["",".bak1",".bak2",".bak3"]:
		var state: Dictionary = read_path(path + suffix)
		if not state.is_empty():
			result.append({"path":path+suffix,"state":state})
	return result

func save(state: Dictionary) -> bool:
	error = ""
	if state.get("mode", "") == "GAMEOVER" or float(state.get("food",0)) <= 0:
		error = "资源耗尽后的状态不会覆盖存档。"
		return false
	var err: Error = DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if err != OK:
		error = "存档目录无法写入。"
		return false
	var payload: String = JSON.stringify(state)
	var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		error = "无法创建临时存档。"
		return false
	file.store_string(JSON.stringify({"payload":payload,"sha256":payload.sha256_text()}))
	file.flush()
	file.close()
	if read_path(path + ".tmp").is_empty():
		error = "存档校验未通过。"
		return false
	for i in range(3,0,-1):
		var source: String = path if i == 1 else path + ".bak%d" % (i-1)
		if not read_path(source).is_empty():
			if DirAccess.copy_absolute(source,path+".bak%d"%i) != OK:
				error = "轮换备份失败，当前存档保留。"
				return false
	if DirAccess.rename_absolute(path + ".tmp", path) != OK:
		error = "替换存档失败，备份已保留。"
		return false
	return true

