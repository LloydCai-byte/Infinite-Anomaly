extends RefCounted
const C = preload("res://scripts/earth/catalog.gd")
const Home = preload("res://scripts/earth/home.gd")
const Loot = preload("res://scripts/earth/loot.gd")
var s: Dictionary = {}
var error = ""
var events: Array = []
var invincible=false

func _init() -> void: reset()

func reset() -> void:
	s = {"schema":1,"version":C.VERSION,"intro":0,"intro_done":false,"credits":180,"alloy":8,"cores":0,"room":1,"max_stage":1,"wins":{},"people":[],"support":{},"result":{},"battle":{},"saved_at":0.0}
	s.home=Home.new_state()
	s.inventory=[]
	s.equipped=[{},{},{},{},{}]
	s.loot_serial=1
	s.loot_seed=int(randi())
	for p in C.PEOPLE:
		s.people.append({"id":p.id,"level":1,"suit":1,"owned_suits":[1],"equipment":1,"talent":1})
	events.clear()
	error = ""

func import_state(data: Dictionary) -> bool:
	data=data.duplicate(true)
	# Additive migration keeps the 0.6 save and its battle/intro progress intact.
	if not data.has("home"): data.home=Home.new_state()
	if not data.has("inventory"):
		data.inventory=[];data.equipped=[{},{},{},{},{}];data.loot_serial=1;data.loot_seed=104729
	if not Loot.valid_inventory(data):return fail("装备记录无法通过校验，原存档保留。")
	if not Home.valid(data.home): return fail("房间位置记录无效。")
	if data.get("schema",0)!=1 or not data.get("people") is Array or data.people.size()!=5:
		return fail("这不是有效的地球篇五人存档。原存档保留。")
	for i in range(5):
		if not data.people[i] is Dictionary or data.people[i].get("id","")!=C.PEOPLE[i].id:
			return fail("存档中的队员身份不一致。原文件保留。")
		var p=data.people[i]
		for key in ["level","suit","equipment","talent"]:
			if not p.get(key) is int or p[key]<1 or p[key]>150: return fail("队员成长字段损坏。")
		if p.suit>3 or p.talent>10 or p.equipment>100 or not p.get("owned_suits") is Array: return fail("套装或成长范围无效。")
		if p.suit not in p.owned_suits or p.owned_suits.is_empty():return fail("已穿戴套装未记录。")
		for tier in p.owned_suits:
			if not tier is int or tier<1 or tier>3:return fail("套装版本无效。")
	for key in s.keys():
		if not data.has(key) or typeof(data[key])!=typeof(s[key]):
			return fail("存档字段不完整："+key)
	if data.credits<0 or data.alloy<0 or data.cores<0 or data.intro<0 or data.intro>31:
		return fail("存档数值无法通过校验。")
	if data.room<1 or data.room>10 or data.max_stage<1 or data.max_stage>C.CAMPAIGN_STAGE_COUNT:return fail("关卡或空间等级无效。")
	for key in data.wins:
		if not str(key).is_valid_int() or int(key)<1 or int(key)>C.STAGE_COUNT or not data.wins[key] is int or data.wins[key]<1:return fail("任务记录无效。")
	for key in data.support:
		var support=data.support[key]
		if support_info(str(key)).is_empty() or not support is Dictionary:return fail("支援记录无效。")
		if not support.get("level") is int or support.level<0 or support.level>10 or not support.get("enabled") is bool:return fail("支援等级无效。")
	if not data.battle.is_empty():
		var b=data.battle
		if not b.has("gear_clock"):b.gear_clock={}
		if not b.gear_clock is Dictionary:return fail("装备支援计时无效。")
		if b.has("gear_triggers") and (not b.gear_triggers is int or b.gear_triggers<0):return fail("装备支援次数无效。")
		for key in b.gear_clock:
			if not str(key).is_valid_int() or int(key)<1 or int(key)>=data.loot_serial or not finite_number(b.gear_clock[key]) or b.gear_clock[key]<0:return fail("装备支援计时无效。")
		for key in ["active","stage","encounter","units","time","travel","killed","damage","healing","effects","support_clock","next_id","camera"]:
			if not b.has(key):return fail("战斗记录不完整。")
		for key in ["stage","encounter","killed","next_id"]:
			if not b[key] is int or b[key]<0:return fail("战斗计数字段无效。")
		if not b.units is Array or b.units.size()<5 or b.stage<1 or b.stage>C.STAGE_COUNT or b.encounter<0 or b.encounter>C.mission(b.stage).encounters:return fail("战斗关卡记录无效。")
		if not b.active is bool or not b.effects is Array or not b.support_clock is Dictionary:return fail("战斗类型无效。")
		for key in ["time","travel","damage","healing","camera"]:
			if not finite_number(b[key]):return fail("战斗数值无效。")
		for key in b.support_clock:
			if support_info(str(key)).is_empty() or not finite_number(b.support_clock[key]):return fail("支援计时无效。")
		for e in b.effects:
			if not e is Dictionary or e.get("type","") not in ["hit","heal","laser","enemy_laser","bomb"]:return fail("战场效果类型无效。")
			for key in ["x","y","life"]:
				if not finite_number(e.get(key)):return fail("战场效果数值无效。")
			for key in ["source_x","source_y"]:
				if e.has(key) and not finite_number(e[key]):return fail("效果起点无效。")
			if e.type in ["hit","heal"] and not finite_number(e.get("amount")):return fail("伤害或恢复效果无效。")
		var seen={}
		for i in range(b.units.size()):
			var u=b.units[i]
			if not u is Dictionary:return fail("战斗单位无效。")
			for key in ["id","side","role","hp","max_hp","atk","armor","interval","x","lane","cooldown","skill_clock","state","anim","move_distance"]:
				if not u.has(key):return fail("战斗单位缺少字段。")
			if not u.id is int or not u.side is int or not u.role is int:return fail("战斗单位身份类型无效。")
			if seen.has(u.id) or u.side not in [0,1] or u.role<0 or u.role>4:return fail("战斗单位身份冲突。")
			seen[u.id]=true
			if i<5 and (u.side!=0 or u.role!=i):return fail("编队不是五位原战士。")
			for key in ["hp","max_hp","atk","armor","interval","x","lane","cooldown","skill_clock","anim","move_distance"]:
				if not finite_number(u[key]):return fail("战斗单位包含无效数值。")
			if u.hp<0 or u.hp>u.max_hp or u.max_hp<=0 or u.interval<=0:return fail("单位生命或间隔无效。")
			if u.state not in ["idle","move","attack","hit","fall"]:return fail("动作状态无效。")
			for key in ["shield","marked","slow","facing"]:
				if u.has(key) and not finite_number(u[key]):return fail("单位状态数值无效。")
			if u.side==0:
				if not u.get("suit") is int or u.suit<1 or u.suit>3 or not finite_number(u.get("skill_factor")):return fail("单位套装或技能无效。")
			elif not u.get("boss") is bool:return fail("异常首领标记无效。")
			elif C.Anomalies.has_stage(b.stage):
				if not u.has("variant"):u.variant=4 if u.boss else (u.id-5)%5
				if not finite_number(u.variant) or u.variant<0 or u.variant>4 or int(u.variant)!=u.variant:return fail("怪谈角色编号无效。")
	if not data.result.is_empty():
		for key in ["reason","stage","credits","alloy","cores","first","time","killed","damage","healing"]:
			if not data.result.has(key):return fail("结算记录不完整。")
		if data.result.reason not in ["victory","recall","defeat"] or data.battle.get("active",false):return fail("结算状态冲突。")
		if not data.result.get("loot",[]) is Array:return fail("战利品记录无效。")
		for item in data.result.get("loot",[]):
			if not Loot.valid(item):return fail("战利品记录无效。")
	s = data.duplicate(true)
	events.clear()
	return true

