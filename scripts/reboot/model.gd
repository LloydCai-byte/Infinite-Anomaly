extends RefCounted
const C = preload("res://scripts/reboot/catalog.gd")
var s: Dictionary = {}
var error = ""
var notice = ""
var events: Array = []
var dirty = false

func _init() -> void:
	reset("未命名基地")

func reset(base_name: String) -> void:
	s = {"schema_version":1,"design_version":C.VERSION,"base_name":base_name,"credits":150,"alloy":8,"tier":1,"intro":0,"intro_done":false,"wins":{"M01":0,"M02":0,"M03":0},"people":[],"inventory":[],"next_item":9,"next_run":1,"battle":{},"training":{},"result":{},"auto":"return","speed":1,"playtime":0.0,"selected_mission":"M01","selected_person":0,"dialogues":[],"settings":{"volume":0.65,"blood":true,"large":false,"background":true,"flash":true},"saved_at":0.0}
	for i in range(4):
		var p = {"id":C.PEOPLE[i].id,"body":1,"skill":1,"weapon":"item_%d"%(i*2+1),"armor":"item_%d"%(i*2+2)}
		s.people.append(p)
		s.inventory.append({"id":p.weapon,"role":i,"slot":"weapon","mk":1,"level":1})
		s.inventory.append({"id":p.armor,"role":i,"slot":"armor","mk":1,"level":1})
	error = ""
	dirty = true

func import_state(data: Dictionary) -> bool:
	if int(data.get("schema_version",0)) != 1:
		error = "此存档版本与当前程序不兼容，原文件已保留。"
		return false
	if not data.get("people",[]) is Array or data.people.size()!=4 or not data.get("wins",{}) is Dictionary or not data.has("inventory"):
		error = "存档内容不完整，原文件已保留。"
		return false
	s = data.duplicate(true)
	events.clear()
	return true

func item(id: String) -> Dictionary:
	for v in s.inventory:
		if v.id == id: return v
	return {}

func stats(index: int) -> Dictionary:
	var d = C.PEOPLE[index]
	var p = s.people[index]
	var w = item(p.weapon)
	var a = item(p.armor)
	var hp = d.hp*(1.0+.08*(p.body-1)+.03*(a.get("level",1)-1))
	var atk = d.atk*(1.0+.03*(p.body-1)+.1*(w.get("level",1)-1))+10*(w.get("mk",1)-1)
	var armor = d.armor+6*(a.get("level",1)-1)+10*(a.get("mk",1)-1)
	return {"hp":hp,"atk":atk,"armor":armor,"interval":d.interval,"range":d.range,"power":roundi(hp/10+atk/d.interval*3+armor*2+(10 if index==3 else 0)+p.skill*15)}

func power() -> int:
	var total=0
	for i in range(4): total += stats(i).power
	return total

func active() -> bool:
	return not s.battle.is_empty() and s.battle.get("active",false)

func unlocked(id: String) -> bool:
	return id=="M01" or (id=="M02" and s.wins.M01>0) or (id=="M03" and s.wins.M02>0)

func cap() -> int: return int(s.tier)*5

func fail(message: String) -> bool:
	error=message
	return false

func growth_available() -> bool:
	if active(): return fail("小队正在出战，召回后才可升级、制造或换装。")
	if not s.training.is_empty(): return fail("队员正在训练，请等待完成或取消训练。")
	return true

func pay(credits: int, alloy: int) -> bool:
	if s.credits<credits or s.alloy<alloy:
		return fail("还差 %d 积分 / %d 合金。" % [maxi(0,credits-s.credits),maxi(0,alloy-s.alloy)])
	s.credits-=credits
	s.alloy-=alloy
	return true

func body_cost(index: int) -> int: return 35+15*int(s.people[index].body)

