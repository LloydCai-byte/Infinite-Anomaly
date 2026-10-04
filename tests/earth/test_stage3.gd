extends SceneTree
const M=preload("res://scripts/earth/model.gd")
var n=0
var errors=0
func ck(ok: bool,label:String) -> void:
	n+=1
	if not ok:errors+=1;printerr("FAIL "+label)
func _initialize() -> void:
	var m=M.new()
	var before=m.s.duplicate(true)
	ck(not m.make_suit(1,2) and m.s==before,"locked suit no spend")
	m.s.room=3;m.s.wins={"3":1,"6":1};m.s.credits=10000;m.s.alloy=1000;m.s.cores=100
	ck(m.make_suit(1,2),"manufacture bound outfit")
	ck(m.s.people[1].suit==1,"manufacture does not silently equip")
	var credits=m.s.credits
	ck(not m.make_suit(1,2) and m.s.credits==credits,"duplicate blocked")
	var old=m.stats(1)
	ck(m.equip_suit(1,2) and m.stats(1).weapon=="磁刃太刀" and m.stats(1).atk>old.atk,"weapon and attributes switch together")
	ck(not m.equip_suit(0,2),"ownership per warrior")
	m.s.intro_done=true;m.depart(1)
	ck(m.s.battle.units[1].suit==2,"deployment snapshot follows suit")
	ck(not m.equip_suit(1,1) and not m.make_suit(1,3),"combat locks outfit")
	m.recall();m.close_result()
	ck(m.equip_suit(1,1) and m.stats(1).weapon=="制式太刀","equipping old outfit restores bound weapon")
	var clone=M.new()
	ck(clone.import_state(m.s) and 2 in clone.s.people[1].owned_suits,"ownership survives save state")
	print("EARTH STAGE3 ",n," checks / ",errors," failures")
	quit(1 if errors else 0)