func finite_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

func fail(message: String) -> bool:
	error = message
	return false

func active() -> bool: return s.battle.get("active",false)

func enter_home_room(id: String,via_map=false) -> bool:
	if active() or not s.result.is_empty(): return fail("请先完成召回结算。")
	if id not in Home.ROOM_IDS: return fail("没有这个房间。")
	if not via_map and id not in Home.LINKS[s.home.room]: return fail("这里没有通往该房间的门。")
	s.home.room=id
	return true

func stats(index: int) -> Dictionary:
	return stats_for(index,s.people[index])

func stats_for(index: int,p: Dictionary) -> Dictionary:
	var base = C.PEOPLE[index]
	var suit=C.SUITS[p.suit-1]
	var gear=1+.045*(p.equipment-1)
	var bonus=equipment_bonus(index)
	return {"hp":base.hp*(1+.09*(p.level-1))*suit.factor*gear*(1+bonus.hp/100),"atk":base.atk*(1+.07*(p.level-1))*suit.factor*gear*(1+bonus.atk/100),"armor":(base.armor*suit.factor+1.4*(p.equipment-1))*(1+bonus.armor/100),"interval":base.interval/(1+bonus.haste/100),"weapon":suit.weapons[index],"skill_factor":(1+.16*(p.talent-1))*(1+bonus.skill/100)}

