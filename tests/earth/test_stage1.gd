extends SceneTree
const Model = preload("res://scripts/earth/model.gd")
const C = preload("res://scripts/earth/catalog.gd")
const Store = preload("res://scripts/reboot/save_store.gd")
var failures=0
var checks=0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("FAIL "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var model=Model.new()
	check(model.s.people.size()==5,"five warriors")
	check(C.PEOPLE.map(func(p): return p.name)==["大东老师","粉粉","高哥","老王","七七"],"locked identities")
	var store=Store.new("res://.local/earth-tests/stage1.json")
	model.s.intro=12
	check(store.save(model.s),"save opening progress")
	var restored=Model.new()
	check(restored.import_state(store.load_primary()) and restored.s.intro==12,"restore same shot")
	var invalid=model.s.duplicate(true)
	invalid.people.remove_at(4)
	check(not restored.import_state(invalid) and restored.s.people.size()==5,"reject four-person save unchanged")
	var game=load("res://scenes/earth/main.tscn").instantiate()
	root.add_child(game)
	game.transient=true
	await process_frame
	check(game.buttons.has("start") and game.buttons.has("settings"),"menu actions")
	check(game.new_game(1) and game.view=="intro","new game enters AVG")
	check(game.shots.size()==31,"30 shots plus suit insert")
	check("六个" in game.shots[1].line and "七个" in game.shots[10].line,"seventh stranger present")
	for i in range(30): game.advance_intro(1)
	check(game.view=="intro" and game.model.s.intro==30,"last beat reached")
	game.advance_intro(1)
	check(game.view=="base" and game.model.s.intro_done,"AVG enters five-person room")
	game.open_settings()
	check(game.view=="settings" and game.settings_return=="base","settings remembers return")
	print("EARTH STAGE1 ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
