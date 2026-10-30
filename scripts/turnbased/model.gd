extends RefCounted
const G=preload("res://scripts/turnbased/gear.gd")
const C=preload("res://scripts/turnbased/catalog.gd")
var rng=RandomNumberGenerator.new()
var s:Dictionary={}
var b:Dictionary={}

func _init(seed_value:int=0)->void:
	G.init();rng.seed=seed_value if seed_value!=0 else int(Time.get_unix_time_from_system()*1000)
	s={"schema":1,"gold":450,"materials":0,"xp":0,"level":1,"training":[0,0,0,0,0],"inventory":[],"equipped":[{},{},{},{},{}],"next_id":1,"kills":{},"sets":[[],[],[]],"looks":[-1,-1,-1,-1,-1],"wins":[0,0,0],"talks":{},"actions":0}
	for h in range(5):
		var item=award(1,0,1,h*4)
		s.equipped[h]["weapon"]=item.id
	# A small starter bag lets the player try all nine slots immediately.
	for base in [20,26,32,38,44,50,56,57,21,27,33,39]:award(1,0,1,base)

func snapshot()->Dictionary:return {"state":s.duplicate(true),"battle":b.duplicate(true),"rng":rng.state}
func restore(data:Dictionary)->bool:
	if not data.get("state") is Dictionary or not data.get("battle") is Dictionary or not data.get("rng") is int:return false
	var v:Dictionary=data.state
	for key in s:
		if not v.has(key) or typeof(v[key])!=typeof(s[key]):return false
	if v.schema!=1 or v.level<1 or v.next_id<1 or v.gold<0 or v.materials<0:return false
	if v.equipped.size()!=5 or v.training.size()!=5 or v.looks.size()!=5 or v.sets.size()!=3 or v.wins.size()!=3:return false
	var ids={};var used={};var greatest=0
	for item in v.inventory:
		if not G.valid(item) or ids.has(item.id):return false
		ids[item.id]=item;greatest=maxi(greatest,item.id)
	if v.next_id<=greatest:return false
	for h in range(5):
		if not v.equipped[h] is Dictionary or not v.training[h] is int or v.training[h]<0:return false
		for slot in v.equipped[h]:
			var id=v.equipped[h][slot]
			if not ids.has(id) or used.has(id) or not G.can_equip(ids[id],h,slot):return false
			used[id]=true
		if not v.looks[h] is int or v.looks[h]<-1 or v.looks[h]>2:return false
	for list in v.sets:
		if not list is Array:return false
		for part in list:
			if part not in G.SET_TYPES:return false
	for h in range(5):
		if v.looks[h]>=0 and v.sets[v.looks[h]].size()!=4:return false
	var battle:Dictionary=data.battle
	if not battle.is_empty():
		for key in ["theme","scene","tier","round","units","queue","phase","loot","gold","kills"]:
			if not battle.has(key):return false
		if battle.theme not in [0,1,2] or battle.scene<0 or battle.scene>4 or battle.tier<1:return false
		if battle.phase not in ["fighting","clear","won","lost"] or not battle.units is Array or battle.units.size()<6 or battle.units.size()>10:return false
		for i in range(battle.units.size()):
			var u=battle.units[i]
			if not u is Dictionary or u.get("id",-1)!=i or not u.get("stats") is Dictionary:return false
			for key in ["hp","maxhp","shield","dot","dot_turns","slow","hero","kind","boss","name","side"]:
				if not u.has(key):return false
			for key in G.AFFIX:
				if not u.stats.has(key):return false
			if not u.stats.has("powers") or u.hp<0 or u.hp>u.maxhp:return false
		for id in battle.queue:
			if not id is int or id<0 or id>=battle.units.size():return false
	s=v.duplicate(true);b=battle.duplicate(true);rng.state=data.rng;return true

func item_by_id(id:int)->Dictionary:
	for item in s.inventory:
		if item.id==id:return item
	return {}
func owner(id:int)->int:
	for h in range(5):
		if id in s.equipped[h].values():return h
	return -1
