extends SceneTree
const M=preload("res://scripts/reboot/model.gd")
const C=preload("res://scripts/reboot/catalog.gd")
var m=M.new()
var runs=0
var seconds=0.0
var upgrades=0
var failures=0
var history=[]
var goals=[[1,1,1,1],[3,3,2,1],[5,4,3,1],[7,6,5,2],[9,8,7,2],[10,10,10,3],[14,14,14,4],[15,15,15,5],[15,15,15,5],[15,15,15,5]]
func run_mission(id: String) -> bool:
	if not m.depart(id): push_error(m.error);return false
	var step=0
	while m.active() and step<40000:
		m.tick(.05);m.events.clear();step+=1
	runs+=1
	seconds+=float(m.s.result.get("time",0))
	return m.s.result.get("outcome","")=="victory"
func farm(id: String) -> bool:
	if not run_mission(id):
		push_error("Farming failed at "+id);failures+=1;return false
	return true
func _initialize() -> void:
	m.s.intro_done=true
	for idx in range(10):
		var d=C.MISSIONS[idx]
		var previous=C.MISSIONS[maxi(0,idx-1)].id
		var tier=1 if idx<3 else (2 if idx<6 else 3)
		while m.s.tier<tier:
			while not m.facility():
				if not farm(previous): quit(1);return
		var target=goals[idx]
		for role in range(4):
			if idx>=6:
				m.s.selected_person=role
				var module="reflect" if idx==6 else "regen"
				while int(m.s.people[role].modules.get(module,0))<3:
					if m.module_upgrade(module): upgrades+=1
					elif not farm(previous): quit(1);return
				m.module_equip(module)
			for kind_index in range(4):
				var kind=["body","weapon","armor","skill"][kind_index]
				var current=m.s.people[role][kind] if kind in ["body","skill"] else m.item(m.s.people[role][kind]).level
				while current<target[kind_index]:
					if m.upgrade(role,kind): current+=1;upgrades+=1
					elif not farm(previous): quit(1);return
			var mk=2 if idx>=3 else 1
			if idx>=8: mk=3
			for kind in ["weapon","armor"]:
				if m.item(m.s.people[role][kind]).mk>=mk: continue
				while not m.manufacture(role,kind,mk):
					if not farm(previous): quit(1);return
				var old=m.item(m.s.people[role][kind])
				var desired=old.level
				var reserve_credits=0
				var reserve_alloy=0
				for level in range(1,desired):
					reserve_credits+=(50+30*level) if kind=="weapon" else (40+25*level)
					reserve_alloy+=1+int(level/3) if kind=="weapon" else 1+int(level/4)
				while m.s.credits<reserve_credits or m.s.alloy<reserve_alloy:
					if not farm(previous): quit(1);return
				m.equip(role,m.s.inventory.back().id)
				while m.item(m.s.people[role][kind]).level<desired:
					if m.upgrade(role,kind): upgrades+=1
					elif not farm(previous): quit(1);return
				m.dismantle(old.id)
		# Each gold card must be earned, with no injected currency or stats.
		while m.s.wins[d.id]<8:
			if not run_mission(d.id):
				push_error("PROGRESSION wall "+d.id+" power "+str(m.power())+" result "+str(m.s.result))
				quit(1);return
		var row={"mission":d.id,"power":m.power(),"runs":runs,"seconds":seconds,"credits":m.s.credits,"alloy":m.s.alloy,"tier":m.s.tier}
		history.append(row);print("PROGRESSION ",JSON.stringify(row))
	while not m.facility():
		if not farm("M10"): quit(1);return
	if not m.graduate_ready(): failures+=1
	m.s.reveal_read=true
	if not m.graduate(): failures+=1
	var out=FileAccess.open("res://.local/war-production/natural-progression.json",FileAccess.WRITE)
	out.store_string(JSON.stringify({"runs":runs,"seconds":seconds,"upgrades":upgrades,"failures":failures,"history":history},"  "));out.close()
	out=FileAccess.open("res://.local/war-production/graduated-natural.save",FileAccess.WRITE)
	out.store_string(var_to_str(m.s));out.close()
	print("NATURAL_PROGRESSION: ",runs," missions / ",upgrades," purchases / ",seconds," simulated seconds / ",failures," failures")
	quit(1 if failures else 0)
