extends SceneTree
const Model = preload("res://scripts/containment/model.gd")
const Store = preload("res://scripts/save_store.gd")
var failures = 0
var checks = 0
var game: Control
class FailingStore:
	extends RefCounted
	var error = "模拟磁盘写入失败"
	func save(_snapshot: Dictionary) -> bool: return false

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("PERSIST FAIL: "+label)

func corrupt(path: String) -> void:
	var file = FileAccess.open(path,FileAccess.WRITE)
	file.store_string("broken-test-record")
	file.close()

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	game = load("res://scenes/containment/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	await process_frame
	var args = OS.get_cmdline_user_args()
	if "write" in args:
		game.load_slot(1,true)
		for id in ["depart","down","paper","read_note","continue","seam","verify","contain:boundary","return_success","put_away","auto:M01"]: game.perform(id)
		game.tick_simulation(17.5)
		var snapshot = game.model.export_state()
		snapshot.saved_at = Time.get_unix_time_from_system()-95
		check(game.store.save(snapshot),"write active partial round")
		check(game.model.s.idle.elapsed==17.5,"partial progress saved")
		var storage = game.slot_store(2)
		var other = Model.new()
		other.s.last_line = "backup-marker"
		check(storage.save(other.export_state()),"write backup candidate")
		other.s.last_line = "primary-marker"
		check(storage.save(other.export_state()),"rotate backup")
		corrupt(storage.path)
		var broken = game.slot_store(3)
		broken.save(other.export_state())
		broken.save(other.export_state())
		corrupt(broken.path)
		corrupt(broken.path+".bak")
	elif "read" in args:
		game.load_slot(1)
		check(game.fault=="" and game.model.s.cards.M01.progress==3,"restart settles exactly two elapsed rounds")
		check(game.model.s.idle.elapsed>=22.5 and game.model.s.idle.elapsed<30,"restart preserves leftover time")
		check(game.model.s.box_rounds==2 and game.model.s.inbox.item_0==11,"restart exact resources")
		var expected = game.model.export_state()
		game.load_slot(2)
		check(game.fault=="" and game.model.s.last_line=="backup-marker","corrupted primary recovers valid backup")
		check(game.model.s.cards.is_empty(),"slots independent")
		game.load_slot(3)
		check(game.load_fault and game.modal=="fault","both bad records block load")
		check(FileAccess.get_file_as_string(game.slot_store(3).path)=="broken-test-record","bad records not overwritten")
		game.load_slot(1)
		check(game.model.s.cards.M01.progress==expected.cards.M01.progress,"second read does not duplicate offline rewards")
		var previous = game.model.export_state()
		game.store = FailingStore.new()
		game.perform("claim")
		check(game.model.s==previous and game.modal=="fault","write failure rolls claim back atomically")
	elif "again" in args:
		game.load_slot(1)
		check(game.model.s.cards.M01.progress==3 and game.model.s.box_rounds==2,"second process does not duplicate offline payout")
		check(game.model.s.inbox.item_0==11 and game.model.s.bag.is_empty(),"failed claim stays uncommitted across restart")
		game.perform("recall")
		game.tick_simulation(45)
		check(not game.model.s.idle.active and game.model.s.cards.M01.progress==4,"loaded idle task completes recall")
		game.load_slot(1)
		check(not game.model.s.idle.active and game.model.s.cards.M01.progress==4,"recalled state survives another load")
		game.load_slot(3,true)
		check(game.fault=="" and game.model.s.cards.is_empty(),"fresh start replaces broken slot only after archiving")
		var dir = DirAccess.open(game.store.path.get_base_dir())
		var archived = false
		for name in dir.get_files():
			if name.begins_with("archive-slot3-") and FileAccess.get_file_as_string(game.store.path.get_base_dir().path_join(name))=="broken-test-record": archived = true
		check(archived,"original corrupt bytes retained in archive")
	else:
		check(false,"phase required")
	game.queue_free()
	await process_frame
	print("PERSIST_TEST ",args," ",checks," checks, ",failures," failures")
	quit(0 if failures==0 else 1)
