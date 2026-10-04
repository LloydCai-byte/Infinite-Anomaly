extends SceneTree
const M=preload("res://scripts/earth/model.gd")
var n=0
var errors=0
func ck(ok:bool,label:String) -> void:
	n+=1
	if not ok:errors+=1;printerr("FAIL "+label)
func _initialize() -> void:
	var m=M.new();m.s.credits=10000;m.s.alloy=1000;m.s.cores=100
	var old=m.stats(1)
	ck(m.upgrade(1,"talent") and m.stats(1).atk==old.atk and m.stats(1).skill_factor>old.skill_factor,"talent separate from basic stats")
	old=m.stats(1)
	ck(m.upgrade(1,"equipment") and m.stats(1).hp>old.hp and m.s.people[1].suit==1,"equipment stats only")
	var money=m.s.credits
	ck(not m.upgrade_room() and m.s.credits==money,"room mission gate")
	m.s.wins["3"]=1
	ck(m.upgrade_room() and m.s.room==2,"room upgrade")
	ck(m.make_suit(1,2),"room unlocks suit recipe")
	m.s.people[0].talent=6
	ck(not m.upgrade(0,"talent"),"room talent cap")
	m.s.people[0].level=30
	ck(not m.grow(0),"room personal cap")
	m.s.intro_done=true;m.depart(1)
	ck(not m.upgrade(0,"equipment") and not m.upgrade_room(),"growth locked during battle")
	for i in range(3000):m.tick(1.0/60)
	ck(not m.active() and m.s.result.reason=="victory","skills work in full battle")
	print("EARTH STAGE4 ",n," checks / ",errors," failures")
	quit(1 if errors else 0)