func upgrade(index: int, kind: String) -> bool:
	if not growth_available(): return false
	var p = s.people[index]
	if kind=="body":
		if p.body>=cap(): return fail("已到成长上限，需要基地 T%d。" % (s.tier+1))
		if not pay(body_cost(index),0): return false
		p.body+=1
	elif kind=="skill":
		if p.skill>=5: return fail("职业能力已满级。")
		if not pay(180*int(p.skill),4*int(p.skill)): return false
		p.skill+=1
	else:
		var gear = item(p.get(kind,""))
		if gear.is_empty(): return fail("没有可升级的装备。")
		if gear.level>=cap(): return fail("已到成长上限，需要基地 T%d。" % (s.tier+1))
		var n = int(gear.level)
		if not pay((50+30*n) if kind=="weapon" else (40+25*n),1+int(n/3) if kind=="weapon" else 1+int(n/4)): return false
		gear.level+=1
	dirty=true
	notice="%s的%s提升了。"%[C.PEOPLE[index].name,{"body":"体质","skill":"能力","weapon":"武器","armor":"防具"}[kind]]
	return true

func manufacture(role: int, slot_name: String, mk: int) -> bool:
	if not growth_available(): return false
	if s.wins.M01<1: return fail("完成 M01 后解锁标准制造配方。")
	if mk==2 and ((role==1 and s.wins.M02<1) or (role!=1 and s.wins.M03<1)):
		return fail("完成 %s 后解锁此配方。" % ("M02" if role==1 else "M03"))
	if not pay(100 if mk==1 else 180,4 if mk==1 else 6): return false
	var id="item_%d"%s.next_item
	s.next_item+=1
	s.inventory.append({"id":id,"role":role,"slot":slot_name,"mk":mk,"level":1})
	dirty=true
	notice="制造完成，成品已放入装备库存。"
	return true

func equip(index: int, id: String) -> bool:
	if not growth_available(): return false
	var v=item(id)
	if v.is_empty() or int(v.role)!=index: return fail("此装备不适用于该队员。")
	s.people[index][v.slot]=id
	dirty=true
	notice="已更换装备，原装备保留在库存中。"
	return true

func dismantle(id: String) -> bool:
	if not growth_available(): return false
	var v=item(id)
	if v.is_empty(): return fail("该装备已不存在。")
	for p in s.people:
		if p.weapon==id or p.armor==id: return fail("已装备的物品不能分解，请先换下。")
	var count=0
	for other in s.inventory:
		if other.role==v.role and other.slot==v.slot: count+=1
	if count<=1: return fail("不能分解该职业最后一件可用装备。")
	s.alloy+=2 if v.mk==1 else 3
	s.inventory.erase(v)
	dirty=true
	notice="分解完成，合金已返还。"
	return true

func train() -> bool:
	if not growth_available(): return false
	var cost=0
	var ids=[]
	for i in range(4):
		if s.people[i].body<cap():
			cost+=body_cost(i)
			ids.append(i)
	if ids.is_empty(): return fail("所有队员已达当前基地上限。")
	if not pay(cost,0): return false
	s.training={"remaining":30.0,"cost":cost,"people":ids}
	dirty=true
	return true

func cancel_training() -> bool:
	if s.training.is_empty(): return fail("没有进行中的训练。")
	s.credits+=s.training.cost
	s.training={}
	dirty=true
	notice="已取消训练，积分全部退回。"
	return true

func facility() -> bool:
	if not growth_available(): return false
	if s.tier>=2: return fail("当前章节的基地设施已全部建成。")
	if s.wins.M03<1: return fail("完成 M03 高架桥底后可升级 T2。")
	if not pay(500,12): return false
	s.tier=2
	dirty=true
	notice="基地升至 T2，成长上限提升到 10 级。"
	return true

func depart(id: String) -> bool:
	if active(): return fail("小队已经出发。")
	if not s.training.is_empty(): return fail("训练尚未结束，请先完成或取消训练。")
	if not unlocked(id): return fail("需要先完成前一个任务。")
	var run_id="run_%d"%int(s.next_run)
	s.next_run+=1
	s.selected_mission=id
	s.result={}
	s.battle={"active":true,"id":run_id,"mission":id,"wave":0,"phase":"travel","wait":1.8,"time":0.0,"units":[],"completed":0,"credits":0,"alloy":0,"stats":[],"seq":0}
	for i in range(4):
		var st=stats(i)
		var d=C.PEOPLE[i]
		s.battle.units.append({"id":d.id,"side":0,"role":i,"boss":false,"hp":st.hp,"max_hp":st.hp,"atk":st.atk,"armor":st.armor,"interval":st.interval,"range":st.range,"x":280.0-i*45,"y":405.0+i*61,"cd":0.2+i*.16,"skill_cd":d.cd*.7,"anim":"idle","anim_time":0.0,"flash":0.0,"shield":0.0,"shield_time":0.0,"dead_time":0.0})
		s.battle.stats.append({"name":d.name,"damage":0.0,"taken":0.0,"heal":0.0})
	dirty=true
	return true

