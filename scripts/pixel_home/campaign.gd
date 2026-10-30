extends RefCounted
## Room clears and the archived ten-picture campaign remain separate ledgers.
const Legacy=preload("res://scripts/pixel_home/campaign_legacy.gd")
const Layout=preload("res://scripts/pixel_home/room_layout.gd")
const EARTH_COUNT=1000
const LAST_LEVEL=2000
const GOLD_DEPTH=5
const GOLD_RULE="同一房间完成3种难度获银标，5种获金标，10种获闪光标；每次须打完十波。"
const GATES=["shimmer"]

static func initial(gate:String="shimmer") -> Dictionary:
	return {"schema":2,"cycle":1,"phase":"earth","levels":{},"graduation_seen":false,"pending_story":"","story_seen":[],"gate":gate,"legacy":{}}

static func key(id:int) -> String:return Layout.key(id)
static func id_of(value:String) -> int:return Layout.id_of(value)
static func empty_record() -> Dictionary:
	return {"clears":0,"mask":0,"best_depth":0,"gold":false,"gold_depth":0,"best_seconds":0.0,"last_downs":0,"last_reason":"尚未通关","source":"room_battle"}

static func difficulties(record:Dictionary) -> Array:
	var result=[]
	for i in range(10):
		if int(record.get("mask",0)) & (1<<i):result.append(i+1)
	return result
static func difficulty_count(record:Dictionary) -> int:return difficulties(record).size()
static func badge(record:Dictionary) -> String:
	var n=difficulty_count(record)
	return "shimmer" if n==10 else "gold" if n>=5 else "silver" if n>=3 else "clear" if n>0 else "unvisited"
static func badge_title(value:String) -> String:
	return {"unvisited":"尚未通关","clear":"已通关","silver":"银标","gold":"金标","shimmer":"闪光完成"}.get(value,"")

static func record_valid(record:Variant) -> bool:
	if not record is Dictionary:return false
	for field in ["clears","mask","best_depth","gold_depth","last_downs"]:
		if not record.get(field) is int or record[field]<0:return false
	if record.mask<1 or record.mask>1023 or record.last_downs>5:return false
	var ds=difficulties(record);var n=ds.size()
	if record.clears<n or record.best_depth!=ds.back():return false
	if not record.get("gold") is bool or record.gold!=(n>=5):return false
	if record.gold_depth!=(record.best_depth if record.gold else 0):return false
	if not (record.get("best_seconds") is int or record.get("best_seconds") is float) or not is_finite(float(record.best_seconds)) or record.best_seconds<0:return false
	return record.get("last_reason") is String and record.get("source")=="room_battle"

static func legacy_state(state:Dictionary) -> Dictionary:
	return state if state.get("schema")==1 else state.get("legacy",{})
static func legacy_graduated(state:Dictionary) -> bool:return legacy_state(state).get("graduation_seen",false)
static func phase_count(state:Dictionary) -> int:return 300 if state.get("schema")==1 else EARTH_COUNT

static func count(state:Dictionary,phase:String,gold:bool=false) -> int:
	if state.get("schema")==1:return Legacy.count(state,phase,gold)
	var total=0;var first=1 if phase=="earth" else EARTH_COUNT+1;var last=EARTH_COUNT if phase=="earth" else LAST_LEVEL
	for id in range(first,last+1):
		var record=state.levels.get(key(id),{})
		if record.get("clears",0)>0 and (not gold or record.get("gold",false)):total+=1
	return total
static func shimmer_count(state:Dictionary,phase:String) -> int:
	var total=0
	for entry in state.levels:
		var id=id_of(entry)
		if id>0 and (id<=EARTH_COUNT)==(phase=="earth") and badge(state.levels[entry])=="shimmer":total+=1
	return total

static func earth_qualified(state:Dictionary) -> bool:
	var old=legacy_state(state)
	if not old.is_empty() and (old.graduation_seen or Legacy.eligible(old)):return true
	return shimmer_count(state,"earth")==EARTH_COUNT
