extends RefCounted
## Deterministic aggregate simulation. A stream represents a disjoint range of real
## rooms running the same schedule. Soldier identities are (room, cycle, slot).
## Army stacks merge only identical stat snapshots; visual sampling never caps them.
const C=preload("res://scripts/reboot/war_catalog.gd")
var s: Dictionary
var events: Array=[]
var dirty=false
var error=""
var invincible=false

func _init(state: Dictionary={}) -> void: s=state

static func create(originals: Array) -> Dictionary:
	var state={"schema":1,"time":0.0,"tick_bank":0.0,"active":false,"planet":0,"occupied":0,"stage":0,"phase":"orbit","wait":0.0,"hull":1000.0,"enemy_hp":0.0,"enemy_max":0.0,"enemy_count":0,"enemy_unit_hp":100.0,"enemy_armor":8.0,"enemy_atk":12.0,"enemy_trait":"","army":[],"streams":[],"originals":originals.duplicate(true),"tech":{"weapons":0,"armor":0,"medicine":0,"logistics":0},"formations":[[0,1,2,3],[0,1,2,3],[0,1,2,3],[0,1,2,3]],"auto_send":[true,true,true,true],"auto_push":false,"supplies":500,"science":0,"income_bank":0.0,"generated":4,"landed":0,"dead":0,"kills":0,"batches":0,"ledger":[],"memorial":[],"result":{},"cards":[],"ending":false,"ending_read":false,"boost":0.0,"paid_stage":0,"reward_supplies":0,"reward_science":0,"deaths_at_start":0,"story_queue":[],"story_seen":[],"orders":0}
	var w=new(state)
	state.streams.append({"id":0,"first":1,"rooms":1,"group":0,"cycle":0,"phase":"outbound","remaining":10.0,"duration":10.0,"travel":10.0,"slots":[0,1,2,3],"stats":originals.duplicate(true),"held":4,"original":true})
	var start=2
	for i in range(16):
		var count=62499 if i==0 else 62500
		var group=int(i/4)
		var stream={"id":i+1,"first":start,"rooms":count,"group":group,"cycle":1,"phase":"training","remaining":7.5+float(i%4)*7.5,"duration":30.0,"travel":10.0,"slots":[0,1,2,3],"stats":[],"held":0,"original":false}
		stream.stats=w.snapshots(stream.slots)
		state.streams.append(stream)
		start+=count
	for i in range(4):
		state.originals[i].status="去程"
		state.originals[i].current_hp=state.originals[i].hp
	state.active=true
	state.phase="landing"
	state.wait=12.0
	return state

func fail(message: String) -> bool:
	error=message
	return false

func snapshots(slots: Array) -> Array:
	var result=[]
	for role in slots:
		var d=C.ROLES[int(role)]
		result.append({"role":int(role),"hp":d.hp*(1+.08*s.tech.armor),"atk":d.atk*(1+.08*s.tech.weapons),"armor":d.armor*(1+.08*s.tech.armor),"interval":d.interval,"heal":30.0*(1+.08*s.tech.medicine),"stamp":"%d.%d.%d"%[s.tech.weapons,s.tech.armor,s.tech.medicine]})
	return result

func travel_time() -> float: return maxf(4.0,10.0*(1-.03*int(s.tech.logistics)))

func begin_phase(stream: Dictionary, phase: String, duration: float) -> void:
	stream.phase=phase
	stream.remaining=duration
	stream.duration=duration
	dirty=true

func room_step(stream: Dictionary, delta: float) -> void:
	if stream.phase=="ready":
		if s.auto_send[int(stream.group)]:
			stream.travel=travel_time()
			begin_phase(stream,"outbound",stream.travel)
		return
	stream.remaining-=delta
	if stream.remaining>0: return
	match str(stream.phase):
		"training":
			stream.held=4*int(stream.rooms)
			s.generated+=stream.held
			if s.auto_send[int(stream.group)]:
				stream.travel=travel_time()
				begin_phase(stream,"outbound",stream.travel)
			else: begin_phase(stream,"ready",0.0)
		"outbound": begin_phase(stream,"unloading",C.UNLOAD_TIME)
		"unloading":
			land(stream)
			stream.held=0
			stream.travel=travel_time()
			begin_phase(stream,"returning",stream.travel)
		"returning":
			stream.cycle+=1
			stream.original=false
			stream.slots=s.formations[int(stream.group)].duplicate()
			stream.stats=snapshots(stream.slots)
			begin_phase(stream,"training",C.TRAIN_TIME)

