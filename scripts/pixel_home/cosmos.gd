extends RefCounted
const Campaign=preload("res://scripts/pixel_home/campaign.gd")
const TYPES=["lance","aegis","relay"]
static var config:Dictionary={}

static func catalog() -> Dictionary:
	if config.is_empty():config=JSON.parse_string(FileAccess.get_file_as_string("res://assets/pixel_campaign/cosmos.json"))
	return config

static func initial() -> Dictionary:
	return {"schema":1,"unlocked":false,"inventory":[],"slots":[0,0,0,0,0],"skills":[0,0,0,0,0],"next_id":1,"stardust":0,"misses":0,"mastery":0,"starter_claimed":false}

static func unlock(state:Dictionary) -> void:
	state.unlocked=true
	if state.starter_claimed:return
	for kind in ["lance","aegis","lance","relay","relay"]:add_core(state,kind,1,0,"graduation")
	state.stardust+=10;state.starter_claimed=true

static func from_campaign(campaign:Dictionary) -> Dictionary:
	var result=initial()
	if campaign.graduation_seen:unlock(result)
	result.mastery=Campaign.count(campaign,"cosmos")
	return result

static func add_core(state:Dictionary,kind:String,rank:int,roll:int,origin:String) -> Dictionary:
	var core={"id":state.next_id,"kind":kind,"rank":rank,"roll":roll,"locked":false,"origin":origin}
	state.next_id+=1;state.inventory.append(core);return core

static func core_valid(core:Variant) -> bool:
	if not core is Dictionary:return false
	for key in ["id","rank","roll"]:
		if not core.get(key) is int:return false
	return core.id>0 and core.rank>=1 and core.rank<=3 and core.roll>=0 and core.roll<=15 and core.get("kind") in TYPES and core.get("locked") is bool and core.get("origin") is String

static func valid(state:Variant) -> bool:
	if not state is Dictionary or state.get("schema")!=1:return false
	for key in ["unlocked","starter_claimed"]:
		if not state.get(key) is bool:return false
	if state.unlocked!=state.starter_claimed:return false
	for key in ["next_id","stardust","misses","mastery"]:
		if not state.get(key) is int or state[key]<0:return false
	if state.misses>=8 or state.next_id<1 or state.mastery>1000:return false
	if not state.get("inventory") is Array or not state.get("slots") is Array or state.slots.size()!=5:return false
	if not state.get("skills") is Array or state.skills.size()!=5:return false
	var ids={};var highest=0;var used={}
	for core in state.inventory:
		if not core_valid(core) or ids.has(core.id):return false
		ids[core.id]=true;highest=maxi(highest,core.id)
	if state.next_id<=highest:return false
	for id in state.slots:
		if not id is int or (id!=0 and (not ids.has(id) or used.has(id))):return false
		if id!=0:used[id]=true
	for skill in state.skills:
		if not skill is int or skill not in [0,1,2]:return false
	if not state.unlocked and (not state.inventory.is_empty() or state.stardust!=0 or state.mastery!=0 or state.misses!=0 or state.next_id!=1 or state.slots.any(func(id):return id!=0) or state.skills.any(func(choice):return choice!=0)):return false
	return true

static func item(state:Dictionary,id:int) -> Dictionary:
	for core in state.inventory:
		if core.id==id:return core
	return {}

static func owner(state:Dictionary,id:int) -> int:return state.slots.find(id) if id>0 else -1
static func title(core:Dictionary) -> String:return "%s · 阶%d"%[catalog().core_types[core.kind].name,core.rank]
static func upgrade_cost(core:Dictionary) -> int:return 15 if core.rank==1 else 35
static func salvage_value(core:Dictionary) -> int:return [4,10,22][core.rank-1]

static func bonuses(core:Dictionary) -> Dictionary:
	var rank=core.rank-1;var roll=core.roll*.001
	match core.kind:
		"lance":return {"attack":.12+.06*rank+roll,"elite":12+6*rank}
		"aegis":return {"health":.18+.08*rank+roll,"shield":.05+.02*rank}
		"relay":return {"speed":3+rank+core.roll*.05,"heal":20+10*rank}
	return {}

static func description(core:Dictionary) -> String:
	var bonus=bonuses(core);var result=catalog().core_types[core.kind].description+"\n\n"
	match core.kind:
		"lance":result+="攻击 +%.1f%%\n对首领伤害 +%d%%"%[bonus.attack*100,bonus.elite]
		"aegis":result+="最大生命 +%.1f%%\n入场护盾 +%.0f%%最大生命"%[bonus.health*100,bonus.shield*100]
		"relay":result+="行动速度 +%.2f\n治疗加成 +%d%%"%[bonus.speed,bonus.heal]
	return result+"\n词条品质：%d / 15"%core.roll

static func apply_stats(state:Dictionary,hero:int,stats:Dictionary) -> Dictionary:
	if not state.unlocked:return stats
	var core=item(state,state.slots[hero])
	if core.is_empty():return stats
	var bonus=bonuses(core)
	stats.atk*=1+bonus.get("attack",0);stats.hp*=1+bonus.get("health",0)
	stats.elite+=bonus.get("elite",0);stats.speed+=bonus.get("speed",0);stats.heal+=bonus.get("heal",0)
	stats.shield=minf(stats.hp*.35,stats.shield+stats.hp*bonus.get("shield",0))
	return stats

static func skill_available(state:Dictionary,choice:int) -> bool:
	return state.unlocked and choice>=0 and choice<3 and state.mastery>=int(catalog().skill_clear_thresholds[choice])