func preview_growth(index: int,kind: String) -> Dictionary:
	if index<0 or index>=5 or kind not in ["level","equipment","talent"]:return {}
	var p=s.people[index].duplicate(true)
	var limit=s.room*15 if kind=="level" else s.room*10 if kind=="equipment" else mini(10,s.room*3)
	if p[kind]>=limit:return {}
	p[kind]+=1
	return stats_for(index,p)

func preview_suit(index: int,tier: int) -> Dictionary:
	if index<0 or index>=5 or tier<1 or tier>C.SUITS.size():return {}
	var p=s.people[index].duplicate(true);p.suit=tier
	return stats_for(index,p)

func support_preview(id: String,next_level=false) -> String:
	var d=support_info(id)
	if d.is_empty():return ""
	var level=int(s.support.get(id,{}).get("level",0))+(1 if next_level else 0)
	level=maxi(1,level)
	var power=0.0
	for i in range(5):power+=stats(i).atk/5.0
	match id:
		"laser":return "每 %.0f 秒：单体 %.0f 基础伤害（穿透护甲）"%[d.interval,power*(2+.55*(level-1))]
		"regen":return "每 %.0f 秒：全体存活者恢复 %.1f%% 最大生命"%[d.interval,100*(.04+.012*(level-1))]
		"bomb":return "每 %.0f 秒：对每个敌人造成 %.0f 基础伤害"%[d.interval,power*(1.2+.3*(level-1))]
	return ""

func upgrade_cost(index: int,kind: String) -> Dictionary:
	if kind=="equipment":
		var level=s.people[index].equipment
		return {"credits":65+level*25,"alloy":2+int(level/4),"cores":0}
	if kind=="talent":
		var level=s.people[index].talent
		return {"credits":130*level,"alloy":level*3,"cores":0}
	return {"credits":level_cost(index),"alloy":0,"cores":0}

func upgrade(index: int,kind: String) -> bool:
	if kind=="level": return grow(index)
	if active(): return fail("请先召回小队。")
	if index<0 or index>=5 or kind not in ["equipment","talent"]: return fail("升级项目无效。")
	var limit=s.room*10 if kind=="equipment" else mini(10,s.room*3)
	if s.people[index][kind]>=limit: return fail("达到当前上限，请提升主神空间。")
	var cost=upgrade_cost(index,kind)
	if not pay(cost.credits,cost.alloy,cost.cores): return false
	s.people[index][kind]+=1
	return true