func land(stream: Dictionary) -> void:
	for slot in range(4):
		var stats=stream.stats[slot]
		var named=bool(stream.original)
		var id=str(stats.id) if named else "r%d_%s"%[stats.role,stats.stamp]
		var stack={}
		for candidate in s.army:
			if candidate.id==id: stack=candidate;break
		if stack.is_empty():
			stack={"id":id,"role":stats.role,"count":0,"hp":0.0,"unit_hp":stats.hp,"atk":stats.atk,"armor":stats.armor,"interval":stats.interval,"heal":float(stats.get("heal",30.0)),"named":named,"damage":0.0,"taken":0.0}
			if named:
				stack.name=stats.name
				stack.skill=stats.skill
				stack.module=stats.module
				stack.modules=stats.modules.duplicate(true)
				stack.skill_cd=[12.0,10.0,14.0,8.0][slot]
				stack.module_cd=10.0
				stack.shield=0.0
				stack.shield_time=0.0
				if stats.role==3: stack.heal=40.0+15*(stats.skill-1)
			s.army.append(stack)
		stack.count+=int(stream.rooms)
		stack.hp+=stats.hp*int(stream.rooms)
		if named: s.originals[slot].status="在役"
	s.landed+=stream.held
	s.batches+=int(stream.rooms)
	s.ledger.push_front({"first":stream.first,"last":stream.first+stream.rooms-1,"cycle":stream.cycle,"time":s.time,"slots":stream.slots.duplicate(),"count":stream.held,"destination":s.planet+1 if s.active else s.occupied})
	if s.ledger.size()>80: s.ledger.resize(80)
	dirty=true
	events.append({"type":"war_landing","count":stream.held,"stream":stream.id})

func soldiers() -> int:
	var count=0
	for stack in s.army: count+=int(stack.count)
	return count

func held() -> int:
	var count=0
	for stream in s.streams: count+=int(stream.held)
	return count

func roles() -> Array:
	var counts=[0,0,0,0]
	for stack in s.army: counts[int(stack.role)]+=int(stack.count)
	return counts

func conservation() -> bool: return int(s.generated)==soldiers()+held()+int(s.dead)

func tick(delta: float) -> void:
	if s.is_empty(): return
	s.tick_bank+=delta
	# A fixed 0.1 s clock preserves production, damage and reload behavior across
	# frame rates, save/reload and speed changes. No offline deaths are simulated.
	while s.tick_bank>=.1:
		s.tick_bank-=.1
		step(.1)

func step(delta: float) -> void:
	s.time+=delta
	s.boost=maxf(0,s.boost-delta)
	for stream in s.streams: room_step(stream,delta)
	s.income_bank+=delta
	if s.income_bank>=60:
		s.income_bank-=60
		s.supplies+=30*int(s.occupied)
		s.science+=3*int(s.occupied)
		dirty=true
	if not s.active:
		for a in s.army:
			if a.count>0: a.hp=minf(a.count*a.unit_hp,a.hp+a.count*a.unit_hp*delta/10.0)
		update_originals()
		return
	if s.phase in ["landing","between"]:
		s.wait-=delta
		if s.wait<=0: spawn_stage()
		return
	combat(delta)

func spawn_stage() -> void:
	var d=C.planet(s.planet)
	var scouts=int(s.planet)==0 and int(s.stage)==0 and s.kills==0
	var count=6 if scouts else int((950000+int(s.stage)*200000)*pow(d.factor,.68))
	var hp=100.0*pow(d.factor,.7)
	var behavior=d.behavior
	if behavior=="final": behavior=["shield","rush","regen","ranged"][int(s.stage)%4]
	if behavior=="glass": hp*=.65
	if behavior=="elite": hp*=1.6
	if int(s.stage)==int(d.stages)-1: hp*=1.35
	s.enemy_count=count
	s.enemy_unit_hp=hp
	s.enemy_hp=count*hp
	s.enemy_max=s.enemy_hp
	s.enemy_armor=(50.0 if behavior=="armor" else (30.0 if behavior=="shield" else 8.0))*sqrt(d.factor)
	s.enemy_atk=12.0*pow(d.factor,.45)*(1.4 if behavior in ["glass","ranged"] else 1.0)
	s.enemy_trait=behavior
	if behavior=="shield": s.enemy_hp*=1.2;s.enemy_max=s.enemy_hp;s.enemy_unit_hp*=1.2
	s.phase="fight"
	dirty=true
	events.append({"type":"war_wave"})

func attack_power() -> float:
	var power=0.0
	for a in s.army:
		if a.count<=0: continue
		var armor=float(s.enemy_armor)*(.5 if int(a.role)==2 else 1.0)
		power+=a.count*a.atk/a.interval*100/(100+armor)
	return power*(1.3 if s.boost>0 else 1.0)

