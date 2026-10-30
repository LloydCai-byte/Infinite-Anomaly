extends "res://scripts/reboot/save_store.gd"
## Self-contained compressed snapshots; legacy JSON/Variant snapshots remain readable.
## Synchronous writes verify the exact bytes before replacing the primary file.
const ENCODING="variant64-zstd"
const MAX_RAW_BYTES=536870912
var verified_hash=""

func read_path(file_path:String)->Dictionary:
	if not FileAccess.file_exists(file_path):return {}
	var parser=JSON.new()
	if parser.parse(FileAccess.get_file_as_string(file_path))!=OK:return {}
	var envelope=parser.data
	if not envelope is Dictionary or envelope.get("encoding","")!=ENCODING:return super.read_path(file_path)
	var payload=envelope.get("payload")
	var size=envelope.get("raw_bytes",0)
	if not payload is String or payload.sha256_text()!=envelope.get("sha256",""):return {}
	if not (size is int or size is float) or size!=int(size) or size<=0 or size>MAX_RAW_BYTES:return {}
	var raw=Marshalls.base64_to_raw(payload).decompress(int(size),FileAccess.COMPRESSION_ZSTD)
	if raw.size()!=int(size):return {}
	var data=bytes_to_var(raw)
	return data if data is Dictionary else {}

func save(snapshot:Dictionary)->bool:
	error=""
	if snapshot.is_empty():error="存档为空，原档保留。";return false
	var directory_error=DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if directory_error!=OK:
		error="无法创建存档目录："+error_string(directory_error);return false
	var raw=var_to_bytes(snapshot)
	if raw.is_empty() or raw.size()>MAX_RAW_BYTES:
		error="存档数据超出支持范围，原档保留。";return false
	var packed=raw.compress(FileAccess.COMPRESSION_ZSTD)
	if packed.is_empty():error="存档压缩失败，原档保留。";return false
	var payload=Marshalls.raw_to_base64(packed)
	var encoded=JSON.stringify({"encoding":ENCODING,"raw_bytes":raw.size(),"payload":payload,"sha256":payload.sha256_text()})
	var file=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null:error="无法写入临时存档："+error_string(FileAccess.get_open_error());return false
	file.store_string(encoded);file.flush();file.close()
	# The encoded snapshot was produced in this synchronous call. Comparing every
	# written byte avoids decoding a second full inventory just to verify the write.
	if FileAccess.get_file_as_string(path+".tmp")!=encoded:
		error="临时存档校验失败，原存档保留。";return false
	var primary_hash=FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
	var valid_primary=not primary_hash.is_empty() and (primary_hash==verified_hash or not read_path(path).is_empty())
	if valid_primary:
		var backup_error=DirAccess.copy_absolute(path,path+".bak")
		if backup_error!=OK or FileAccess.get_sha256(path+".bak")!=primary_hash:
			error="备份失败，取消本次保存。";return false
	var rename_error=DirAccess.rename_absolute(path+".tmp",path)
	if rename_error!=OK:
		error="存档替换失败："+error_string(rename_error);return false
	verified_hash=encoded.sha256_text()
	return true
