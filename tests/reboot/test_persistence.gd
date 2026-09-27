extends SceneTree
const Store=preload("res://scripts/reboot/save_store.gd")
var failures=0
var checks=0
var game: Control
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("PERSIST FAIL: "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	game=load("res://scenes/reboot/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	await process_frame
	var args=OS.get_cmdline_user_args()
	var oracle=Store.new("user://reboot-tests/oracle.json")
	if "write" in args:
		game.model.reset("跨进程验收")
		game.model.s.intro_done=true
		game.slot=1
		game.store=game.slot_store(1)
		game.commit()
		game.perform("depart","M01")
		for i in range(180): game.model.tick(.05)
		game.model.events.clear()
		check(game.commit(),"mid-battle save")
		for i in range(100): game.model.tick(.05)
		check(oracle.save(game.model.s),"expected next five seconds")
		var copy=game.model.s.duplicate(true)
		copy.base_name="备份完整记录"
		game.slot_store(2).save(copy)
		copy.base_name="主档完整记录"
		game.slot_store(2).save(copy)
		var f=FileAccess.open(game.slot_store(2).path,FileAccess.WRITE)
		f.store_string("corrupt for recovery test")
		f.close()
	elif "read" in args:
		check(game.load_game(1) and game.model.active(),"restart resumes an active deployment")
		for i in range(100): game.model.tick(.05)
		check(game.model.s.battle==oracle.load_primary().battle,"cross-process simulation remains bit-identical")
		check(not game.load_game(2) and game.page=="recovery","corrupt file routes to recovery instead of reset")
		game.ui.buttons.recover_backup.pressed.emit()
		check(game.model.s.base_name=="备份完整记录","explicit restore loads correct previous snapshot")
		check(game.load_game(1),"switch back to independent slot")
		while game.model.active():
			game.model.tick(.05)
			game.model.events.clear()
		check(game.commit(),"save fully settled result")
	elif "again" in args:
		check(game.load_game(1) and game.page=="result","settlement survives restart")
		check(game.model.s.credits==250 and game.model.s.alloy==11 and game.model.s.wins.M01==1,"exact rewards persisted without replay")
		game.model.tick(300)
		check(game.model.s.credits==250 and game.model.s.wins.M01==1,"inactive result cannot issue extra rewards")
		game.go_base()
		check(game.load_game(1) and game.page=="" and game.view=="base","return state persists")
	print("REBOOT_PERSIST ",args,": ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
