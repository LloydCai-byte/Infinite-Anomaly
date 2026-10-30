extends RefCounted
## Stable campaign IDs align with the material table. A record is never content.
const EARTH_COUNT=300
const LAST_LEVEL=600
const GOLD_DEPTH=3
const GOLD_RULE="强度3及以上，连续完成本关全部10景，过程中五人无人倒下。不限时间。"

static func initial() -> Dictionary:
	return {"schema":1,"cycle":1,"phase":"earth","levels":{},"graduation_seen":false,"pending_story":"","story_seen":[]}

static func key(id:int) -> String:return "L%03d"%id
static func id_of(value:String) -> int:
	if value.length()!=4 or not value.begins_with("L") or not value.substr(1).is_valid_int():return 0
	var id=value.substr(1).to_int()
	return id if id>=1 and id<=LAST_LEVEL and key(id)==value else 0

static func empty_record() -> Dictionary:
	return {"clears":0,"best_depth":0,"gold":false,"gold_depth":0,"best_seconds":0.0,"last_downs":0,"last_reason":"尚未通关","source":"battle"}

static func record_valid(record:Variant) -> bool:
	if not record is Dictionary:return false
	for field in ["clears","best_depth","gold_depth","last_downs"]:
		if not record.get(field) is int or record[field]<0:return false
	if record.last_downs>5 or not record.get("gold") is bool:return false
	if not (record.get("best_seconds") is int or record.get("best_seconds") is float) or not is_finite(float(record.best_seconds)) or record.best_seconds<0:return false
	if not record.get("last_reason") is String or not record.get("source") is String:return false
	if record.gold and (record.clears<1 or record.gold_depth<GOLD_DEPTH or record.best_depth<record.gold_depth):return false
	if not record.gold and record.gold_depth!=0:return false
	return true

static func valid(value:Variant) -> bool:
	if not value is Dictionary or value.get("schema")!=1:return false
	if not value.get("cycle") is int or value.cycle<1 or value.cycle>3:return false
	if value.get("phase") not in ["earth","cosmos"]:return false
	if not value.get("levels") is Dictionary:return false
	for entry in value.levels:
		if not entry is String or id_of(entry)==0 or not record_valid(value.levels[entry]):return false
	if not value.get("graduation_seen") is bool:return false
	if value.get("pending_story") not in ["","graduation"]:return false
	if not value.get("story_seen") is Array:return false
	for story in value.story_seen:
		if not story is String or story!="graduation":return false
	if value.story_seen.size()>1:return false
	if value.graduation_seen!=("graduation" in value.story_seen):return false
	if (value.phase=="cosmos")!=value.graduation_seen:return false
	if value.phase=="earth" and value.levels.keys().any(func(entry):return id_of(entry)>EARTH_COUNT):return false
	if value.graduation_seen and (count(value,"earth",false)!=EARTH_COUNT or count(value,"earth",true)!=EARTH_COUNT):return false
	if value.pending_story=="graduation" and (value.graduation_seen or not eligible(value)):return false
	return true

static func count(state:Dictionary,phase:String,gold:bool=false) -> int:
	var total=0;var first=1 if phase=="earth" else 301;var last=300 if phase=="earth" else 600
	for id in range(first,last+1):
		var record=state.levels.get(key(id),{})
		if record.get("clears",0)>0 and (not gold or record.get("gold",false)):total+=1
	return total

static func eligible(state:Dictionary) -> bool:
	return state.phase=="earth" and not state.graduation_seen and count(state,"earth",false)==EARTH_COUNT and count(state,"earth",true)==EARTH_COUNT

static func from_growth(growth:Dictionary) -> Dictionary:
	var result=initial()
	for pair in [[1,"hyakki"],[2,"sleepbeast"]]:
		var world=growth.get("worlds",{}).get(pair[1],{})
		if int(world.get("clears",0))<=0:continue
		var r=empty_record();r.clears=int(world.clears);r.best_depth=int(world.best_depth)
		r.source="legacy_growth";r.last_reason="通关记录已保留；金标请按新规则挑战。";result.levels[key(pair[0])]=r
	return result

static func apply_result(state:Dictionary,id:int,depth:int,scenes:int,downs:int,seconds:float,complete_run:bool) -> Dictionary:
	if id<1 or id>LAST_LEVEL or not complete_run or scenes!=10 or depth<1 or downs<0 or downs>5 or seconds<0 or not is_finite(seconds):return {}
	if id>EARTH_COUNT and state.phase!="cosmos":return {}
	var record=state.levels.get(key(id),empty_record()).duplicate(true)
	var new_gold=depth>=GOLD_DEPTH and downs==0
	var first_gold=new_gold and not record.gold
	record.clears+=1;record.best_depth=maxi(record.best_depth,depth);record.last_downs=downs;record.source="battle"
	record.best_seconds=seconds if record.best_seconds<=0 else minf(seconds,record.best_seconds)
	if new_gold:record.gold=true;record.gold_depth=maxi(record.gold_depth,depth)
	record.last_reason="金标达成" if new_gold else "强度不足3" if depth<GOLD_DEPTH else "本次有%d名队员倒下"%downs
	state.levels[key(id)]=record
	if eligible(state):state.pending_story="graduation"
	return {"id":id,"gold":new_gold,"first_gold":first_gold,"reason":record.last_reason,"clears":record.clears}
