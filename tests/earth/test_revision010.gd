extends SceneTree
const Model=preload("res://scripts/earth/model.gd")
const Loot=preload("res://scripts/earth/loot.gd")
const Store=preload("res://scripts/reboot/save_store.gd")
var checks=0
var failures=0
func ck(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL "+label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var m=Model.new()
	var old=m.s.duplicate(true)
	for key in ["inventory","equipped","loot_seed","loot_serial"]:old.erase(key)
	ck(m.import_state(old) and m.s.inventory.is_empty(),"0.9 inventory migration")
	m.s.intro_done=true
	ck(m.depart(1),"first encounter starts without equipment")
	for i in range(18000):
		m.tick(1.0/60)
		if not m.active():break
	ck(m.s.result.get("reason")=="victory","natural first stage won without injected stats")
	ck(m.s.inventory.size()==1 and m.s.result.loot.size()==1,"one genuine victory drop")
	var helmet=m.s.inventory[0]
	ck(helmet.base==0 and helmet.quality==2,"first victory guarantees laser helmet")
	var balance=m.s.credits
	m.settle("victory")
	ck(m.s.inventory.size()==1 and m.s.credits==balance,"settlement idempotent")
	var base=m.stats(0)
	ck(m.equip_item(0,helmet.id),"equip reward at result")
	ck(m.stats(0)!=base and m.gear_spirits().size()==1,"affixes and spirit activate")
	ck(m.equip_item(1,helmet.id) and not m.s.equipped[0].has("head") and m.item_owner(helmet.id)==1,"transfer unique equipment")
	var store=Store.new("res://.local/earth-010-qa/loot-save.json")
	ck(store.save(m.s),"save actual reward and equipped owner")
	var restored=Model.new()
	ck(restored.import_state(store.load_primary()) and restored.s==m.s,"roundtrip inventory affixes result and loadout")
	var before=m.s.duplicate(true)
	var bad=before.duplicate(true);bad.equipped[0].head=helmet.id
	ck(not m.import_state(bad) and m.s==before,"reject duplicate owner atomically")
	bad=before.duplicate(true);bad.inventory[0].affixes.atk=NAN
	ck(not m.import_state(bad) and m.s==before,"reject invalid affix atomically")
	bad=before.duplicate(true);bad.inventory[0].base=999
	ck(not m.import_state(bad),"reject invalid equipment definition")
	ck(not m.continue_battle(3) and m.s==before,"reject jumping locked next stage atomically")
	var visits=m.s.home.visits;var preset=m.s.home.preset
	ck(m.continue_battle(2) and m.s.home.visits==visits and m.s.home.preset==preset,"next battle bypasses return-home reroll")
	ck(m.s.result.is_empty() and m.s.battle.stage==2,"clears previous result for continuation")
	for unit in m.alive(0):ck(unit.hp==unit.max_hp,"new challenge restores warrior")
	ck(not m.unequip_item(1,"head"),"cannot mutate loadout during battle")
	m.spawn_encounter()
	for unit in m.alive(1):unit.hp=100000;unit.max_hp=100000
	for i in range(480):m.tick(1.0/60)
	ck(m.s.battle.get("gear_triggers",0)>0,"equipped helmet fires in real simulation")
	ck(store.save(m.s) and restored.import_state(store.load_primary()),"save midbattle equipped support clock and effects")
	m.recall();var count=m.s.inventory.size()
	ck(m.s.result.loot.is_empty(),"recall has resources but no boss equipment")
	ck(not m.continue_battle(3),"recall cannot unlock next stage")
	ck(m.continue_battle(2) and m.s.inventory.size()==count,"repeat does not re-award prior result")
	m.recall();m.close_result()
	ck(m.s.home.visits==visits+1,"explicit return rerolls home once")
	ck(m.unequip_item(1,"head") and m.gear_spirits().is_empty(),"unequipped support disappears")
	# Exercise all three special effects with controlled high-health enemies.
	for n in range(3):
		var item=Loot.make(3,m.s.loot_serial,99);item.base=n
		m.s.inventory.append(item);m.s.loot_serial+=1
		ck(m.equip_item(0,item.id),"equip special "+str(n))
	m.s.max_stage=3;m.depart(3)
	m.spawn_encounter()
	for unit in m.alive(1):unit.hp=100000;unit.max_hp=100000
	for unit in m.alive(0):unit.hp*=.7
	for i in range(550):m.tick(1.0/60)
	ck(m.s.battle.gear_clock.size()==3 and m.s.battle.get("gear_triggers",0)>=3,"three independent summon clocks")
	ck(m.s.battle.healing>0,"healing familiar restores hp")
	ck(m.s.battle.damage>0,"offensive familiars damage enemies")
	ck(store.save(m.s) and restored.import_state(store.load_primary()),"three-spirit snapshot roundtrip")
	for stage in [1,10,100,300]:
		for serial in range(1,101):ck(Loot.valid(Loot.make(stage,serial,503)),"bounded drop schema "+str(stage)+"/"+str(serial))
	var report={"checks":checks,"failures":failures,"natural_first_stage":true,"fixture":"Only isolated support-effect scenarios use high enemy health; first victory uses natural starting stats."}
	var file=FileAccess.open("res://docs/revision-20261002/model-test.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("REVISION010 MODEL ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
