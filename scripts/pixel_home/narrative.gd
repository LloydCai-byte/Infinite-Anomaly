extends RefCounted
const Campaign=preload("res://scripts/pixel_home/campaign.gd")
static var data:Dictionary={}
static func catalog() -> Dictionary:
	if data.is_empty():data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/pixel_campaign/cosmic_story.json"))
	return data
static func initial() -> Dictionary:return {"schema":1,"seen":[],"pending":{}}
static func find(id:String) -> Dictionary:
	for chapter in catalog().chapters:
		if chapter.id==id:return chapter
	return {}
static func seen(state:Dictionary,id:String,cycle:int) -> bool:
	return state.seen.any(func(entry):return entry.id==id and entry.cycle==cycle)
static func next_entry(state:Dictionary,campaign:Dictionary) -> Dictionary:
	if campaign.phase!="cosmos":return {}
	var clears=Campaign.story_progress(campaign)
	for chapter in catalog().chapters:
		var threshold=int(chapter.clears)
		if campaign.schema==2 and threshold>1:threshold=ceili(threshold*1000.0/300.0)
		if threshold>clears:break
		if not seen(state,chapter.id,campaign.cycle):return {"id":chapter.id,"cycle":campaign.cycle}
	return {}
static func reserve(state:Dictionary,campaign:Dictionary) -> bool:
	if not state.pending.is_empty():return false
	var next=next_entry(state,campaign)
	if next.is_empty():return false
	state.pending=next;return true
static func from_campaign(campaign:Dictionary) -> Dictionary:
	var state=initial();reserve(state,campaign);return state
static func valid(state:Variant,campaign:Dictionary) -> bool:
	if not state is Dictionary or state.get("schema")!=1 or not state.get("seen") is Array or not state.get("pending") is Dictionary:return false
	var keys={}
	for entry in state.seen:
		if not entry is Dictionary or not entry.get("id") is String or find(entry.id).is_empty() or not entry.get("cycle") is int or entry.cycle<1 or entry.cycle>campaign.cycle:return false
		var key="%d:%s"%[entry.cycle,entry.id]
		if keys.has(key):return false
		keys[key]=true
	if not state.pending.is_empty() and state.pending!=next_entry(state,campaign):return false
	return true