static func eligible(state:Dictionary) -> bool:
	if state.get("schema")==1:return Legacy.eligible(state)
	return state.phase=="earth" and not state.graduation_seen and earth_qualified(state)
static func cosmos_complete(state:Dictionary) -> bool:
	if count(state,"cosmos")==phase_count(state):return true
	var old=legacy_state(state)
	return not old.is_empty() and Legacy.count(old,"cosmos")==300
static func story_progress(state:Dictionary) -> int:
	var actual=count(state,"cosmos")
	if state.get("schema")==1:return actual
	var old=legacy_state(state)
	# Access credit preserves earned stories/checkpoints; it is not a room clear.
	return maxi(actual,ceili(Legacy.count(old,"cosmos")*1000.0/300.0)) if not old.is_empty() else actual

static func valid(value:Variant) -> bool:
	if not value is Dictionary:return false
	if value.get("schema")==1:return Legacy.valid(value)
	if value.get("schema")!=2 or not value.get("cycle") is int or value.cycle<1 or value.cycle>3:return false
	if value.get("phase") not in ["earth","cosmos"] or value.get("gate") not in GATES:return false
	if not value.get("levels") is Dictionary or not value.get("legacy") is Dictionary:return false
	if not value.legacy.is_empty() and (not Legacy.valid(value.legacy) or value.legacy.cycle!=value.cycle):return false
	for entry in value.levels:
		if not entry is String or id_of(entry)==0 or not record_valid(value.levels[entry]):return false
		if value.phase=="earth" and id_of(entry)>EARTH_COUNT:return false
	if not value.get("graduation_seen") is bool or value.get("pending_story") not in ["","graduation"]:return false
	if not value.get("story_seen") is Array or value.story_seen not in [[],["graduation"]]:return false
	if value.graduation_seen!=("graduation" in value.story_seen) or (value.phase=="cosmos")!=value.graduation_seen:return false
	if value.graduation_seen and not earth_qualified(value):return false
	if value.pending_story=="graduation" and not eligible(value):return false
	return true

static func migrate(old:Dictionary) -> Dictionary:
	if not valid(old):return {}
	if old.schema==2:return old.duplicate(true)
	var result=initial()
	for field in ["cycle","phase","graduation_seen","pending_story","story_seen"]:result[field]=old[field].duplicate(true) if old[field] is Array else old[field]
	result.legacy=old.duplicate(true)
	return result
static func from_growth(growth:Dictionary) -> Dictionary:return migrate(Legacy.from_growth(growth))

static func apply_result(state:Dictionary,id:int,depth:int,waves:int,downs:int,seconds:float,complete_run:bool) -> Dictionary:
	if state.get("schema")!=2 or id<1 or id>LAST_LEVEL or depth<1 or depth>10 or waves!=10 or not complete_run:return {}
	if downs<0 or downs>5 or not is_finite(seconds) or seconds<0 or (id>EARTH_COUNT and state.phase!="cosmos"):return {}
	var record=state.levels.get(key(id),empty_record()).duplicate(true);var previous=badge(record)
	var first_difficulty=(record.mask & (1<<(depth-1)))==0
	record.mask |= 1<<(depth-1);record.clears+=1;record.best_depth=maxi(record.best_depth,depth);record.last_downs=downs
	record.best_seconds=seconds if record.clears==1 else minf(seconds,record.best_seconds)
	record.gold=difficulty_count(record)>=5;record.gold_depth=record.best_depth if record.gold else 0
	var current=badge(record);record.last_reason="%s · 已完成%d/10种难度"%[badge_title(current),difficulty_count(record)]
	state.levels[key(id)]=record
	if eligible(state):state.pending_story="graduation"
	return {"id":id,"gold":record.gold,"first_gold":record.gold and previous not in ["gold","shimmer"],"badge":current,"badge_changed":current!=previous,"first_difficulty":first_difficulty,"difficulty_count":difficulty_count(record),"reason":record.last_reason,"clears":record.clears}
