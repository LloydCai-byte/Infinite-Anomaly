extends SceneTree
const M=preload("res://scripts/earth/model.gd")
const C=preload("res://scripts/earth/catalog.gd")
var checks=0
var failures=0
var results=[]
func ck(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL "+label)
func _initialize() -> void:
	for stage in [301,302]:
		var m=M.new();m.s.intro_done=true
		ck(m.depart(stage),"new anomaly accessible after intro")
		var starts=[];var counts=[];var seen=0;var restored_once=false
		for tick in range(60*600):
			m.tick(1.0/60)
			if m.s.battle.encounter!=seen:
				seen=m.s.battle.encounter
				starts.append(m.s.battle.camera);counts.append(m.alive(1).size())
				ck(m.alive(1).size()==5,"five enemies in section %d"%seen)
				var kinds={}
				for u in m.alive(1):kinds[u.variant]=true
				ck(kinds.size()==5,"five designs mixed in section")
			if seen==2 and not restored_once:
				var clone=M.new();ck(clone.import_state(m.s),"mid-battle save restores anomaly and units")
				ck(clone.s.battle.stage==stage and clone.s.battle.encounter==2,"restored correct world segment")
				m=clone;restored_once=true
			if not m.active():break
		ck(not m.active() and m.s.result.get("reason","")=="victory","starter team naturally wins %d"%stage)
		ck(seen==5 and m.s.result.get("killed",0)==25,"five sections and 25 kills")
		ck(starts.size()==5 and starts[-1]>9500,"actually traversed the long map")
		ck(m.s.max_stage==1 and not m.depart(2),"bonus win does not unlock main campaign")
		ck(m.s.inventory.size()==1 and m.s.result.loot.size()==1,"equipment reward")
		ck(M.new().import_state(m.s),"completed anomaly save validates")
		var money=m.s.credits;m.settle("victory");ck(m.s.credits==money,"no duplicate rewards")
		var saved_result=m.s.result.duplicate(true)
		ck(m.continue_battle(stage) and m.active(),"retry connected")
		m.recall();ck(m.s.result.reason=="recall","recall from new anomaly")
		m.close_result();ck(m.s.home.visits==1,"return home settles once")
		results.append({"stage":stage,"result":saved_result,"section_cameras":starts,"counts":counts,"normal_starting_team":true})
	var legacy=M.new();legacy.s.intro_done=true;legacy.s.max_stage=300;legacy.depart(300)
	ck(C.next_stage(300)==0 and C.next_stage(301)==302 and C.next_stage(302)==0,"campaign and anomaly endpoints distinct")
	legacy.settle("victory");ck(legacy.s.max_stage==300 and not legacy.continue_battle(301),"main finale does not spill into bonus route")
	var invalid=M.new();invalid.s.intro_done=true;invalid.depart(301);invalid.spawn_encounter();invalid.s.battle.units[5].variant=10
	ck(not M.new().import_state(invalid.s),"reject corrupted monster variant")
	var report={"checks":checks,"failures":failures,"battles":results}
	var f=FileAccess.open("res://docs/kaidan-integration-011/model-test.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
	print("KAIDAN 011 MODEL ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