func award(level:int,theme:int,quality:int=-1,base:int=-1)->Dictionary:
	var item=G.make(rng,s.next_id,level,theme,quality,base);s.next_id+=1;s.inventory.append(item)
	var set_id=int(G.bases[item.base].get("set",-1))
	if set_id>=0:
		var type=G.type_of(item)
		if type not in s.sets[set_id]:s.sets[set_id].append(type)
	return item
func equip(id:int,hero:int,slot:String)->bool:
	var item=item_by_id(id)
	if hero<0 or hero>4 or item.is_empty() or not G.can_equip(item,hero,slot):return false
	for slots in s.equipped:
		for key in slots.keys():
			if slots[key]==id:slots.erase(key)
	s.equipped[hero][slot]=id;return true
func unequip(hero:int,slot:String)->bool:return s.equipped[hero].erase(slot)
func salvage(id:int)->bool:
	var item=item_by_id(id)
	if item.is_empty() or item.get("locked",false) or owner(id)>=0:return false
	s.materials+=1+int(item.quality)*2;s.gold+=8+int(item.level)*2;s.inventory.erase(item);return true
func forge(theme:int)->Dictionary:
	if s.materials<20 or s.gold<100:return {}
	s.materials-=20;s.gold-=100
	# Crafting always produces one missing set part until the collection is complete.
	var missing=[]
	for p in G.SET_TYPES:
		if p not in s.sets[theme]:missing.append(p)
	var part=missing[rng.randi_range(0,missing.size()-1)] if not missing.is_empty() else G.SET_TYPES[rng.randi_range(0,3)]
	return award(s.level,theme,4,62+theme*4+G.SET_TYPES.find(part))
func set_look(hero:int,theme:int)->bool:
	if theme< -1 or theme>2 or hero<0 or hero>4:return false
	if theme>=0 and s.sets[theme].size()!=4:return false
	s.looks[hero]=theme;return true
func train(hero:int)->bool:
	var cost=80+s.training[hero]*45
	if s.gold<cost:return false
	s.gold-=cost;s.training[hero]+=1;return true
func stats(hero:int)->Dictionary:
	var st={}
	for key in G.AFFIX:st[key]=0.0
	st.merge({"hp":260.0+(s.level-1)*18+s.training[hero]*14,"atk":34.0+(s.level-1)*2.8+s.training[hero]*2,"armor":9.0,"speed":float([14,10,12,11,13][hero]),"crit":5.0,"crit_damage":150.0,"powers":[]},true)
	var sets=[0,0,0]
	for id in s.equipped[hero].values():
		var item=item_by_id(id)
		for key in G.inherent(item):st[key]+=G.inherent(item)[key]
		for key in item.affixes:st[key]+=item.affixes[key]
		if item.power!="" and item.power not in st.powers:st.powers.append(item.power)
		var set_id=int(G.bases[item.base].get("set",-1))
		if set_id>=0:sets[set_id]+=1
	for theme in range(3):
		if sets[theme]>=2:st.atk*=1.1
		if sets[theme]>=4:
			var power=["cleave","mercy","barrier"][theme]
			if power not in st.powers:st.powers.append(power)
	for key in ["crit","block","dodge","resist"]:st[key]=minf(st[key],65)
	st.vamp=minf(st.vamp,40);st.luck=minf(st.luck,60)
	return st

func start(theme:int,tier:int=1)->void:
	b={"theme":clampi(theme,0,2),"scene":0,"tier":maxi(tier,1),"round":0,"units":[],"queue":[],"phase":"fighting","loot":[],"gold":0,"kills":0}
	for h in range(5):
		var st=stats(h)
		b.units.append(unit(h,0,h,-1,C.HEROES[h],st))
	apply_guardian();spawn_enemies()
func unit(id:int,side:int,hero:int,kind:int,title:String,st:Dictionary,boss:bool=false)->Dictionary:
	return {"id":id,"side":side,"hero":hero,"kind":kind,"name":title,"stats":st,"hp":st.hp,"maxhp":st.hp,"shield":st.shield,"dot":0.0,"dot_turns":0,"slow":0.0,"boss":boss}
