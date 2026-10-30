extends RefCounted

const HERO_IDS=["fenfen","gao","qiqi","dadong","wang"]
const HERO_NAMES=["粉粉","高哥","七七","大东老师","老王"]
const ENEMY_IDS=["tengu","umbrella","oni","kappa","wheel"]
const ENEMY_NAMES=["天狗","唐伞妖","赤鬼","河童","轮入道"]
const STAGES=["面具商店街","无人钱汤","祭典空巷","千灯神社","鬼王门庭"]
const HERO_POS=[Vector2(630,695),Vector2(440,770),Vector2(205,770),Vector2(190,575),Vector2(425,575)]
const ENEMY_POS=[Vector2(1025,575),Vector2(1250,575),Vector2(1430,695),Vector2(1000,770),Vector2(1240,770)]
# Fixed theatre-approved battle formation. Backgrounds must fit these positions.
const CAMPAIGN_HERO_POS=[Vector2(630,705),Vector2(420,770),Vector2(180,770),Vector2(290,640),Vector2(510,640)]
const CAMPAIGN_ENEMY_POS=[Vector2(1090,640),Vector2(1260,640),Vector2(1450,705),Vector2(1000,770),Vector2(1230,770)]
const SKILLS={"fenfen":"疾影斩","gao":"破阵拳","qiqi":"机枪连射","dadong":"脉冲干扰","wang":"灼热火球","tengu":"羽风","umbrella":"惊跳","oni":"碎地重击","kappa":"利爪","wheel":"火轮冲撞"}
var units:Array=[]
var projectiles:Array=[]
var effects:Array=[]
var ready_queue:Array=[]
var action:Dictionary={}
var history:Array=[]
var phase="ready"
var stage=0
var time=0.0
var stage_time=0.0
var kills=0
var attacks=0
var focus=-1
var last_skill=""
var total_damage=0
var fixed_accumulator=0.0
var event_log:Array=[]
var level_defs:Array=[]
var level_kills=0

func _init()->void:reset()

func configure_levels(definitions:Array)->void:
	assert(not definitions.is_empty())
	for definition in definitions:assert(not definition.scenes.is_empty())
	level_defs=definitions.duplicate(true);reset()

func level_count()->int:return maxi(1,level_defs.size())

func level_offset(index:int)->int:
	var offset=0
	for i in range(mini(index,level_defs.size())):offset+=level_defs[i].scenes.size()
	return offset

func level_index(at:int=-1)->int:
	if at<0:at=stage
	for i in range(level_defs.size()):
		if at<level_offset(i)+level_defs[i].scenes.size():return i
	return 0

func scene_count(level:int=-1)->int:
	if level_defs.is_empty():return STAGES.size()
	if level<0:level=level_index()
	return level_defs[level].scenes.size()

func stage_count()->int:
	return STAGES.size() if level_defs.is_empty() else level_offset(level_defs.size())

func scene_index()->int:return stage-level_offset(level_index())

func level_title(level:int=-1)->String:
	if level_defs.is_empty():return "百鬼夜行"
	if level<0:level=level_index()
	return level_defs[level].title

func scene_info(at:int=-1)->Dictionary:
	if at<0:at=stage
	if level_defs.is_empty():return {"title":STAGES[at],"image":"res://art/pixel-hyakki-level-20261024/backgrounds/%02d.png"%(at+1),"actor_scale":2.65}
	var level=level_index(at)
	return level_defs[level].scenes[at-level_offset(level)]

func stage_title(at:int=-1)->String:return scene_info(at).title
func is_level_end()->bool:return scene_index()==scene_count()-1
func is_boss_stage()->bool:return is_level_end()

func encounter_tier()->int:
	if level_defs.is_empty():return stage
	return mini(4,int(float(scene_index())*5.0/scene_count()))

func standing_position(side:int,index:int)->Vector2:
	if level_defs.is_empty():return (HERO_POS if side==0 else ENEMY_POS)[index]
	return (CAMPAIGN_HERO_POS if side==0 else CAMPAIGN_ENEMY_POS)[index]

func make_unit(id:String,title:String,side:int,index:int,hp:int,power:int,agility:float,point:Vector2)->Dictionary:
	return {"id":id,"name":title,"side":side,"uid":index,"hp":hp,"max_hp":hp,"power":power,"agility":agility,"charge":0.0,"home":point,"pos":point,"anim":"idle","anim_time":0.0,"hit_time":0.0,"dead_time":0.0,"burn":0.0,"burn_tick":0.0,"dealt":0}

func reset(start_level:int=0)->void:
	units=[];projectiles=[];effects=[];ready_queue=[];action={};history=[];event_log=[]
	stage=level_offset(clampi(start_level,0,level_count()-1));time=0;stage_time=0;kills=0;level_kills=0;attacks=0;focus=-1;total_damage=0;fixed_accumulator=0
	for i in range(5):
		units.append(make_unit(HERO_IDS[i],HERO_NAMES[i],0,i,[480,600,440,460,420][i],[86,92,92,64,94][i],[26.0,22.0,25.0,29.0,23.0][i],HERO_POS[i]))
	spawn_stage();phase="ready"

