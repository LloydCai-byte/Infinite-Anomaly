extends SceneTree
const M=preload("res://scripts/earth/model.gd")
const C=preload("res://scripts/earth/catalog.gd")
var fights=0
var defeats=0
var purchases=0
var simulated=0.0
var failures=0
func _initialize() -> void:
	var m=M.new();m.s.intro_done=true
	var unique={}
	for n in range(1,301):
		var d=C.mission(n)
		if d.stage!=n or d.schedule.is_empty() or d.encounters!=d.schedule.size()+1: failures+=1
		unique[d.mechanic]=true
	if unique.size()!=10: failures+=1
	while not m.s.wins.has("300") and fights<2000:
		var target=int(m.s.max_stage)
		# Favor a real retry of a completed operation after a loss; no currency injection.
		if defeats>0 and fights%3!=0: target=maxi(1,target-1)
		# A visible material source matters: farm a cleared core-bearing task when the room needs cores.
		if m.s.room<10 and m.s.wins.has(str(m.room_cost().gate)) and m.s.cores<m.room_cost().cores:
			for candidate in range(target-1,0,-1):
				if candidate%3==0 and m.s.wins.has(str(candidate)):target=candidate;break
		if not m.depart(target): failures+=1;break
		fights+=1
		for step in range(9000):
			if not m.active():break
			m.tick(1.0/30);simulated+=1.0/30
		if m.active():m.recall()
		if m.s.result.reason!="victory": defeats+=1
		m.close_result()
		if m.s.room<10 and m.s.wins.has(str(m.room_cost().gate)):
			if m.upgrade_room():purchases+=1
			else:continue # Save for the room gate, rather than spend its money on optional upgrades.
		for role in range(5):
			for tier in range(3,1,-1):
				if tier not in m.s.people[role].owned_suits and m.make_suit(role,tier):purchases+=1
				if tier in m.s.people[role].owned_suits:m.equip_suit(role,tier);break
		for d in C.SUPPORTS:
			if m.s.support.has(d.id) and m.s.support[d.id].level<mini(m.s.room,5):
				if m.upgrade_support(d.id):purchases+=1
		# Raise the weakest trained member first, balancing all five instead of a single carry.
		for attempt in range(40):
			var lowest=0
			for i in range(5):
				if m.s.people[i].level<m.s.people[lowest].level:lowest=i
			if m.s.people[lowest].level<mini(m.s.room*15,3+int(m.s.max_stage*.52)) and m.grow(lowest):purchases+=1
			else:break
		for role in range(5):
			if m.s.people[role].equipment<mini(m.s.room*10,1+int(m.s.max_stage*.3)) and m.upgrade(role,"equipment"):purchases+=1
			if m.s.people[role].talent<mini(10,m.s.room) and m.upgrade(role,"talent"):purchases+=1
		if fights%100==0:print("PROGRESS ",fights," battles / stage ",m.s.max_stage," / defeats ",defeats)
	if not m.s.wins.has("300"):failures+=1
	var out={"fights":fights,"defeats":defeats,"purchases":purchases,"simulated_seconds":simulated,"final_stage":m.s.max_stage,"cleared":m.s.wins.size(),"room":m.s.room,"people":m.s.people,"failures":failures,"note":"Automated spending policy using earned resources; no invulnerability or currency injection. 10 encounter themes at 30 difficulty levels, not 300 unique narratives."}
	var f=FileAccess.open("res://docs/earth-production/progression-report.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(out,"  "));f.close()
	print("EARTH PROGRESSION ",JSON.stringify(out))
	quit(1 if failures else 0)
