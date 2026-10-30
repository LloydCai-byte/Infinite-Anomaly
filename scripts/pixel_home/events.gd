extends RefCounted
const PATH="res://assets/pixel_campaign/home_events.json"
static var cached:Dictionary={}
static func catalog() -> Dictionary:
	if cached.is_empty():cached=JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return cached

static func initial(seed_value:int) -> Dictionary:
	var rng=RandomNumberGenerator.new();rng.seed=seed_value
	return {"schema":1,"rng":rng.state,"serial":0,"ticket":{},"pending":{},"eligible_returns":0,"misses":0,"seen":{},"last":{},"materials":0,"supports":{},"equipped":"","history":[]}

static func find(id:String) -> Dictionary:
	for event in catalog().events:
		if event.id==id:return event
	return {}

static func valid(state:Variant) -> bool:
	if not state is Dictionary or state.get("schema")!=1:return false
	for key in ["rng","serial","eligible_returns","misses","materials"]:
		if not state.get(key) is int or (key!="rng" and state[key]<0):return false
	for key in ["ticket","pending","seen","last","supports"]:
		if not state.get(key) is Dictionary:return false
	if not state.get("history") is Array or state.history.size()>50:return false
	if not state.get("equipped") is String:return false
	var cfg=catalog()
	for id in state.supports:
		if id not in cfg.supports or not state.supports[id] is int or state.supports[id]<1 or state.supports[id]>3:return false
	if state.equipped!="" and state.equipped not in state.supports:return false
	for key in ["seen","last"]:
		for id in state[key]:
			if find(id).is_empty() or not state[key][id] is int or state[key][id]<0:return false
	if not state.ticket.is_empty():
		for key in ["id","kills","clears"]:
			if not state.ticket.get(key) is int or state.ticket[key]<0:return false
		if state.ticket.id>state.serial:return false
	if not state.pending.is_empty():
		if not state.pending.get("ticket") is int or state.pending.ticket<1 or state.pending.ticket>state.serial:return false
		if not state.pending.get("id") is String or find(state.pending.id).is_empty():return false
		if not state.ticket.is_empty():return false
	for entry in state.history:
		if not entry is Dictionary or not entry.get("id") is String or find(entry.id).is_empty() or not entry.get("reward") is String:return false
	return true

static func available(state:Dictionary,context:Dictionary,reward_eligible:bool) -> Array:
	var result=[]
	for event in catalog().events:
		if event.phase!="any" and event.phase!=context.phase:continue
		if context.cleared<event.min or context.cleared>event.max:continue
		if context.cycle<int(event.get("min_cycle",1)):continue
		if event.once and state.seen.get(event.id,0)>0:continue
		if not reward_eligible and not event.reward.is_empty():continue
		if state.last.has(event.id) and state.eligible_returns-state.last[event.id]<int(event.cooldown):continue
		result.append(event)
	return result

static func roll(state:Dictionary,context:Dictionary,reward_eligible:bool) -> String:
	var rng=RandomNumberGenerator.new();rng.state=state.rng
	var pool=available(state,context,reward_eligible)
	if pool.is_empty():return ""
	var cfg=catalog()
	if rng.randf()>cfg.chance and state.misses<int(cfg.pity_returns)-1:
		state.misses+=1;state.rng=rng.state;return ""
	var weight=0
	for event in pool:weight+=int(event.weight)
	var pick=rng.randi_range(1,weight);state.rng=rng.state;state.misses=0
	for event in pool:
		pick-=int(event.weight)
		if pick<=0:return event.id
	return ""
