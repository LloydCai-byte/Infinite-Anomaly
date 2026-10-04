extends SceneTree
const M=preload("res://scripts/earth/model.gd")
var count=0
var failures=0
func ck(ok: bool,label: String) -> void:
	count+=1
	if not ok: failures+=1; printerr("FAIL "+label)
func run_fight(m: RefCounted) -> void:
	for i in range(36000):
		if not m.active(): break
		m.tick(1.0/60)
func _initialize() -> void:
	var m=M.new()
	ck(not m.depart(1),"intro gate")
	m.s.intro_done=true
	ck(not m.depart(2),"locked stage")
	ck(m.depart(1) and m.alive(0).size()==5,"five deploy")
	ck(not m.grow(0),"battle blocks growth")
	run_fight(m)
	ck(m.s.result.reason=="victory","starter wins first mission")
	var money=m.s.credits
	m.settle("victory")
	ck(m.s.credits==money,"cannot reward twice")
	ck(m.s.max_stage==2,"next stage unlocked")
	m.close_result()
	var before=m.stats(0)
	ck(m.grow(0) and m.stats(0).atk>before.atk and m.stats(0).hp>before.hp,"growth changes actual stats")
	ck(m.depart(1),"repeat mission")
	for i in range(1200):
		m.tick(1.0/60)
		if m.s.battle.killed>0: break
	ck(m.recall() and m.s.result.reason=="recall","recall settles earned drops")
	money=m.s.credits
	ck(not m.recall() and m.s.credits==money,"repeated recall harmless")
	m.close_result()
	ck(m.depart(1) and m.alive(0).all(func(u):return u.hp==u.max_hp),"returned team recovers")
	var restored=M.new()
	ck(restored.import_state(m.s) and restored.active(),"battle resume")
	m.s.credits=0
	m.recall(); m.close_result()
	m.s.credits=0
	ck(not m.grow(0) and m.s.credits==0,"no negative balance")
	print("EARTH STAGE2 ",count," checks / ",failures," failures")
	quit(1 if failures else 0)
