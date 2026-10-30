extends RefCounted
const Campaign=preload("res://scripts/pixel_home/campaign.gd")
const Narrative=preload("res://scripts/pixel_home/narrative.gd")
static var data:Dictionary={}
static func catalog() -> Dictionary:
	if data.is_empty():data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/pixel_campaign/finale.json"))
	return data
static func initial(cycle:int=1) -> Dictionary:
	return {"schema":1,"cycle":cycle,"status":"idle","next":0,"attempts":0,"checkpoint":[],"battles":[],"ending_seen":false}
static func eligible(campaign:Dictionary,narrative:Dictionary) -> bool:
	return campaign.phase=="cosmos" and Campaign.cosmos_complete(campaign) and Narrative.seen(narrative,"core_approach",campaign.cycle)
static func valid_party(value:Variant) -> bool:
	if not value is Array or value.size()!=5:return false
	for member in value:
		if not member is Dictionary:return false
		for key in ["hp","shield"]:
			var number=member.get(key)
			if not (number is int or number is float) or not is_finite(float(number)) or number<0 or number>(1.0 if key=="hp" else .350001):return false
	return value.any(func(member):return member.hp>0)
static func valid(state:Variant,campaign:Dictionary,narrative:Dictionary) -> bool:
	if not state is Dictionary or state.get("schema")!=1 or state.get("cycle")!=campaign.cycle:return false
	if state.get("status") not in ["idle","active","failed","won","complete"]:return false
	if not state.get("next") is int or state.next<0 or state.next>4 or not state.get("attempts") is int or state.attempts<0:return false
	if not state.get("battles") is Array or state.battles.size()!=state.next or not state.get("checkpoint") is Array or not state.get("ending_seen") is bool:return false
	for i in range(state.battles.size()):
		var record=state.battles[i]
		if not record is Dictionary or record.get("id")!=catalog().battles[i].id:return false
		if not record.get("downs") is int or record.downs<0 or record.downs>4:return false
		var seconds=record.get("seconds")
		if not (seconds is int or seconds is float) or not is_finite(float(seconds)) or seconds<0:return false
	if state.status=="idle":return state.next==0 and state.attempts==0 and state.checkpoint.is_empty() and not state.ending_seen
	if not eligible(campaign,narrative) or state.attempts<1:return false
	if state.next>0 and not valid_party(state.checkpoint):return false
	if state.next==0 and not state.checkpoint.is_empty():return false
	if (state.next==4)!=(state.status in ["won","complete"]):return false
	return state.ending_seen==(state.status=="complete")