func spawn_stage()->void:
	units=units.slice(0,5);projectiles=[];effects=[];ready_queue=[];action={};focus=-1;stage_time=0
	var tier=encounter_tier()
	for i in range(5):
		var hp=100+tier*29
		if i==2:hp=190+tier*55
		if is_boss_stage() and i==2:hp=920
		var u=make_unit(ENEMY_IDS[i],("鬼王 · " if is_boss_stage() and i==2 else "")+ENEMY_NAMES[i],1,i+5,hp,20+tier*5+(8 if i==2 else 0),[20.0,24.0,16.0,25.0,22.0][i]+tier,standing_position(1,i))
		u.charge=[0.12,0.27,0.0,0.21,0.07][i];units.append(u)
	for i in range(5):
		var u=units[i];u.charge=[0.18,0.08,0.32,0.0,0.50][i];u.home=standing_position(0,i);u.pos=u.home;u.anim="idle";u.anim_time=0.0;u.burn=0;u.burn_tick=0;u.hit_time=0
	phase="fight";last_skill="";note("进入 "+stage_title())

func start()->void:
	if phase=="ready":phase="fight"

func advance_stage()->bool:
	if phase!="clear":return false
	if stage>=stage_count()-1:phase="victory";return false
	var new_level=level_index(stage+1)!=level_index()
	stage+=1
	if new_level:level_kills=0
	for u in units.slice(0,5):
		u.hp=u.max_hp if new_level else mini(u.max_hp,maxi(u.hp,roundi(u.max_hp*.25))+roundi(u.max_hp*.18));u.dead_time=0.0
	spawn_stage();return true

func note(text:String)->void:
	history.push_front(text)
	if history.size()>5:history.pop_back()

func alive(side:int)->Array:
	return units.filter(func(u):return u.side==side and u.hp>0)

func choose_target(actor:Dictionary)->int:
	if actor.side==0 and focus>=5 and focus<units.size() and units[focus].hp>0:return focus
	var candidates=alive(1-actor.side)
	if candidates.is_empty():return -1
	if actor.side==0:
		candidates.sort_custom(func(a,b):return a.hp<b.hp if a.hp!=b.hp else a.uid<b.uid)
		return candidates[0].uid
	# Distribute enemy pressure without nondeterministic test outcomes.
	return candidates[(attacks+actor.uid)%candidates.size()].uid

func advance(delta:float)->void:
	if phase!="fight":return
	fixed_accumulator+=maxf(0,delta)
	while fixed_accumulator>=1.0/120.0 and phase=="fight":
		tick(1.0/120.0);fixed_accumulator-=1.0/120.0

func tick(dt:float)->void:
	time+=dt;stage_time+=dt
	for e in effects:e.age+=dt
	effects=effects.filter(func(e):return e.age<e.life)
	for u in units:
		u.anim_time+=dt;u.hit_time=maxf(0,u.hit_time-dt)
		if u.hp<=0:u.dead_time+=dt;continue
		if u.anim=="hurt" and u.hit_time<=0:u.anim="idle";u.anim_time=0.0
		if u.burn>0:
			u.burn=maxf(0,u.burn-dt);u.burn_tick+=dt
			if u.burn_tick>=.8:
				u.burn_tick-=.8;damage(-1,u.uid,13,"burn")
	# Projectiles cause damage at actual arrival, not at action start.
	for p in projectiles:
		p.age+=dt
		if p.age>=p.duration and not p.hit:
			p.hit=true
			if units[p.target].hp>0:
				damage(p.actor,p.target,p.damage,p.kind)
				if p.kind=="fire" and units[p.target].hp>0:
					units[p.target].burn=3.3;units[p.target].burn_tick=0
				effects.append({"kind":"blast" if p.kind=="fire" else "spark","pos":p.end,"age":0.0,"life":.5,"color":Color("ffac40") if p.kind=="fire" else Color("fff2ac")})
	projectiles=projectiles.filter(func(p):return p.age<p.duration+.03)
	if not action.is_empty():update_action(dt)
	var crossings:Array=[]
	for u in units:
		if u.hp<=0 or ready_queue.has(u.uid) or (not action.is_empty() and action.actor==u.uid):continue
		var before=u.charge
		u.charge=minf(1.0,before+u.agility*.01*dt)
		if u.charge>=1.0:
			crossings.append({"uid":u.uid,"at":(1.0-before)/(u.agility*.01)})
	crossings.sort_custom(func(a,b):return a.at<b.at if not is_equal_approx(a.at,b.at) else a.uid<b.uid)
	for c in crossings:ready_queue.append(c.uid);event_log.append({"type":"ready","uid":c.uid,"time":time})
	ready_queue=ready_queue.filter(func(index):return units[index].hp>0)
	if action.is_empty() and not ready_queue.is_empty():begin_action(ready_queue.pop_front())
	if alive(0).is_empty():finish("defeat")
	elif alive(1).is_empty() and action.is_empty() and projectiles.is_empty():finish("victory" if stage==stage_count()-1 else "clear")

