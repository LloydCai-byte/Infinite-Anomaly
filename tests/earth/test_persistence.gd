extends SceneTree
const M=preload("res://scripts/earth/model.gd")
const Store=preload("res://scripts/reboot/save_store.gd")
var n=0
var failures=0
func ck(ok:bool,label:String)->void:
	n+=1
	if not ok:failures+=1;printerr("FAIL "+label)
func _initialize()->void:
	var m=M.new();m.s.intro_done=true;m.depart(1)
	for i in range(100):m.tick(1.0/60)
	var st=Store.new("res://.local/earth-tests/persist.json")
	ck(st.save(m.s),"save live battle")
	var clone=M.new()
	ck(clone.import_state(st.load_primary()),"restore live battle")
	for i in range(300):m.tick(1.0/60);clone.tick(1.0/60)
	ck(m.s==clone.s,"resume deterministic simulation")
	var invalid=m.s.duplicate(true);invalid.people[0].level=0
	var before=clone.s.duplicate(true)
	ck(not clone.import_state(invalid) and clone.s==before,"invalid level rejected atomically")
	invalid=m.s.duplicate(true);invalid.people[1].suit=9
	ck(not clone.import_state(invalid),"invalid suit rejected")
	invalid=m.s.duplicate(true);invalid.battle.units[0].hp=NAN
	ck(not clone.import_state(invalid),"nonfinite battle rejected")
	invalid=m.s.duplicate(true);invalid.battle.units[1].id=0
	ck(not clone.import_state(invalid),"duplicate ids rejected")
	invalid=m.s.duplicate(true);invalid.battle.units[0].erase("skill_factor")
	ck(not clone.import_state(invalid),"missing skill factor rejected")
	invalid=m.s.duplicate(true);invalid.battle.units[0].suit="wrong"
	ck(not clone.import_state(invalid),"wrong suit type rejected")
	invalid=m.s.duplicate(true);invalid.battle.effects=[{"type":"hit"}]
	ck(not clone.import_state(invalid),"malformed effect rejected")
	m.recall();ck(st.save(m.s),"save settled state")
	ck(not st.load_backup().is_empty(),"backup preserved")
	var broken=FileAccess.open(st.path,FileAccess.WRITE);broken.store_string("broken");broken.close()
	ck(st.load_primary().is_empty() and not st.load_backup().is_empty(),"corrupt primary recoverable")
	var blocker=FileAccess.open("res://.local/earth-tests/not-a-folder",FileAccess.WRITE);blocker.store_string("x");blocker.close()
	var failed_store=Store.new("res://.local/earth-tests/not-a-folder/slot.json")
	ck(not failed_store.save(m.s),"write failure reported")
	print("EARTH PERSISTENCE ",n," checks / ",failures," failures")
	quit(1 if failures else 0)