func alive(side: int) -> Array:
	var a=[]
	for u in s.battle.get("units",[]):
		if int(u.side)==side and u.hp>0: a.append(u)
	return a

func spawn_wave() -> void:
	var b=s.battle
	var d=C.mission(b.mission)
	var w=d.waves[b.wave]
	for u in b.units.duplicate():
		if u.side==1: b.units.erase(u)
	for i in range(int(w.count)+(1 if w.boss else 0)):
		var boss=bool(w.boss) and i==w.count
		b.seq+=1
		var hp=(450.0 if boss else 70.0)*d.factor*2.4
		var attack=(18.0 if boss else 8.0)*pow(d.factor,.75)
		var role=C.MISSIONS.find(d)
		b.units.append({"id":"e_%d"%b.seq,"side":1,"role":role,"boss":boss,"hp":hp,"max_hp":hp,"atk":attack,"armor":5.0*role+(5 if boss else 0),"interval":1.6 if boss else 1.4,"range":260.0 if role==1 else (90.0 if boss else 60.0),"x":1300.0+(i%3)*65,"y":408.0+(i%4)*56,"cd":.4+(i%4)*.12,"skill_cd":99.0,"anim":"run","anim_time":0.0,"flash":0.0,"shield":0.0,"shield_time":0.0,"dead_time":0.0})
	b.phase="fight"
	events.append({"type":"wave","value":b.wave+1})
	dirty=true

func tick(delta: float) -> void:
	s.playtime+=delta
	if not s.training.is_empty():
		s.training.remaining-=delta
		if s.training.remaining<=0:
			for i in s.training.people: s.people[int(i)].body+=1
			s.training={}
			dirty=true
			notice="训练完成，全队体质已经提升。"
			events.append({"type":"training"})
	if not active(): return
	var b=s.battle
	b.time+=delta
	if b.phase in ["travel","between"]:
		b.wait-=delta
		if b.wait<=0: spawn_wave()
		return
	for u in b.units:
		u.anim_time+=delta
		u.flash=maxf(0,u.flash-delta)
		u.shield_time=maxf(0,u.shield_time-delta)
		if u.shield_time<=0: u.shield=0.0
		if u.hp<=0:
			u.dead_time+=delta
			continue
		u.cd=maxf(0.0,u.cd-delta)
		u.skill_cd=maxf(0.0,u.skill_cd-delta)
		var foes=alive(1-int(u.side))
		if foes.is_empty(): continue
		var target=nearest(u,foes)
		var dx=target.x-u.x
		var dy=target.y-u.y
		var dist=sqrt(dx*dx+dy*dy)
		if dist>u.range:
			var speed=125.0 if u.side==0 else (105.0 if u.role==2 else 76.0)
			u.x+=dx/dist*speed*delta
			u.y+=dy/dist*speed*delta
			set_anim(u,"run")
		else:
			if u.anim=="run" or (u.anim=="attack" and u.anim_time>=.48): set_anim(u,"idle")
			if u.side==0 and u.skill_cd<=0:
				use_skill(u,target,foes)
				u.skill_cd=C.PEOPLE[u.role].cd
			if u.cd<=0 and target.hp>0:
				set_anim(u,"attack",true)
				u.cd=u.interval
				hit(u,target,u.atk)
				events.append({"type":"attack","role":u.role,"side":u.side,"x":u.x,"y":u.y,"tx":target.x,"ty":target.y})
	if alive(0).is_empty():
		finish("defeat")
	elif alive(1).is_empty():
		complete_wave()

