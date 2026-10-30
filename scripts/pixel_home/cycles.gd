extends RefCounted
const Campaign=preload("res://scripts/pixel_home/campaign.gd")
static var data:Dictionary={}
static func catalog() -> Dictionary:
	if data.is_empty():data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/pixel_campaign/cycles.json"))
	return data
static func initial() -> Dictionary:
	return {"schema":1,"history":[],"secondary_support":"","resonance":-1,"skill_rank":0,"pending_intro":0,"game_complete":false}
static func receipt(cycle:int,level:int,campaign:Dictionary={}) -> Dictionary:
	if campaign.get("schema")==2:
		var old=Campaign.legacy_state(campaign)
		return {"schema":2,"cycle":cycle,"level":level,"earth_clears":Campaign.count(campaign,"earth"),"earth_gold":Campaign.count(campaign,"earth",true),"earth_shimmer":Campaign.shimmer_count(campaign,"earth"),"planet_clears":Campaign.count(campaign,"cosmos"),"legacy_earth":Campaign.legacy_graduated(campaign),"legacy_planets":0 if old.is_empty() else Campaign.Legacy.count(old,"cosmos"),"bosses":4}
	return {"cycle":cycle,"level":level,"earth_gold":300,"planet_clears":300,"bosses":4}
static func from_progress(campaign:Dictionary,finale:Dictionary,level:int) -> Dictionary:
	var state=initial()
	if campaign.cycle==1 and finale.status=="complete":state.history.append(receipt(1,level,campaign))
	return state
static func valid(state:Variant,campaign:Dictionary,finale:Dictionary,events:Dictionary) -> bool:
	if not state is Dictionary or state.get("schema")!=1 or not state.get("history") is Array:return false
	var expected=campaign.cycle if finale.status=="complete" else campaign.cycle-1
	if state.history.size()!=expected:return false
	for i in range(state.history.size()):
		var entry=state.history[i]
		if not entry is Dictionary or entry.get("cycle")!=i+1 or entry.get("bosses")!=4:return false
		if entry.get("schema",1)==1:
			if entry.get("earth_gold")!=300 or entry.get("planet_clears")!=300:return false
		elif entry.get("schema")==2:
			for field in ["earth_clears","earth_gold","earth_shimmer","planet_clears","legacy_planets"]:
				if not entry.get(field) is int or entry[field]<0 or entry[field]>1000:return false
			if not entry.get("legacy_earth") is bool or entry.legacy_planets>300:return false
			if entry.earth_shimmer>entry.earth_gold or entry.earth_gold>entry.earth_clears:return false
			if entry.earth_shimmer!=1000 and not entry.legacy_earth:return false
			if entry.planet_clears!=1000 and entry.legacy_planets!=300:return false
			if entry.legacy_planets>0 and not entry.legacy_earth:return false
		else:return false
		if not entry.get("level") is int or entry.level<1:return false
	if not state.get("skill_rank") is int or state.skill_rank<0 or state.skill_rank>5:return false
	if not state.get("pending_intro") is int or state.pending_intro not in [0,2,3]:return false
	if state.pending_intro!=0 and (state.pending_intro!=campaign.cycle or campaign.phase!="earth" or not campaign.levels.is_empty()):return false
	if not state.get("secondary_support") is String:return false
	if state.secondary_support!="" and (campaign.cycle<2 or not events.supports.has(state.secondary_support) or state.secondary_support==events.equipped):return false
	if not state.get("resonance") is int or state.resonance not in ([-1] if campaign.cycle<3 else [0,1,2]):return false
	if not state.get("game_complete") is bool or state.game_complete!=(campaign.cycle==3 and finale.status=="complete"):return false
	return true
static func difficulty(cycle:int) -> Dictionary:return catalog().difficulty[clampi(cycle-1,0,2)]