func apply_guardian()->void:
	var n=0
	for u in b.units:
		if "guardian" in u.stats.powers:n+=1
	for u in b.units:u.stats.armor+=mini(n,3)*5
func spawn_enemies()->void:
	var count=[2,3,4,3,5][b.scene]
	for n in range(count):
		var kind=(n+b.scene)%3;var boss=b.scene==4 and n==0
		var st={}
		for key in G.AFFIX:st[key]=0.0
		var scale=pow(1.22,b.tier-1)
		st.merge({"hp":(110+b.theme*24+b.scene*12)*scale*(2.6 if boss else 1.0),"atk":(18+b.theme*4+b.scene*2)*scale*(1.5 if boss else 1.0),"armor":5.0+b.theme*2,"speed":float(8+kind*2),"crit":4.0,"crit_damage":150.0,"powers":[]},true)
		if kind==2:st[["fire","cold","lightning"][b.theme]]=4+b.theme*2
		b.units.append(unit(5+n,1,-1,kind,("首领 · " if boss else "")+C.ENEMIES[b.theme][kind],st,boss))
	b.round=0;b.queue=[];b.phase="fighting"
func advance()->bool:
	if b.is_empty() or b.phase!="clear":return false
	if b.scene==4:
		b.phase="won";s.wins[b.theme]+=1;return true
	b.scene+=1;b.units=b.units.slice(0,5)
	for h in range(5):
		var u=b.units[h];var st=stats(h);var ratio=u.hp/u.maxhp
		u.stats=st;u.maxhp=st.hp;u.hp=minf(st.hp,maxf(st.hp*.25,st.hp*ratio)+st.hp*.2);u.shield=st.shield;u.dot=0.0;u.dot_turns=0;u.slow=0.0
	apply_guardian();spawn_enemies();return true
func alive(side:int)->Array:
	var result=[]
	for u in b.units:
		if u.side==side and u.hp>0:result.append(u.id)
	return result
func fill_queue()->void:
	b.round+=1
	var ids=alive(0)+alive(1)
	ids.sort_custom(func(a,bb):
		var sa=b.units[a].stats.speed-b.units[a].slow;var sb=b.units[bb].stats.speed-b.units[bb].slow
		return a<bb if is_equal_approx(sa,sb) else sa>sb)
	b.queue=ids
func phase_check()->void:
	if alive(1).is_empty():b.phase="clear"
	elif alive(0).is_empty():b.phase="lost"
func next_action()->Dictionary:
	if b.is_empty() or b.phase!="fighting":return {}
	phase_check()
	if b.phase!="fighting":return {}
	if b.queue.is_empty():fill_queue()
	while not b.queue.is_empty() and b.units[b.queue[0]].hp<=0:b.queue.pop_front()
	if b.queue.is_empty():fill_queue()
	var id=int(b.queue.pop_front());var actor=b.units[id]
	var event={"actor":id,"hits":[],"heals":[],"target":-1,"label":actor.name+" · "+("攻击" if b.round%3!=0 else "全力出击"),"melee":actor.hero in [0,1] if actor.side==0 else not (actor.kind==2 or (b.theme==0 and actor.kind==1)),"robot":actor.hero==3,"round":b.round}
	if actor.dot_turns>0:
		deal(id,actor.dot,event,false,"持续伤害");actor.dot_turns-=1
	if actor.hp<=0:phase_check();s.actions+=1;return event
	var targets=alive(1-actor.side)
	var target=int(targets[rng.randi_range(0,targets.size()-1)]);event.target=target
	var st=actor.stats;var powers=st.powers
	if "barrier" in powers:actor.shield+=10
	if "mercy" in powers:
		var allies=alive(actor.side);allies.sort_custom(func(a,bb):return b.units[a].hp/b.units[a].maxhp<b.units[bb].hp/b.units[bb].maxhp)
		heal(allies[0],(12+st.atk*.18)*(1+st.heal/100.0),event)
	# The support robot is its own rendered actor and attacks on the controller's turn.
	if actor.hero==3:
		var allies=alive(0);allies.sort_custom(func(a,bb):return b.units[a].hp/b.units[a].maxhp<b.units[bb].hp/b.units[bb].maxhp)
		heal(allies[0],(8+st.atk*.1)*(1+st.heal/100.0),event)
	var amount=st.atk*(1.55 if b.round%3==0 else 1.0)
	if actor.hero==1:b.units[target].stats.armor=maxf(0,b.units[target].stats.armor-2)
	strike(actor,target,amount,event)
	if "echo" in powers and b.units[target].hp>0:strike(actor,target,amount*.25,event)
	var splash=2 if "chain" in powers else (1 if "cleave" in powers else (1 if actor.hero==2 and b.round%3==0 else 0))
	for other in targets:
		if other==target or b.units[other].hp<=0:continue
		if splash<=0:break
		strike(actor,other,amount*(.2 if "chain" in powers else .35),event);splash-=1
	actor.slow=maxf(0,actor.slow-1);s.actions+=1;phase_check();return event