func room_cost() -> Dictionary:
	return {"credits":400*s.room,"alloy":15*s.room,"cores":s.room,"gate":[3,6,15,30,60,120,180,240,290][clampi(s.room-1,0,8)]}

func upgrade_room() -> bool:
	if active(): return fail("小队作战时不能改建空间。")
	if s.room>=10: return fail("主神空间已达本篇上限。")
	var cost=room_cost()
	if not s.wins.has(str(cost.gate)): return fail("先完成第 %d 关，才能进行本次改建。"%cost.gate)
	if not pay(cost.credits,cost.alloy,cost.cores): return false
	s.room+=1
	return true

func support_info(id: String) -> Dictionary:
	for d in C.SUPPORTS:
		if d.id==id: return d
	return {}

func support_cost(id: String) -> Dictionary:
	var level=int(s.support.get(id,{}).get("level",0))
	return {"credits":220*(level+1),"alloy":5*(level+1),"cores":0 if level<2 else 1}

func upgrade_support(id: String) -> bool:
	if active(): return fail("请召回小队后再维护装置。")
	if not s.support.has(id) or support_info(id).is_empty(): return fail("尚未击败持有该装置的异常。")
	var level=s.support[id].level
	if level>=mini(10,s.room*2): return fail("装置达到当前空间的升级上限。")
	var cost=support_cost(id)
	if not pay(cost.credits,cost.alloy,cost.cores): return false
	s.support[id].level+=1
	if level==0: s.support[id].enabled=true
	return true

func toggle_support(id: String) -> bool:
	if active(): return fail("请召回小队后调整支援。")
	if not s.support.has(id) or s.support[id].level<1: return fail("请先购置该装置。")
	s.support[id].enabled=not s.support[id].enabled
	return true

func tick_support(delta: float) -> void:
	var b=s.battle
	if alive(0).is_empty() or alive(1).is_empty(): return
	var power=0.0
	for u in alive(0): power+=u.atk/5.0
	for d in C.SUPPORTS:
		var support=s.support.get(d.id,{})
		if support.get("level",0)<1 or not support.get("enabled",false): continue
		b.support_clock[d.id]=float(b.support_clock.get(d.id,0.0))+delta
		if b.support_clock[d.id]<d.interval: continue
		b.support_clock[d.id]-=d.interval
		var level=float(support.level)
		var targets=alive(1)
		if d.id=="laser" and not targets.is_empty():
			var target=targets[0]
			damage({"side":0},target,power*(2+.55*(level-1))+target.armor)
			b.effects.append({"type":"laser","x":target.x,"y":target.lane-100,"life":.48})
		elif d.id=="bomb":
			for t in targets:
				damage({"side":0},t,power*(1.2+.3*(level-1)))
				b.effects.append({"type":"bomb","x":t.x,"y":t.lane-60,"life":.7})
		elif d.id=="regen":
			for u in alive(0):
				var amount=minf(u.max_hp-u.hp,u.max_hp*(.04+.012*(level-1)))
				u.hp+=amount;b.healing+=amount
				if events.size()<20:events.append({"type":"sound","id":"heal"})
				b.effects.append({"type":"heal","x":u.x,"y":u.lane,"amount":amount,"life":.7})
		b["support_triggers"]=int(b.get("support_triggers",0))+1

func pay(credits: int,alloy: int,cores: int=0) -> bool:
	if credits<0 or alloy<0 or cores<0: return fail("费用无效。")
	if s.credits<credits or s.alloy<alloy or s.cores<cores: return fail("资源不足：需要 %d 积分、%d 合金、%d 核心。"%[credits,alloy,cores])
	s.credits-=credits; s.alloy-=alloy; s.cores-=cores
	return true

