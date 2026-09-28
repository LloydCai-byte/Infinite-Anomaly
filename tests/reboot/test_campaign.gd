extends SceneTree
const Model=preload("res://scripts/reboot/model.gd")
const W=preload("res://scripts/reboot/war_model.gd")
const C=preload("res://scripts/reboot/catalog.gd")
const WC=preload("res://scripts/reboot/war_catalog.gd")
var failures=0
var checks=0
var report=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures+=1;push_error(label)
func trained() -> RefCounted:
	var m=Model.new()
	m.s.intro_done=true
	m.s.tier=4
	for d in C.MISSIONS: m.s.wins[d.id]=8
	for i in range(4):
		m.s.people[i].body=20
		m.s.people[i].skill=5
		m.item(m.s.people[i].weapon).level=20
		m.item(m.s.people[i].armor).level=20
		m.item(m.s.people[i].weapon).mk=4
		m.item(m.s.people[i].armor).mk=4
	m.s.reveal_read=true
	return m
func advance(w: RefCounted,seconds: float) -> void:
	for i in range(ceili(seconds/.1)):
		w.tick(.1)
		w.events.clear()
func _initialize() -> void:
	var m=Model.new()
	var old=m.s.duplicate(true)
	old.schema_version=1
	for d in C.MISSIONS.slice(3): old.wins.erase(d.id)
	check(m.import_state(old) and m.s.wins.size()==10,"schema1 expands all mission keys")
	check(not m.graduate(),"unqualified handoff rejected")
	for d in C.MISSIONS:
		var weights=0
		for wave in d.waves: weights+=int(wave.weight)
		check(weights==100,d.id+" reward weights sum to 100")
	check(C.MISSIONS[9].waves.size()>3,"formal missions variable")
	m=trained()
	check(m.graduate(),"qualified handoff")
	check(not m.graduate(),"handoff cannot duplicate originals")
	var w=m.war_model()
	var room_count=0
	for stream in w.s.streams: room_count+=stream.rooms
	check(room_count==1000000,"one million disjoint rooms")
	check(w.conservation() and w.s.generated==4 and w.held()==4,"only original four initially deployed")
	advance(w,12.1)
	check(w.s.streams[0].phase=="returning" and w.s.streams[0].held==0,"original room returns empty")
	check(w.s.landed>=4,"four original soldiers landed")
	var old_names=w.s.originals.duplicate(true)
	advance(w,10.3)
	check(w.s.streams[0].phase=="training" and w.s.streams[0].cycle==1,"same room cultivates NEW batch")
	check(w.conservation(),"counts conserved across first cycle")
	w.finish("retreat")
	check(not w.s.active and w.s.occupied==0 and w.s.phase=="orbit","P01 retreat uses orbit not nonexistent P00")
	var prior=w.s.time
	check(m.history_mode(true),"enter historical simulation")
	m.tick(10)
	check(m.s.war.time==prior,"historical mode freezes all war clocks")
	check(m.history_mode(false),"leave historical simulation")
	w=m.war_model()
	advance(w,50)
	check(w.conservation() and w.s.landed>4,"living previous batches don't block deployment")
	var original_stack={}
	for a in w.s.army:
		if a.id=="qiaoyue": original_stack=a
	check(not original_stack.is_empty(),"original identity preserved")
	w.damage_army(1e12,[original_stack])
	w.update_originals()
	var dead=w.s.dead
	advance(w,70)
	check(w.s.originals[0].status=="阵亡" and w.s.originals[0].current_hp==0,"new cycles cannot revive named soldier")
	check(w.s.dead>=dead and w.s.memorial.size()>=1 and w.conservation(),"permadeath persisted and accounted")
	var save=m.s.duplicate(true)
	var reload=Model.new()
	check(reload.import_state(save),"war save import")
	advance(w,17.3)
	advance(reload.war_model(),17.3)
	check(var_to_str(m.s.war)==var_to_str(reload.s.war),"resume is deterministic including room phases")
	# Room readiness respects manual hold, and tech/formation snapshot boundaries.
	w=reload.war_model()
	w.s.auto_send=[false,false,false,false]
	advance(w,100)
	var deployed=w.s.landed
	check(w.s.streams.all(func(st): return st.phase=="ready"),"all rooms wait with four passengers when disabled")
	advance(w,60)
	check(w.s.landed==deployed,"hold never spawns soldiers")
	check(w.action("formation",{"group":0,"slot":0,"role":2}),"formation change")
	check(w.s.streams[0].slots[0]==0,"ready batch keeps original formation")
	w.s.science=100
	check(w.action("tech","weapons"),"tech research")
	check(w.s.streams[0].stats[0].atk==WC.ROLES[0].atk,"ready batch keeps stat snapshot")
	w.action("auto_send",0)
	advance(w,60)
	check(w.s.streams[0].slots[0]==2 and w.s.streams[0].stats[0].atk>WC.ROLES[2].atk,"new batch gets new role and tech")
	check(w.conservation(),"conservation after holds and changes")
	# Ten missions with actual combat, preserving real earned reward semantics.
	m=trained();m.s.phase="training";m.s.war={}
	for d in C.MISSIONS:
		var credits=m.s.credits
		var wins=m.s.wins[d.id]
		check(m.depart(d.id),d.id+" launches")
		var steps=0
		while m.active() and steps<30000:
			m.tick(.05);m.events.clear();steps+=1
		check(m.s.result.get("outcome","")=="victory",d.id+" can be completed at mature build")
		check(m.s.credits-credits==d.credits and m.s.wins[d.id]==wins+1,d.id+" pays once")
		print("TRAINING ",d.id," ",m.s.result.get("outcome","")," time=",snapped(m.s.result.get("time",0),.1))
	# Simulate full war campaigns with different requested formations. No tech
	# or supplies are injected; research is purchased only from earned rewards.
	for run in range(4):
		m=trained()
		if run==3:
			check(m.import_state(str_to_var(FileAccess.get_file_as_string("res://.local/war-production/graduated-natural.save"))),"resume the fully earned training campaign")
		else: m.graduate()
		w=m.war_model()
		if run==1: w.s.formations=[[0,0,1,3],[0,1,2,3],[0,1,2,3],[0,1,2,3]]
		if run==2: w.s.formations=[[0,1,2,2],[0,1,2,3],[0,1,2,3],[0,1,2,3]]
		var turns=0
		var losses=0
		while w.s.occupied<12 and turns<144000:
			w.tick(.5);w.events.clear();turns+=1
			if turns%120==0: check(w.conservation(),"campaign %d population at %d"%[run,turns])
			if not w.s.active:
				if w.s.result.get("outcome","")=="defeat": losses+=1
				for tech in ["weapons","armor","medicine","logistics"]:
					w.action("tech",tech)
				if w.s.occupied<12:
					# Regroup for one production cycle after a loss; no free army.
					advance(w,60 if w.s.result.get("outcome","")!="victory" else 10)
					while w.soldiers()<WC.recommended(w.s.occupied): advance(w,10)
					w.launch(w.s.occupied)
			if w.s.active and w.s.hull<600 and w.soldiers()>1000000: w.action("repair")
			if w.s.active and w.s.time-float(w.s.get("started",0))>600: w.action("retreat")
			if w.s.active and w.s.boost<=0 and w.s.supplies>500: w.action("boost")
		check(w.s.occupied==12 and w.s.ending and w.s.cards.size()==12,"campaign %d reaches final ending"%run)
		check(w.conservation(),"campaign %d final conservation"%run)
		var row={"run":run,"seconds":w.s.time,"occupied":w.s.occupied,"deaths":w.s.dead,"generated":w.s.generated,"losses":losses,"tech":w.s.tech,"originals":w.s.originals.map(func(p):return {"name":p.name,"status":p.status})}
		report.append(row);print("WAR CAMPAIGN ",JSON.stringify(row))
		if run==0:
			var final_state=FileAccess.open("res://.local/war-production/completed-campaign.save",FileAccess.WRITE)
			final_state.store_string(var_to_str(m.s));final_state.close()
	var file=FileAccess.open("res://.local/war-production/campaign-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"campaigns":report},"  "));file.close()
	print("CAMPAIGN: ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
