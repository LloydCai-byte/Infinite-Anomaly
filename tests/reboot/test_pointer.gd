extends SceneTree

# Exercise Godot GUI hit testing with mouse events, independently of pressed.emit().
var game: Control
var checks=0
var failures=0

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("POINTER FAIL: "+label)

func point(pos: Vector2) -> void:
	var motion=InputEventMouseMotion.new()
	motion.position=pos
	motion.global_position=pos
	root.push_input(motion,true)
	for pressed in [true,false]:
		var e=InputEventMouseButton.new()
		e.position=pos
		e.global_position=pos
		e.button_index=MOUSE_BUTTON_LEFT
		e.pressed=pressed
		root.push_input(e,true)
		await process_frame

func click(id: String) -> void:
	check(game.ui.buttons.has(id),"button exists "+id)
	if game.ui.buttons.has(id):
		await point(game.ui.buttons[id].get_global_rect().get_center())

func _initialize() -> void: call_deferred("run")

func run() -> void:
	root.size=Vector2i(1280,720)
	game=load("res://scenes/reboot/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	await process_frame
	await click("slots")
	check(game.page=="slots","title opens slots by hit test")
	await click("new_1")
	check(game.page=="newsave","nested slot button receives mouse")
	await click("create_save")
	check(game.page=="intro","create enters intro")
	var behind=game.ui.buttons.person_0.get_global_rect().get_center()
	await point(behind)
	check(game.page=="intro","intro blocks underlying character button")
	for i in range(12): await click("intro_next")
	check(game.page=="" and game.model.s.intro_done,"all opening dialogue is clickable")
	await click("person_2")
	check(game.page=="profile" and game.model.s.selected_person==2,"portrait selects correct person")
	var funds=game.model.s.credits
	await click("upgrade_body")
	check(game.model.s.credits==funds-50,"growth executes once per pointer click")
	await click("back")
	await click("nav_missions")
	await click("mission_M02")
	await click("prepare")
	check(game.page=="missions","disabled locked task cannot launch")
	await click("mission_M01")
	await click("prepare")
	await click("depart")
	check(game.view=="battle" and game.model.active(),"mouse starts battle")
	await click("recall")
	check(game.page=="recall","recall confirmation opens")
	print("REBOOT_POINTER: ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