func set_anim(u: Dictionary, name: String, force=false) -> void:
	if force or u.anim!=name:
		u.anim=name
		u.anim_time=0.0

func nearest(u: Dictionary, units: Array) -> Dictionary:
	var best=units[0]
	var distance=INF
	for v in units:
		var d=(u.x-v.x)*(u.x-v.x)+(u.y-v.y)*(u.y-v.y)
		if d<distance:
			distance=d
			best=v
	return best

func hit(u: Dictionary, target: Dictionary, attack: float, penetration=1.0) -> void:
	if target.hp<=0: return
	var damage=maxf(1,roundf(attack*100.0/(100.0+target.armor*penetration)))
	var absorbed=minf(target.shield,damage)
	target.shield-=absorbed
	damage-=absorbed
	var real=minf(target.hp,damage)
	target.hp=maxf(0,target.hp-damage)
	target.flash=.11
	if u.side==0: s.battle.stats[u.role].damage+=real
	if target.side==0: s.battle.stats[target.role].taken+=real
	events.append({"type":"hit","x":target.x,"y":target.y,"value":roundi(real),"side":target.side})
	if target.hp<=0:
		set_anim(target,"dead",true)
		events.append({"type":"death","side":target.side,"role":target.role})
	# Incoming hits never change the surviving target's attack timer or animation.

func use_skill(u: Dictionary, target: Dictionary, foes: Array) -> void:
	var level=int(s.people[u.role].skill)
	match int(u.role):
		0:
			u.shield=maxf(u.shield,30+12*(level-1))
			u.shield_time=4
			hit(u,target,u.atk*(1.2+.2*(level-1)))
		1:
			for foe in foes.slice(0,3): hit(u,foe,u.atk*(.8+.15*(level-1)))
		2:
			for foe in foes.slice(0,6): hit(u,foe,u.atk*(1.5+.2*(level-1)),.5)
		3:
			var patient=u
			for ally in alive(0):
				if ally.hp/ally.max_hp<patient.hp/patient.max_hp: patient=ally
			var healing=minf(patient.max_hp-patient.hp,40+15*(level-1))
			patient.hp+=healing
			s.battle.stats[u.role].heal+=healing
			events.append({"type":"heal","x":patient.x,"y":patient.y,"value":roundi(healing)})
	set_anim(u,"attack",true)
	events.append({"type":"skill","role":u.role,"x":u.x,"y":u.y})

func complete_wave() -> void:
	var b=s.battle
	var d=C.mission(b.mission)
	b.completed+=1
	var weight=0
	for i in range(int(b.completed)): weight+=int(d.waves[i].weight)
	var earned_c=int(d.credits*weight/100)
	var earned_a=int(d.alloy*weight/100)
	s.credits+=earned_c-int(b.credits)
	s.alloy+=earned_a-int(b.alloy)
	b.credits=earned_c
	b.alloy=earned_a
	dirty=true
	if b.completed>=d.waves.size():
		s.wins[b.mission]+=1
		finish("victory")
		return
	for ally in alive(0):
		ally.hp=ally.max_hp
		ally.shield=0
		ally.x=300.0-ally.role*42
		ally.y=405.0+ally.role*61
		set_anim(ally,"idle")
	b.wave+=1
	b.phase="between"
	b.wait=2.0
	events.append({"type":"between"})

func finish(outcome: String) -> void:
	var b=s.battle
	if not b.get("active",false): return
	b.active=false
	s.result={"run_id":b.id,"mission":b.mission,"outcome":outcome,"completed":b.completed,"credits":b.credits,"alloy":b.alloy,"time":b.time,"stats":b.stats.duplicate(true),"wins":s.wins[b.mission]}
	if outcome!="victory": s.auto="return"
	dirty=true
	events.append({"type":"result","outcome":outcome})

func recall() -> bool:
	if not active(): return fail("小队已经返回。")
	finish("recall")
	return true

func quality(id: String) -> String:
	var wins=int(s.wins[id])
	return "钻石" if wins>=25 else ("金卡" if wins>=8 else ("普通" if wins>0 else "未获得"))