func make_suit(index: int,tier: int) -> bool:
	if active(): return fail("先召回小队，再制造战斗服。")
	if index<0 or index>=5 or tier<1 or tier>C.SUITS.size(): return fail("套装无效。")
	var suit=C.SUITS[tier-1]
	if tier in s.people[index].owned_suits: return fail("这名战士已拥有该套装。")
	if s.room<suit.room or suit.unlock>0 and not s.wins.has(str(suit.unlock)): return fail("需要空间 T%d 并完成第 %d 关。"%[suit.room,suit.unlock])
	if not pay(suit.credits,suit.alloy,suit.cores): return false
	s.people[index].owned_suits.append(tier)
	return true

func equip_suit(index: int,tier: int) -> bool:
	if active(): return fail("先召回小队，再更换套装。")
	if index<0 or index>=5 or tier not in s.people[index].owned_suits: return fail("未拥有这套战斗服。")
	s.people[index].suit=tier
	return true

func level_cost(index: int) -> int: return 35+int(s.people[index].level)*15

func grow(index: int) -> bool:
	if active(): return fail("先召回小队，再进行培养。")
	if index<0 or index>=5: return fail("请选择队员。")
	if s.people[index].level>=s.room*15: return fail("需要提升主神空间等级。")
	var cost=level_cost(index)
	if s.credits<cost: return fail("积分不足，还差 %d。"%(cost-s.credits))
	s.credits-=cost
	s.people[index].level+=1
	return true

func depart(stage: int) -> bool:
	if active() or not s.result.is_empty(): return fail("请先完成本次结算。")
	if not s.intro_done: return fail("请先完成开场。")
	if not C.stage_unlocked(stage,s.max_stage): return fail("该任务尚未解锁。")
	s.battle={"active":true,"stage":stage,"encounter":0,"units":[],"time":0.0,"travel":1.5,"killed":0,"damage":0.0,"healing":0.0,"effects":[],"support_clock":{},"gear_clock":{},"next_id":5,"camera":0.0}
	for i in range(5):
		var d=stats(i)
		s.battle.units.append({"id":i,"side":0,"role":i,"hp":d.hp,"max_hp":d.hp,"atk":d.atk,"armor":d.armor,"interval":d.interval,"x":450.0-i*66,"lane":635.0+i*26,"cooldown":float(i)*.16,"skill_clock":3.0+float(i),"state":"move","anim":0.0,"move_distance":0.0,"suit":s.people[i].suit,"skill_factor":d.skill_factor,"shield":0.0,"marked":0.0})
	events.clear()
	return true

func alive(side: int) -> Array:
	return s.battle.get("units",[]).filter(func(u): return u.side==side and u.hp>0)

func spawn_encounter() -> void:
	var b=s.battle
	var m=C.mission(b.stage)
	b.encounter+=1
	var base_x=0.0
	for u in alive(0): base_x=maxf(base_x,u.x)
	var count=m.schedule[b.encounter-1] if b.encounter<m.encounters else 1
	var anomaly=C.Anomalies.has_stage(b.stage)
	if anomaly:count=5
	for i in range(count):
		var boss=b.encounter==m.encounters and (not anomaly or i==4)
		var hp=(480.0 if boss else 140.0)*m.factor
		var x=base_x+590.0+i*112
		if anomaly:
			x=C.Anomalies.encounter_x(b.stage,b.encounter-1)+i*112
			hp=(360.0 if boss else 92.0)*m.factor
		if m.mechanic=="包围" and i==count-1: x=base_x-310
		b.units.append({"id":b.next_id,"side":1,"role":0,"hp":hp,"max_hp":hp,"atk":(23.0 if boss else 12.0)*m.factor,"armor":(10.0 if m.mechanic in ["重甲","变异"] else 3.0)*m.factor,"interval":1.05 if m.mechanic=="变异" else 1.5,"x":x,"lane":665.0+(i%4)*27,"cooldown":.6+i*.2,"skill_clock":6.0,"state":"move","anim":0.0,"move_distance":0.0,"boss":boss,"kind":m.enemy,"shield":hp*.25 if m.mechanic=="护盾" else 0.0,"marked":0.0})
		if anomaly:
			b.units[-1].variant=i if b.encounter==m.encounters else (b.encounter-1+i)%5
			b.units[-1].atk=(17.0 if boss else 8.0)*m.factor
			b.units[-1].lane=635.0+i*27
		b.next_id+=1

