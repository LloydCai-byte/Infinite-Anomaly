extends SceneTree
const Model=preload("res://scripts/reboot/model.gd")
const Store=preload("res://scripts/reboot/save_store.gd")
const C=preload("res://scripts/reboot/catalog.gd")
var checks=0
var failures=0
var game: Control

class FailingStore:
	extends RefCounted
	var error="模拟写盘失败"
	func save(_data: Dictionary) -> bool: return false

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("EQUIPMENT FAIL: "+label)

func fixture(role: int, slot: String) -> RefCounted:
	var m=Model.new()
	m.s.tier=2
	m.s.credits=517
	m.s.alloy=206
	m.s.intro_done=true
	m.s.selected_person=role
	m.item(m.s.people[role][slot]).level=6
	m.s.inventory.append({"id":"spare","role":role,"slot":slot,"mk":1,"level":1})
	return m

func model_checks() -> void:
	for role in range(4):
		for slot in ["weapon","armor"]:
			var m=fixture(role,slot)
			var worn_id=m.s.people[role][slot]
			var before=m.s.duplicate(true)
			var current=m.stats(role)
			var spare=m.item("spare")
			var preview=m.stats(role,spare)
			var cost=m.gear_upgrade_cost("spare")
			check(cost=={"credits":80 if slot=="weapon" else 65,"alloy":1},"selected Lv.1 price, not worn Lv.6")
			check(m.s==before,"stat preview is read-only")
			check(m.upgrade_gear(role,"spare"),"upgrade selected spare "+str(role)+slot)
			check(m.item("spare").level==2 and m.item(worn_id).level==6,"only selected item gains one level")
			check(m.s.credits==517-cost.credits and m.s.alloy==205,"selected price charged exactly once")
			check(m.stats(role)==current and m.s.people==before.people,"spare upgrade does not silently equip or weaken wearer")
			for original in before.inventory:
				if original.id!="spare": check(m.item(original.id)==original,"other inventory items unchanged")
			var improved=m.stats(role,m.item("spare"))
			if slot=="weapon": check(improved.atk>preview.atk and is_equal_approx(improved.atk-preview.atk,C.PEOPLE[role].atk*.1),"weapon actually gains attack")
			else: check(improved.armor==preview.armor+6 and improved.hp>preview.hp,"armor gains armor and health")
			check(m.equip(role,"spare") and m.stats(role)==improved,"equip applies exactly the previewed stats")
			check(m.item(worn_id)==before.inventory[role*2+(0 if slot=="weapon" else 1)],"previous worn item retains level and Mk")
			m.s.credits=10000
			m.s.alloy=1000
			check(m.upgrade(role,slot),"existing equipped upgrade entry still works")
			check(m.item("spare").level==3,"equipped upgrade targets correct ID")
			check(m.depart("M01"),"start combat with upgraded gear")
			var unit=m.s.battle.units[role]
			check(unit.atk==m.stats(role).atk and unit.armor==m.stats(role).armor and unit.max_hp==m.stats(role).hp,"combat uses displayed stats")
			var locked=m.s.duplicate(true)
			check(not m.upgrade_gear(role,worn_id) and m.s==locked,"in-battle upgrade rejected without cost")
			m.recall()
			m.s.credits=0
			locked=m.s.duplicate(true)
			check(not m.upgrade_gear(role,"spare") and m.s==locked,"insufficient funds preserve every item")
			m.s.credits=10000
			m.item("spare").level=m.cap()
			locked=m.s.duplicate(true)
			check(not m.upgrade_gear(role,"spare") and m.s==locked,"selected item cap preserves funds")
			check(not m.upgrade_gear((role+1)%4,"spare") and not m.upgrade_gear(role,"missing") and not m.upgrade_gear(-1,"spare") and m.s==locked,"invalid targets cannot upgrade")
	# Same enemy, actual damage calculation before/after upgrading the worn weapon.
	var m=fixture(1,"weapon")
	var damages=[]
	for step in range(2):
		m.depart("M01")
		m.spawn_wave()
		var shooter=m.s.battle.units[1]
		var enemy=m.alive(1)[0]
		var hp=enemy.hp
		m.hit(shooter,enemy,shooter.atk)
		damages.append(hp-enemy.hp)
		m.recall()
		if step==0: check(m.upgrade_gear(1,m.s.people[1].weapon),"upgrade worn Lv.6 weapon")
	check(damages[1]>damages[0],"same enemy takes more damage after upgrade")
	var save=Store.new("user://equipment-regression/slot.json")
	check(save.save(m.s),"save upgraded gear")
	var restored=Model.new()
	check(restored.import_state(save.load_primary()) and restored.s.inventory==m.s.inventory and restored.stats(1)==m.stats(1),"upgrades and absolute stats survive save reload")
	# Mk bonuses and body growth must also use the shared preview calculation.
	for mk in range(1,5):
		m=fixture(1,"weapon")
		m.s.people[1].body=8
		m.item("spare").mk=mk
		var predicted=m.stats(1,m.item("spare"))
		m.equip(1,"spare")
		check(m.stats(1)==predicted,"Mk and body preview agrees after equip "+str(mk))

