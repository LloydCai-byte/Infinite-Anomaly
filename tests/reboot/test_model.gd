extends SceneTree
const Model=preload("res://scripts/reboot/model.gd")
const C=preload("res://scripts/reboot/catalog.gd")
const Store=preload("res://scripts/reboot/save_store.gd")
var checks=0
var failures=0

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: "+message)

func advance(m: RefCounted, seconds: float) -> void:
	for i in range(int(seconds/.05)):
		m.tick(.05)
		m.events.clear()

func battle_to_end(m: RefCounted) -> void:
	for i in range(12000):
		if not m.active(): break
		m.tick(.05)
		m.events.clear()

func _initialize() -> void:
	var m=Model.new()
	check(m.s.credits==150 and m.s.alloy==8 and m.s.people.size()==4,"initial resources and roster")
	check(m.s.inventory.size()==8,"eight unique initial equipment items")
	check(not m.depart("M02"),"locked mission cannot start")
	check(m.depart("M01"),"first deployment")
	var before=m.s.duplicate(true)
	check(not m.upgrade(0,"body") and not m.upgrade(1,"weapon") and not m.upgrade(2,"skill"),"all growth locked outside base")
	check(not m.manufacture(0,"weapon",1) and not m.train() and not m.facility(),"facility printer training locked")
	check(m.s==before,"rejected mutations preserve state")
	check(not m.depart("M01"),"double deploy rejected")
	advance(m,2)
	check(m.s.battle.units[0].cd>=0.0,"travel never banks negative attack cooldown")
	var unit=m.s.battle.units[0]
	unit.cd=.6
	unit.anim="attack"
	unit.anim_time=.2
	m.hit(m.s.battle.units[4],unit,3)
	check(is_equal_approx(unit.cd,.6) and unit.anim=="attack" and is_equal_approx(unit.anim_time,.2),"damage never interrupts attack")
	m.s.battle.units[1].hp=0
	for u in m.alive(1): u.hp=0
	m.tick(.05)
	check(m.s.battle.units[1].hp==0 and m.s.battle.units[0].hp==m.s.battle.units[0].max_hp,"wave heal affects survivors only")
	check(m.s.credits==170 and m.s.battle.credits==20,"first-wave weighted reward")
	check(m.recall(),"manual recall")
	check(m.s.wins.M01==0 and m.s.result.credits==20,"recall preserves only completed reward and no card")
	var credited=m.s.credits
	m.finish("victory")
	check(m.s.credits==credited and m.s.wins.M01==0,"finished run cannot be settled again")
	m.reset("balance")
	m.depart("M01")
	battle_to_end(m)
	print("BALANCE M01: ",m.s.result)
	check(m.s.result.outcome=="victory","unmodified new squad completes first mission")
	check(m.s.credits==250 and m.s.alloy==11 and m.s.wins.M01==1,"full mission pays exact rewards once")
	check(m.s.result.time>20 and m.s.result.time<120,"first mission readable duration")
	var snapshot=m.s.duplicate(true)
	var restored=Model.new()
	check(restored.import_state(snapshot),"state imports")
	advance(restored,20)
	check(restored.s.wins.M01==1 and restored.s.credits==250,"loading settlement does not repeat reward")
	m.s.credits=100000
	m.s.alloy=1000
	for i in range(4):
		for j in range(2): m.upgrade(i,"body");m.upgrade(i,"weapon");m.upgrade(i,"armor")
	check(m.depart("M02"),"M02 unlocked after M01")
	battle_to_end(m)
	print("BALANCE M02: ",m.s.result.outcome," time=",m.s.result.time)
	check(m.s.result.outcome=="victory" and m.s.result.completed==4,"four-wave task ends only after fourth wave")
	for i in range(4):
		for j in range(2): m.upgrade(i,"body");m.upgrade(i,"weapon");m.upgrade(i,"armor")
		for j in range(2): m.upgrade(i,"skill")
	check(m.depart("M03"),"M03 unlock chain")
	battle_to_end(m)
	print("BALANCE M03: ",m.s.result.outcome," time=",m.s.result.time)
	check(m.s.result.outcome=="victory" and m.s.result.completed==5,"five-wave task ends only after fifth wave")
	check(m.facility() and m.cap()==10,"M03 opens T2 growth cap")
	var cost=0
	for i in range(4): cost+=m.body_cost(i)
	var credits=m.s.credits
	var lv=m.s.people[0].body
	check(m.train() and m.s.credits==credits-cost,"batch training reserves exact cost")
	check(not m.upgrade(0,"body") and not m.depart("M01"),"training locks upgrade and departure")
	check(m.cancel_training() and m.s.credits==credits and m.s.people[0].body==lv,"cancelling refunds all cost")
	m.train()
	advance(m,30.1)
	check(m.s.people[0].body==lv+1 and m.s.training.is_empty(),"training completes once")
	advance(m,30)
	check(m.s.people[0].body==lv+1,"completed training does not repeat")
	var count=m.s.inventory.size()
	check(m.manufacture(1,"weapon",2) and m.s.inventory.size()==count+1,"fixed equipment manufacture")
	var new_id=m.s.inventory.back().id
	check(not m.equip(0,new_id),"weapon role restriction")
	var old=m.s.people[1].weapon
	check(m.equip(1,new_id) and m.s.inventory.size()==count+1,"equipping preserves inventory")
	check(not m.dismantle(new_id),"cannot dismantle equipped item")
	check(m.dismantle(old) and m.s.inventory.size()==count,"dismantle removes exactly one item")
	for n in [7,8,24,25]:
		m.s.wins.M01=n
		check(m.quality("M01")==({7:"普通",8:"金卡",24:"金卡",25:"钻石"}[n]),"quality threshold "+str(n))
	m.depart("M01")
	advance(m,3)
	var st=Store.new("user://reboot-tests/slot1.json")
	check(st.save(m.s),"active battle save")
	var loaded=Model.new()
	check(loaded.import_state(st.load_primary()) and loaded.active(),"active battle restored")
	check(loaded.s.battle==m.s.battle,"all battle timers and unit hp roundtrip")
	advance(loaded,2)
	advance(m,2)
	check(loaded.s.battle==m.s.battle,"restart continues deterministically")
	check(st.save(loaded.s) and not st.load_backup().is_empty(),"rotating backup")
	var f=FileAccess.open(st.path,FileAccess.WRITE)
	f.store_string("deliberately corrupt test")
	f.close()
	check(st.load_primary().is_empty() and not st.load_backup().is_empty(),"checksum detects corruption and retains backup")
	loaded.s.auto="repeat"
	for u in loaded.alive(0): u.hp=0
	loaded.tick(.05)
	check(loaded.s.result.outcome=="defeat" and loaded.s.auto=="return","wipe stops automatic retries")
	print("REBOOT_MODEL: ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