func tick(delta: float) -> void:
	if not active() or delta<=0: return
	var b=s.battle
	b.time+=delta
	for effect in b.effects: effect.life-=delta
	b.effects=b.effects.filter(func(e): return e.life>0)
	for u in b.units:
		u.anim+=delta
		u.cooldown=maxf(0,u.cooldown-delta)
		u.skill_clock=maxf(0,u.skill_clock-delta)
		u.marked=maxf(0,u.get("marked",0.0)-delta)
		u.slow=maxf(0,u.get("slow",0.0)-delta)
		if u.hp<=0: u.state="fall"
	if alive(0).is_empty(): settle("defeat"); return
	tick_support(delta)
	tick_gear(delta)
	if alive(1).is_empty():
		if b.encounter>=C.mission(b.stage).encounters: settle("victory"); return
		b.travel-=delta
		for u in alive(0):
			u.state="move"
			u.x+=148.0*delta
			u.move_distance+=148.0*delta
		var ready_to_spawn=b.travel<=0
		if C.Anomalies.has_stage(b.stage):
			var front=0.0
			for u in alive(0):front=maxf(front,u.x)
			ready_to_spawn=front>=C.Anomalies.encounter_x(b.stage,b.encounter)-700.0
		if ready_to_spawn: spawn_encounter(); b.travel=1.8
	else:
		for u in b.units:
			if u.hp<=0: continue
			var targets=alive(1-u.side)
			if targets.is_empty(): break
			var target=targets[0]
			for t in targets:
				if absf(t.x-u.x)<absf(target.x-u.x): target=t
			var reach=125.0 if u.side==1 else [135.0,155.0,115.0,260.0,320.0][u.role]
			u.facing=1.0 if target.x>=u.x else -1.0
			if absf(target.x-u.x)>reach:
				var previous=float(u.x)
				var speed=260.0 if u.side==0 else 175.0
				if u.slow>0: speed*=.65
				u.x=move_toward(u.x,target.x-signf(target.x-u.x)*reach,speed*delta)
				u.move_distance+=absf(u.x-previous)
				u.state="move"
			else:
				if u.state=="move": u.state="idle"; u.anim=0.0
				if u.cooldown<=0:
					u.state="attack"; u.anim=0.0
					u.cooldown=u.interval
					damage(u,target,u.atk)
				elif u.state=="attack" and u.anim>.42: u.state="idle"
			if u.side==1 and u.skill_clock<=0:
				u.skill_clock=8.0
				var mechanic=C.mission(b.stage).mechanic
				if mechanic=="再生":
					for t in alive(1): t.hp=minf(t.max_hp,t.hp+t.max_hp*.06)
				elif mechanic=="冰冻":
					for t in alive(0): t.slow=3.0
				elif u.boss and mechanic in ["激光","齐射","变异"]:
					for t in alive(0):
						damage(u,t,u.atk*.65)
						b.effects.append({"type":"enemy_laser","x":t.x,"y":t.lane-100,"life":.45})
			if u.side==0 and u.role!=4 and u.skill_clock<=0:
				u.skill_clock=10.0 if u.role!=3 else 12.0
				match int(u.role):
					0: u.shield=u.max_hp*.16*u.skill_factor
					1: damage(u,target,u.atk*2.2*u.skill_factor)
					2:
						for t in targets.slice(0,3): damage(u,t,u.atk*1.1*u.skill_factor)
					3: target.marked=4.0*u.skill_factor
			if u.side==0 and u.role==4 and u.skill_clock<=0:
				var weakest=alive(0)[0]
				for t in alive(0):
					if t.hp/t.max_hp<weakest.hp/weakest.max_hp: weakest=t
				var heal=minf(weakest.max_hp-weakest.hp,u.atk*1.8*u.skill_factor)
				weakest.hp+=heal
				b.healing+=heal
				if events.size()<20:events.append({"type":"sound","id":"heal"})
				b.effects.append({"type":"heal","x":weakest.x,"y":weakest.lane,"amount":heal,"life":.7})
				u.skill_clock=8.0
	var leader=0.0
	for u in alive(0): leader=maxf(leader,u.x)
	b.camera=maxf(0,leader-520.0)
	if C.Anomalies.has_stage(b.stage):b.camera=minf(b.camera,C.Anomalies.info(b.stage).world_width-1600)