func finish(result:String)->void:
	phase=result;ready_queue=[];action={};projectiles=[]
	for u in units:
		u.pos=u.home
		if u.hp>0:u.anim="idle";u.anim_time=0
	event_log.append({"type":result,"time":time,"stage":stage})

func begin_action(index:int)->void:
	var u=units[index]
	if u.hp<=0:return
	var target=choose_target(u)
	if target<0:return
	var ranged=u.id in ["qiqi","wang","dadong","tengu"]
	action={"actor":index,"target":target,"elapsed":0.0,"fired":0,"hit":false,"ranged":ranged,"duration":1.15 if ranged else 1.3}
	u.anim="attack" if ranged else "walk";u.anim_time=0
	last_skill=u.name+" · "+SKILLS[u.id];attacks+=1
	note(last_skill);event_log.append({"type":"attack","uid":index,"time":time,"charge":u.charge})

func update_action(dt:float)->void:
	if action.is_empty():return
	var u=units[action.actor]
	if u.hp<=0:action={};return
	action.elapsed+=dt
	var t=action.elapsed
	if action.ranged:
		if u.id=="qiqi":
			while action.fired<4 and t>=[.24,.35,.46,.57][action.fired]:
				launch(u,"bullet",roundi(u.power/4.0));action.fired+=1
		elif action.fired==0 and t>=.37:
			launch(u,"fire" if u.id=="wang" else "pulse" if u.id=="dadong" else "wind",u.power);action.fired=1
	else:
		var target=units[action.target]
		var direction=1 if u.side==0 else -1
		var close=target.home+Vector2(-direction*(100 if u.id!="oni" else 135),8)
		if t<.34:
			var travel=sin(t/.34*PI*.5);u.pos=u.home.lerp(close,travel);u.anim="walk"
		elif t<.90:
			u.pos=close
			if u.anim!="attack":u.anim="attack";u.anim_time=0
			u.anim_time=(t-.34)*(.8/.56)
			if not action.hit and t>=.56:
				action.hit=true
				if target.hp>0:
					damage(u.uid,target.uid,u.power,"slash" if u.id=="fenfen" else "melee")
					effects.append({"kind":"slash" if u.id=="fenfen" else "impact","pos":target.pos+Vector2(0,-75),"age":0.0,"life":.28,"color":Color("f8d485")})
		else:
			if u.anim!="walk":u.anim="walk";u.anim_time=0
			u.pos=close.lerp(u.home,smoothstep(0.0,1.0,(t-.9)/.4))
	if t>=action.duration:
		u.pos=u.home;u.charge=0;u.anim="idle";u.anim_time=0;action={}

func launch(actor:Dictionary,kind:String,power:int)->void:
	var target=action.target
	if units[target].hp<=0:
		target=choose_target(actor)
		if target<0:return
		action.target=target
	var side=1 if actor.side==0 else -1
	var origin=actor.pos+Vector2(side*(74 if kind=="bullet" else 50),-91)
	var end=units[target].pos+Vector2(0,-75)
	var duration=origin.distance_to(end)/(2300.0 if kind=="bullet" else 1050.0)
	projectiles.append({"kind":kind,"actor":actor.uid,"target":target,"start":origin,"end":end,"age":0.0,"duration":maxf(.12,duration),"damage":power,"hit":false})
	effects.append({"kind":"muzzle" if kind=="bullet" else "cast","pos":origin,"age":0.0,"life":.10 if kind=="bullet" else .28,"color":Color("ffdd75")})
	event_log.append({"type":"projectile","kind":kind,"uid":actor.uid,"time":time})

func damage(source:int,target:int,amount:int,kind:String)->void:
	var u=units[target]
	if u.hp<=0:return
	var dealt=mini(amount,u.hp);u.hp-=dealt;u.hit_time=1.0/3.0
	if source>=0:units[source].dealt+=dealt
	if u.side==1:total_damage+=dealt
	effects.append({"kind":"number","pos":u.pos+Vector2(0,-120),"value":dealt,"age":0.0,"life":.8,"color":Color("ffb15c") if kind=="burn" else Color("fff1ce") if u.side==1 else Color("ff7e7e")})
	event_log.append({"type":"damage","source":source,"target":target,"kind":kind,"value":dealt,"time":time})
	if u.hp<=0:
		u.anim="die";u.anim_time=0;u.dead_time=0;u.charge=0;u.burn=0
		ready_queue.erase(target)
		if u.side==1:kills+=1;level_kills+=1
		note(u.name+" 已倒下")
	else:
		if action.is_empty() or action.actor!=target:u.anim="hurt";u.anim_time=0

