extends SceneTree
const M=preload("res://scripts/earth/model.gd")
var n=0
var errors=0
func ck(ok:bool,label:String) -> void:
	n+=1
	if not ok:errors+=1;printerr("FAIL "+label)
func _initialize() -> void:
	var m=M.new();m.s.intro_done=true;m.s.max_stage=6;m.invincible=true
	ck(not m.upgrade_support("laser"),"cannot buy before anomaly victory")
	m.depart(3)
	for i in range(12000):
		if not m.active(): break
		m.tick(1.0/60)
	ck(m.s.result.reason=="victory" and m.s.support.has("laser") and m.s.support.laser.level==0,"win unlocks not auto purchases")
	m.close_result();m.s.credits=5000;m.s.alloy=1000;m.s.cores=50
	ck(m.upgrade_support("laser") and m.s.support.laser.level==1,"purchase enabled")
	m.depart(2)
	for i in range(900):m.tick(1.0/60)
	ck(m.s.battle.get("support_triggers",0)>0,"periodic support actually fires")
	ck(not m.toggle_support("laser"),"no mid-battle support modification")
	m.recall();m.close_result()
	ck(m.toggle_support("laser") and not m.s.support.laser.enabled,"toggle in room")
	m.depart(2)
	for i in range(900):m.tick(1.0/60)
	ck(m.s.battle.get("support_triggers",0)==0,"disabled support never fires")
	var clone=M.new()
	ck(clone.import_state(m.s) and clone.s.support.laser.level==1 and not clone.s.support.laser.enabled,"support save state")
	print("EARTH STAGE5 ",n," checks / ",errors," failures")
	quit(1 if errors else 0)