func words(node: Node) -> String:
	var result=node.text+"\n" if node is Label else ""
	for child in node.get_children(): result+=words(child)
	return result

func click(id: String) -> void:
	check(game.ui.buttons.has(id),"UI button exists "+id)
	if not game.ui.buttons.has(id): return
	await process_frame
	var pos=game.ui.buttons[id].get_global_rect().get_center()
	var motion=InputEventMouseMotion.new()
	motion.position=pos
	root.push_input(motion,true)
	for pressed in [true,false]:
		var e=InputEventMouseButton.new()
		e.position=pos
		e.button_index=MOUSE_BUTTON_LEFT
		e.pressed=pressed
		root.push_input(e,true)
		await process_frame

func screenshot(name: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	await process_frame
	await RenderingServer.frame_post_draw
	var dir="res://art/reboot-fixes/equipment/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	check(root.get_texture().get_image().save_png(dir+name+".png")==OK,"capture "+name)

func ui_checks() -> void:
	root.size=Vector2i(1280,720)
	game=load("res://scenes/reboot/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.world.set_process(false)
	game.transient=true
	game.slot=1
	await process_frame
	for slot in ["armor","weapon"]:
		game.model=fixture(1,slot)
		game.toast_clock=0
		game.toast_label.visible=false
		game.view="base"
		game.page="equipment"
		game.ui.gear_kind=slot
		game.ui.selected_gear=""
		game.model.s.settings.large=true
		game.render()
		await click("gear_spare")
		check(game.ui.selected_gear=="spare","pointer selects spare")
		var display=words(game.overlay)
		check(display.contains("未穿戴") and display.contains("穿戴后：") and display.contains("换装变化："),"absolute stats and comparison are separately labelled")
		check(display.contains("Lv.1 → 2") and display.contains("强化后穿戴："),"selected level and upgrade preview visible")
		if slot=="armor": check(display.contains("护甲 -30") and display.contains("护甲 5 → 11") and display.contains("65 积分"),"reported Lv.6 vs Lv.1 case has correct labels and selected cost")
		else: check(display.contains("攻击 28.0 → 30.8") and display.contains("80 积分"),"weapon preview contains actual gain")
		await screenshot(slot+"-selected-lv1-720p-large")
		await click("upgrade_gear")
		check(game.model.item("spare").level==2 and game.model.item(game.model.s.people[1][slot]).level==6,"pointer upgrade changes selected item only")
		check(game.ui.selected_gear=="spare" and words(game.overlay).contains("Lv.2 → 3"),"selection survives refresh and next preview advances")
		var actual=game.model.stats(1,game.model.item("spare"))
		await click("equip")
		check(game.model.s.people[1][slot]=="spare" and game.model.stats(1)==actual,"pointer equip applies upgraded preview")
		await click("upgrade_gear")
		check(game.model.item("spare").level==3,"pointer upgrades worn selected item")
		await screenshot(slot+"-equipped-lv3-720p-large")
		game.model.item("spare").level=game.model.cap()
		game.render()
		check(game.ui.buttons.upgrade_gear.disabled and words(game.overlay).contains("已达 Lv.10 上限"),"cap disabled for selected item")
		game.model.item("spare").level=3
		game.render()
		game.store=FailingStore.new()
		game.committed=game.model.s.duplicate(true)
		game.transient=false
		var before=game.model.s.duplicate(true)
		await click("upgrade_gear")
		check(game.page=="save_error" and game.model.s==before,"failed save rolls back selected level and cost")
		game.transient=true
	# A stale selection from a different role cannot drive an upgrade.
	game.model=fixture(1,"armor")
	game.model.s.selected_person=0
	game.page="equipment"
	game.ui.gear_kind="armor"
	game.ui.selected_gear="spare"
	game.render()
	check(game.ui.selected_gear==game.model.s.people[0].armor,"different role clears incompatible selection")
	game.queue_free()
	await process_frame

func _initialize() -> void: call_deferred("run")
func run() -> void:
	model_checks()
	await ui_checks()
	print("EQUIPMENT: ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