func damage(attacker: Dictionary, target: Dictionary, amount: float) -> void:
	if target.hp<=0: return
	if invincible and target.side==0: return
	if attacker.get("side",1)==0 and events.size()<20:
		events.append({"type":"sound","id":["heavy","blade","heavy","shot","shot"][clampi(int(attacker.get("role",0)),0,4)]})
	if target.get("marked",0.0)>0: amount*=1.25
	var damage_after_armor=maxf(1,amount-target.armor)
	var absorb=minf(target.get("shield",0.0),damage_after_armor)
	target.shield=maxf(0,target.get("shield",0.0)-absorb)
	var applied=minf(target.hp,damage_after_armor-absorb)
	target.hp-=applied
	if target.side==1: s.battle.damage+=applied
	s.battle.effects.append({"type":"hit","x":target.x,"y":target.lane,"amount":applied,"life":.38})
	if target.hp<=0:
		target.state="fall"; target.anim=0.0
		if target.side==1: s.battle.killed+=1
	else:
		target.state="hit"; target.anim=0.0

func recall() -> bool:
	if not active(): return fail("小队已经回到房间。")
	settle("recall")
	return true

func settle(reason: String) -> void:
	if not active(): return
	var b=s.battle
	var m=C.mission(b.stage)
	var win=reason=="victory"
	var credits=m.credits if win else b.killed*10
	var alloy=m.alloy if win else int(b.killed/2)
	var cores=m.cores if win else 0
	var first=win and not s.wins.has(str(b.stage))
	var unlocks=[]
	if first: credits+=70; alloy+=3
	s.credits+=credits; s.alloy+=alloy; s.cores+=cores
	if win:
		s.wins[str(b.stage)]=int(s.wins.get(str(b.stage),0))+1
		if b.stage<=C.CAMPAIGN_STAGE_COUNT:s.max_stage=maxi(s.max_stage,mini(C.CAMPAIGN_STAGE_COUNT,b.stage+1))
		for d in C.SUPPORTS:
			if d.unlock==b.stage and not s.support.has(d.id):
				s.support[d.id]={"level":0,"enabled":false}
				unlocks.append(d.name)
	b.active=false
	var drops=[]
	if win:
		var item=Loot.make(int(m.get("reward_stage",b.stage)),s.loot_serial,s.loot_seed,first and b.stage==1)
		s.inventory.append(item);s.loot_serial+=1;drops.append(item.duplicate(true))
	s.result={"reason":reason,"stage":b.stage,"credits":credits,"alloy":alloy,"cores":cores,"first":first,"time":b.time,"killed":b.killed,"damage":b.damage,"healing":b.healing,"unlocks":unlocks,"loot":drops}
	events.append({"type":"settled"})

func close_result() -> void:
	if active() or s.result.is_empty(): return
	Home.reroll(s.home)
	s.result={}
	s.battle={}