func combat(delta: float) -> void:
	var total=soldiers()
	var before_enemy=int(s.enemy_count)
	var output=attack_power()*delta
	if s.enemy_trait=="regen": output=maxf(0,output-s.enemy_max*.003*delta)
	s.enemy_hp=maxf(0,s.enemy_hp-output)
	s.enemy_count=ceili(s.enemy_hp/s.enemy_unit_hp)
	s.kills+=maxi(0,before_enemy-int(s.enemy_count))
	if s.enemy_hp<=0:
		stage_clear()
		return
	var incoming=s.enemy_count*s.enemy_atk/1.4*delta
	# Medical fire is allocated to living front-line soldiers during the same
	# exchange. It cannot revive a casualty or fill a lost soldier's health slot.
	var healing=0.0
	for a in s.army:
		if int(a.role)==3 and a.count>0: healing+=a.count*a.heal/8.0*delta
	incoming=maxf(incoming*.2,incoming-healing)
	if total==0:
		s.hull=maxf(0,s.hull-10.0*delta*(2 if s.enemy_trait=="rush" else 1))
	else:
		var formation=s.army.duplicate()
		formation.sort_custom(func(a,b):
			if a.role==b.role: return not a.named and b.named
			return a.role<b.role)
		if s.enemy_trait=="ranged":
			var back=formation.duplicate();back.reverse()
			damage_army(incoming*.28,back)
			incoming*=.72
		damage_army(incoming,formation)
		if int(s.enemy_count)>maxi(1,total)*3:
			s.hull=maxf(0,s.hull-10.0*delta*(2 if s.enemy_trait=="rush" else 1))
	for a in s.army:
		if not a.named or a.count<=0: continue
		a.shield_time=maxf(0,float(a.get("shield_time",0))-delta)
		if a.shield_time<=0: a.shield=0.0
		a.skill_cd-=delta
		if a.skill_cd<=0:
			a.skill_cd=[12.0,10.0,14.0,8.0][int(a.role)]
			if a.role==3:
				var patient=a
				for friend in s.army:
					if friend.named and friend.count>0 and friend.hp/friend.unit_hp<patient.hp/patient.unit_hp: patient=friend
				patient.hp=minf(patient.unit_hp,patient.hp+40+15*(a.skill-1))
			else:
				s.enemy_hp=maxf(0,s.enemy_hp-a.atk*(1+.2*a.skill)*(3 if a.role==1 else (6 if a.role==2 else 1)))
				if a.role==0: a.shield=maxf(a.shield,30+12*(a.skill-1));a.shield_time=4.0
		if a.module!="" and a.module!="reflect":
			a.module_cd-=delta
			if a.module_cd<=0:
				var level=int(a.modules.get(a.module,1))
				a.module_cd={"regen":10.0,"beam":16.0,"barrier":18.0}.get(a.module,10.0)
				if a.module=="regen": a.hp=minf(a.unit_hp,a.hp+a.unit_hp*(.04+.01*(level-1)))
				elif a.module=="beam": s.enemy_hp=maxf(0,s.enemy_hp-a.atk*(1+.2*(level-1)))
				elif a.module=="barrier":
					for friend in s.army:
						if friend.named and friend.count>0: friend.shield=maxf(friend.get("shield",0),20+8*(level-1));friend.shield_time=4.0
	update_originals()
	if s.hull<=0: finish("defeat")

func damage_army(raw: float, order: Array) -> void:
	if invincible: return
	for a in order:
		if raw<=0: break
		if a.count<=0: continue
		var multiplier=100.0/(100.0+a.armor)
		if a.named and a.get("shield",0)>0:
			var absorbed=minf(a.shield,raw*multiplier)
			a.shield-=absorbed
			raw-=absorbed/multiplier
		var damage=minf(a.hp,raw*multiplier)
		raw-=damage/multiplier
		a.hp=maxf(0,a.hp-damage)
		a.taken+=damage
		if a.named and a.module=="reflect" and a.hp>0: s.enemy_hp=maxf(0,s.enemy_hp-damage*(.05+.02*(int(a.modules.get("reflect",1))-1)))
		var after=ceili(a.hp/a.unit_hp)
		var lost=int(a.count)-after
		if lost>0:
			s.dead+=lost
			a.count=after
			dirty=true
			if a.named:
				s.memorial.append({"id":a.id,"name":a.name,"role":a.role,"planet":s.planet,"stage":s.stage+1,"time":s.time})
				events.append({"type":"war_death","name":a.name})
				if not s.story_seen.has("first_death") and not s.story_queue.has("first_death"): s.story_queue.append("first_death")
	# A destroyed stack is retained only for the four named people. New troops
	# with identical technology may merge, but never into a named identity.
	s.army=s.army.filter(func(a): return a.count>0 or a.named)

