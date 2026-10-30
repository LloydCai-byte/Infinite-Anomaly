extends "res://scripts/pixel_hyakki/model.gd"
const ElementVfx=preload("res://scripts/pixel_hyakki/element_vfx.gd")
var gear
var stats_live:Array=[]
var shields:Array=[]
var dots:Array=[]
var dot_turns:Array=[]
var slows:Array=[]
var looks_live:Array=[]
var powers_used={}
var run_loot:Array=[]

func reset(start_level:int=0)->void:
	run_loot=[]
	super.reset(start_level)

func attach(store)->void:
	gear=store;apply_loadout()
func spawn_stage()->void:
	super.spawn_stage()
	if gear!=null:apply_loadout()
func preview_stats(hero:int)->Dictionary:
	var st=gear.stats(hero)
	st.hp+=[480,600,440,460,420][hero]-260
	st.atk+=[86,92,92,64,94][hero]-34
	st.speed+=[26,22,25,29,23][hero]-[14,10,12,11,13][hero]
	return st
func apply_loadout()->void:
	stats_live=[];shields=[];dots=[];dot_turns=[];slows=[];powers_used={};looks_live=gear.equipped_looks()
	for u in units:
		var st={}
		if u.side==0:
			st=preview_stats(u.uid)
			var ratio=float(u.hp)/maxi(1,u.max_hp)
			u.max_hp=roundi(st.hp)
			u.hp=roundi(u.max_hp*ratio);u.power=roundi(st.atk)
			u.agility=st.speed
		else:
			for k in gear.G.AFFIX:st[k]=0.0
			st.merge({"armor":5.0,"crit":4.0,"crit_damage":150.0,"powers":[]},true)
		st.hp=u.max_hp;st.atk=u.power;st.speed=u.agility
		stats_live.append(st);shields.append(st.shield);dots.append(0.0);dot_turns.append(0);slows.append(0.0)
	var guardians=0
	for st in stats_live.slice(0,5):
		if "guardian" in st.powers:guardians+=1
	for st in stats_live.slice(0,5):st.armor+=mini(3,guardians)*5

func bridge()->void:
	gear.b={"theme":clampi(level_index(),0,2),"scene":encounter_tier(),"tier":1,"round":0,"units":[],"queue":[],"phase":"fighting","loot":[],"gold":0,"kills":0}
	for u in units:
		gear.b.units.append({"id":u.uid,"side":u.side,"hero":u.uid if u.side==0 else -1,"kind":(u.uid-5)%3,"name":u.name,"hp":float(u.hp),"maxhp":float(u.max_hp),"shield":shields[u.uid],"dot":dots[u.uid],"dot_turns":dot_turns[u.uid],"slow":slows[u.uid],"boss":is_boss_stage() and u.id=="oni","stats":stats_live[u.uid].duplicate(true)})
func resolve_event(e:Dictionary,source:int,kind:String)->void:
	for h in e.hits:
		ElementVfx.confirmed_hit(self,h,source,kind)
		var loss=ceili(h.before-h.after)
		# Integer animation HP must not report a kill before the gear model rewards it.
		if h.after>0:loss=mini(loss,maxi(0,units[h.id].hp-1))
		if loss>0:super.damage(source,h.id,loss,kind)
		elif h.tag!="":effects.append({"kind":"number","value":h.tag,"pos":units[h.id].pos+Vector2(-15,-125),"age":0.0,"life":.7,"color":Color("98cbd3")})
	for h in e.heals:
		ElementVfx.emit(self,h.id,"heal",source)
		units[h.id].hp=mini(units[h.id].max_hp,units[h.id].hp+roundi(h.amount))
		effects.append({"kind":"number","value":"+%d"%h.amount,"pos":units[h.id].pos+Vector2(0,-130),"age":0.0,"life":.7,"color":Color("82df96")})
	for i in range(units.size()):
		var u=gear.b.units[i];shields[i]=u.shield;dots[i]=u.dot;dot_turns[i]=u.dot_turns;slows[i]=u.slow;stats_live[i].armor=u.stats.armor
	if not gear.b.loot.is_empty():
		note("获得装备："+gear.G.name_of(gear.item_by_id(gear.b.loot.back())))
		last_skill="掉落 · "+gear.G.name_of(gear.item_by_id(gear.b.loot.back()))
		for drop in gear.b.get("drop_events",[]):
			var item=gear.item_by_id(drop.id).duplicate(true)
			run_loot.append(drop.id)
			effects.append({"kind":"loot","item":item,"pos":units[drop.enemy].pos,"age":0.0,"life":3.0})
	var changed=gear.b.kills>0;gear.b={}
	if changed and not gear.persist():note("装备保存失败："+gear.last_error)

func damage(source:int,target:int,amount:int,kind:String)->void:
	if gear==null or stats_live.size()!=units.size():super.damage(source,target,amount,kind);return
	bridge();var e={"hits":[],"heals":[]}
	if source>=0 and kind not in ["burn","dot","test"]:
		var actor=gear.b.units[source]
		if kind=="bullet":
			for k in ["fire","cold","lightning"]:actor.stats[k]*=.25
		gear.strike(actor,target,amount,e)
		if not powers_used.get(source,false):
			powers_used[source]=true
			if "echo" in actor.stats.powers and gear.b.units[target].hp>0:gear.strike(actor,target,units[source].power*.25,e)
			var remaining=2 if "chain" in actor.stats.powers else 1 if "cleave" in actor.stats.powers else 0
			for u in gear.b.units:
				if remaining<=0:break
				if u.side!=actor.side and u.id!=target and u.hp>0:
					gear.strike(actor,u.id,units[source].power*(.2 if "chain" in actor.stats.powers else .35),e);remaining-=1
	else:gear.deal(target,amount,e,false,"持续伤害" if kind in ["burn","dot"] else "")
	resolve_event(e,source,kind)

func begin_action(index:int)->void:
	if gear!=null and not stats_live.is_empty():
		if dot_turns[index]>0:
			dot_turns[index]-=1;damage(-1,index,roundi(dots[index]),"dot")
			if units[index].hp<=0:return
		bridge();var e={"hits":[],"heals":[]};var actor=gear.b.units[index]
		if "barrier" in actor.stats.powers:actor.shield+=10
		var healing=[]
		if "mercy" in actor.stats.powers:healing.append(12+actor.stats.atk*.18)
		if index==3:healing.append(8+actor.stats.atk*.1)
		for amount in healing:
			var allies=gear.alive(actor.side);allies.sort_custom(func(a,b):return gear.b.units[a].hp/gear.b.units[a].maxhp<gear.b.units[b].hp/gear.b.units[b].maxhp)
			if not allies.is_empty():gear.heal(allies[0],amount*(1+actor.stats.heal/100),e)
		actor.slow=maxf(0,actor.slow-1);resolve_event(e,index,"support")
		units[index].agility=maxf(1,stats_live[index].speed-slows[index])
	super.begin_action(index);powers_used[index]=false