func continue_battle(next_stage: int) -> bool:
	if active() or s.result.is_empty():return fail("当前没有可继续的结算。")
	var old_stage=int(s.result.stage)
	if next_stage!=old_stage and not (s.result.reason=="victory" and next_stage==C.next_stage(old_stage)):return fail("请从结算选择再次挑战或下一关。")
	if not C.stage_unlocked(next_stage,s.max_stage):return fail("下一处异常尚未开放。")
	var previous=s.duplicate(true)
	s.result={};s.battle={}
	if not depart(next_stage):s=previous;return false
	return true

func item_by_id(id: int) -> Dictionary:
	for item in s.inventory:
		if item.id==id:return item
	return {}

func item_owner(id: int) -> int:
	for i in range(5):
		if id in s.equipped[i].values():return i
	return -1

func equip_item(index: int,id: int) -> bool:
	if active():return fail("战斗中无法更换装备，请先完成结算。")
	var item=item_by_id(id)
	if index<0 or index>=5 or item.is_empty():return fail("装备或队员不存在。")
	var owner=item_owner(id)
	var slot=Loot.BASES[item.base].slot
	if owner>=0:s.equipped[owner].erase(slot)
	s.equipped[index][slot]=id
	return true

func unequip_item(index: int,slot: String) -> bool:
	if active():return fail("战斗中无法卸下装备。")
	if index<0 or index>=5 or slot not in Loot.SLOTS:return fail("装备槽无效。")
	s.equipped[index].erase(slot)
	return true

func equipment_bonus(index: int) -> Dictionary:
	var bonus={"hp":0.0,"atk":0.0,"armor":0.0,"haste":0.0,"skill":0.0}
	for id in s.equipped[index].values():
		var item=item_by_id(id)
		for key in item.get("affixes",{}):bonus[key]+=item.affixes[key]
	return bonus

func gear_spirits() -> Array:
	var spirits=[]
	for i in range(5):
		for slot in Loot.SLOTS:
			var item=item_by_id(s.equipped[i].get(slot,0))
			if item.is_empty():continue
			var special=Loot.BASES[item.base].special
			if special!="":spirits.append({"owner":i,"id":item.id,"kind":special,"quality":item.quality,"slot":Loot.SLOTS.find(slot)})
	return spirits

func tick_gear(delta: float) -> void:
	if alive(0).is_empty() or alive(1).is_empty():return
	var b=s.battle
	if not b.has("gear_clock"):b.gear_clock={}
	for spirit in gear_spirits():
		var owner=b.units[spirit.owner]
		if owner.hp<=0:continue
		var key=str(spirit.id)
		b.gear_clock[key]=float(b.gear_clock.get(key,0.0))+delta
		if b.gear_clock[key]<Loot.INTERVALS[spirit.kind]:continue
		b.gear_clock[key]-=Loot.INTERVALS[spirit.kind]
		var strength=1+.25*(spirit.quality-1)
		var foes=alive(1)
		if foes.is_empty():continue
		var source_x=owner.x-26+spirit.slot*36
		var source_y=owner.lane-258
		match spirit.kind:
			"laser":
				var target=foes[0]
				damage(owner,target,owner.atk*1.45*strength+target.armor)
				b.effects.append({"type":"laser","x":target.x,"y":target.lane,"source_x":source_x,"source_y":source_y,"life":.48})
			"bomb":
				for target in foes:damage(owner,target,owner.atk*.9*strength)
				b.effects.append({"type":"bomb","x":foes[0].x,"y":foes[0].lane,"life":.7})
			"regen":
				var friends=alive(0)
				friends.sort_custom(func(a,c):return a.hp/a.max_hp<c.hp/c.max_hp)
				var target=friends[0]
				var amount=minf(target.max_hp-target.hp,target.max_hp*.08*strength)
				target.hp+=amount;b.healing+=amount
				b.effects.append({"type":"heal","x":target.x,"y":target.lane,"amount":amount,"life":.7})
		b.gear_triggers=int(b.get("gear_triggers",0))+1