func update_originals() -> void:
	for p in s.originals:
		for a in s.army:
			if a.id!=p.id: continue
			p.current_hp=a.hp
			p.status="阵亡" if a.count<=0 else ("在役" if s.active else "驻守")

func stage_clear() -> void:
	var d=C.planet(s.planet)
	s.stage+=1
	var reward_s=int(d.supplies*float(s.stage)/d.stages)
	var reward_r=int(d.science*float(s.stage)/d.stages)
	s.supplies+=reward_s-int(s.reward_supplies)
	s.science+=reward_r-int(s.reward_science)
	s.reward_supplies=reward_s
	s.reward_science=reward_r
	s.paid_stage=s.stage
	s.hull=minf(1000,s.hull+50)
	if s.stage>=d.stages: finish("victory")
	else:
		s.phase="between"
		s.wait=15.0 if int(s.planet)==0 and int(s.stage)==1 else 4.0
		events.append({"type":"war_wave"})
	dirty=true

func launch(index: int) -> bool:
	if s.active: return fail("当前星区仍在交战。")
	if index!=int(s.occupied) or index>=12: return fail("按已占领航路逐区推进。已占领区域提供驻守与收入。")
	if soldiers()==0 and held()==0: return fail("培养仍在进行，等待第一批士兵就绪。")
	s.planet=index
	s.stage=0
	s.active=true
	s.phase="landing"
	s.wait=3.0
	s.hull=1000.0
	s.reward_supplies=0
	s.reward_science=0
	s.paid_stage=0
	s.deaths_at_start=s.dead
	s.started=s.time
	s.result={}
	dirty=true
	return true

func finish(outcome: String) -> void:
	if not s.active: return
	s.active=false
	s.result={"outcome":outcome,"planet":s.planet,"completed":s.stage,"supplies":s.reward_supplies,"science":s.reward_science,"dead":int(s.dead)-int(s.deaths_at_start),"survivors":soldiers(),"time":s.time}
	if outcome=="victory":
		s.occupied=maxi(s.occupied,s.planet+1)
		var id=C.planet(s.planet).id
		if not s.cards.has(id): s.cards.append(id)
		if s.occupied in [4,8,12]: s.story_queue.append("sector_%d"%s.occupied)
		if s.occupied==12:
			s.ending=true;s.auto_push=false
			s.ending_stats={"time":s.time,"landed":s.landed,"dead":s.dead}
	else: s.auto_push=false
	s.phase="garrison" if s.occupied>0 else "orbit"
	s.enemy_hp=0.0
	s.enemy_count=0
	update_originals()
	dirty=true
	events.append({"type":"war_result","outcome":outcome})

func action(id: String, value: Variant=null) -> bool:
	match id:
		"launch": return launch(int(value))
		"retreat":
			if not s.active: return fail("当前没有战斗。")
			finish("retreat")
		"auto_push": s.auto_push=not s.auto_push
		"auto_send":
			var group=int(value)
			if group<0 or group>=4: return false
			s.auto_send[group]=not s.auto_send[group]
		"formation":
			if int(value.group) not in range(4) or int(value.slot) not in range(4) or int(value.role) not in range(4): return false
			s.formations[int(value.group)][int(value.slot)]=int(value.role)
		"tech":
			if not s.tech.has(str(value)): return false
			var level=int(s.tech[str(value)])
			if level>=20: return fail("科技已满 20 级。")
			var cost=40+60*level
			if s.science<cost: return fail("还差 %d 研究点。"%(cost-s.science))
			s.science-=cost
			s.tech[str(value)]+=1
		"boost":
			if not s.active: return fail("战斗中才能发出火力补给。")
			if s.boost>0: return fail("火力补给仍在生效。")
			if s.supplies<200: return fail("需要 200 战备物资。")
			s.supplies-=200
			s.boost=15.0
			s.orders+=1
		"repair":
			if not s.active or s.hull>=1000: return fail("当前无需修复登陆锚点。")
			if s.supplies<150: return fail("需要 150 战备物资。")
			s.supplies-=150
			s.hull=minf(1000,s.hull+350)
		"next":
			if s.occupied<12: return launch(s.occupied)
		_: return fail("未知指令。")
	dirty=true
	return true