func strike(actor:Dictionary,target:int,amount:float,event:Dictionary)->void:
	var victim=b.units[target];var st=actor.stats
	if rng.randf()*100<victim.stats.dodge:
		event.hits.append({"id":target,"before":victim.hp,"after":victim.hp,"damage":0,"crit":false,"tag":"闪避"});return
	var crit=rng.randf()*100<st.crit
	if crit:amount*=st.crit_damage/100.0
	if victim.boss:amount*=1+st.elite/100.0
	if "execute" in st.powers and victim.hp<victim.maxhp*.5:amount*=1.35
	amount*=100.0/(100+victim.stats.armor*3)
	amount+=(st.fire+st.cold+st.lightning)*(1-victim.stats.resist/100.0)
	if rng.randf()*100<victim.stats.block:amount*=.5
	var actual=deal(target,maxf(1,amount),event,crit,"")
	if st.vamp>0:heal(actor.id,actual*st.vamp/100.0,event)
	if victim.hp>0:
		if st.cold>0:victim.slow=minf(5,st.cold*.2)
		if st.poison>0 or "bleed" in st.powers:
			victim.dot=maxf(victim.dot,st.poison*(1-victim.stats.resist/100.0)+(st.atk*.15 if "bleed" in st.powers else 0));victim.dot_turns=2
	if victim.stats.thorns>0 and actor.hp>0:deal(actor.id,victim.stats.thorns,event,false,"反伤")
func heal(id:int,amount:float,event:Dictionary)->void:
	var u=b.units[id];var before=u.hp;u.hp=minf(u.maxhp,u.hp+amount)
	if u.hp>before:event.heals.append({"id":id,"amount":u.hp-before})
func deal(id:int,amount:float,event:Dictionary,crit:bool,tag:String)->float:
	var u=b.units[id];var before=u.hp
	var absorbed=minf(u.shield,amount);u.shield-=absorbed;amount-=absorbed;u.hp=maxf(0,u.hp-amount)
	event.hits.append({"id":id,"before":before,"after":u.hp,"damage":roundi(before-u.hp),"crit":crit,"tag":tag if tag!="" else ("护盾" if absorbed>0 and amount<=0 else "")})
	if before>0 and u.hp<=0 and u.side==1:reward(u)
	return before-u.hp
func party_bonus(key:String)->float:
	var n=0.0
	for h in range(5):n+=b.units[h].stats[key]
	return n/5
func reward(enemy:Dictionary)->void:
	var key="%d:%d"%[b.theme,enemy.kind];s.kills[key]=s.kills.get(key,0)+1;b.kills+=1
	var money=roundi((12+b.theme*4+b.tier*3)*(1+party_bonus("gold")/100.0));s.gold+=money;b.gold+=money
	s.xp+=roundi((18+b.theme*5+b.tier*2)*(1+party_bonus("xp")/100.0))
	while s.xp>=s.level*120:s.xp-=s.level*120;s.level+=1
	if enemy.boss or rng.randf()<minf(.9,.38+party_bonus("luck")/100.0):
		var item=award(maxi(s.level,b.theme*3+b.tier),b.theme)
		b.loot.append(item.id)
