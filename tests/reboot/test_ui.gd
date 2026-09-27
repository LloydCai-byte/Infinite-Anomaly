extends SceneTree
const Store=preload("res://scripts/reboot/save_store.gd")
var game: Control
var checks=0
var failures=0
class FailingStore:
	extends RefCounted
	var error="模拟写盘失败"
	func save(_data: Dictionary) -> bool: return false

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("UI FAIL: "+label)

func press(id: String) -> void:
	check(game.ui.buttons.has(id),"button exists: "+id)
	if game.ui.buttons.has(id): game.ui.buttons[id].pressed.emit()

func scan_controls(node: Node) -> void:
	if node is Button:
		for state in ["normal","hover","pressed","disabled","focus"]:
			check(node.get_theme_stylebox(state) is StyleBoxTexture,"button texture "+node.name+"/"+state)
		check(node.icon!=null,"button has illustrated icon "+node.name)
		var r=node.get_global_rect()
		if node.get_parent() is not VBoxContainer:
			check(r.position.x>=0 and r.position.y>=0 and r.end.x<=1602 and r.end.y<=902,"button fits viewport "+node.name)
	for c in node.get_children(): scan_controls(c)

func _initialize() -> void: call_deferred("run")
func run() -> void:
	game=load("res://scenes/reboot/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	await process_frame
	press("slots")
	check(game.page=="slots","title to slots")
	press("new_1")
	game.ui.form.text="验收基地"
	press("create_save")
	check(game.page=="intro" and game.slot==1,"new save begins at intro")
	game.back()
	check(game.page=="pause","escape cannot bypass opening")
	press("resume")
	check(game.page=="intro","resume restores opening")
	for i in range(12): press("intro_next")
	check(game.page=="" and game.model.s.intro_done,"complete all intro dialogue")
	press("person_2")
	check(game.model.s.selected_person==2 and game.page=="profile","character button selects correct person")
	var before=game.model.s.credits
	press("upgrade_body")
	check(game.model.s.people[2].body==2 and game.model.s.credits==before-50,"live upgrade deducts exact price")
	press("back")
	press("nav_missions")
	press("mission_M02")
	check(game.model.s.selected_mission=="M02" and game.ui.buttons.prepare.disabled,"locked mission preview")
	press("mission_M01")
	press("prepare")
	press("auto_repeat")
	check(game.model.s.auto=="repeat","auto repeat choice persists")
	press("depart")
	check(game.model.active() and game.view=="battle","confirm deployment starts battle")
	var b=game.model.s.battle.duplicate(true)
	game.open("pause")
	game._process(.5)
	check(game.model.s.battle==b,"pause freezes battle")
	press("resume")
	press("base_monitor")
	press("nav_profile")
	check(not game.ui.buttons.has("upgrade_body") and game.ui.buttons.has("recall_from_growth"),"growth page has recall route while deployed")
	press("recall_from_growth")
	check(game.is_paused(),"recall confirmation pauses combat")
	press("recall_confirm")
	check(not game.model.active() and game.page=="profile","recall returns to original growth page")
	game.page=""
	game.history.clear()
	game.model.s.credits=5000
	game.model.s.alloy=100
	game.model.s.wins.M01=1
	game.model.s.wins.M02=1
	game.render()
	press("nav_printer")
	press("recipe_person_1")
	press("recipe_mk_2")
	var count=game.model.s.inventory.size()
	press("manufacture")
	check(game.model.s.inventory.size()==count+1,"printer button produces selected recipe")
	game.model.s.selected_person=1
	game.page="equipment"
	game.render()
	var id=game.model.s.inventory.back().id
	press("gear_"+id)
	press("equip")
	check(game.model.s.people[1].weapon==id,"inventory selection then explicit equip")
	game.open("settings")
	var original=game.model.s.settings.duplicate()
	press("setting_large")
	press("volume_1")
	press("back")
	check(game.model.s.settings==original,"cancel settings restores persisted values")
	var pages=["missions","ready","profile","equipment","skills","training","printer","facility","cards","dialogue","pause","slots","settings"]
	for mode in [false,true]:
		game.model.s.settings.large=mode
		for page in pages:
			game.open(page)
			await process_frame
			scan_controls(game.ui_root)
			scan_controls(game.overlay)
	game.page=""
	game.model.s.settings.large=false
	game.model.s.auto="repeat"
	game.perform("depart","M01")
	for i in range(6000):
		if not game.model.active(): break
		game.model.tick(.05)
	game.process_events()
	check(game.page=="result" and game.auto_timer>0,"victory starts chosen auto-repeat countdown")
	press("result_stats")
	check(game.auto_timer<0 and game.page=="stats","manual action cancels countdown")
	press("back")
	check(game.page=="result","stats returns to same result")
	press("back")
	check(game.view=="base" and game.model.s.result.is_empty(),"closing result returns safely to base")
	game.transient=false
	game.store=FailingStore.new()
	game.committed=game.model.s.duplicate(true)
	var current=game.model.s.duplicate(true)
	check(not game.perform("upgrade","body"),"save failure reported")
	check(game.model.s==current and game.page=="save_error","write failure rolls back full purchase")
	game.transient=true
	print("REBOOT_UI: ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
