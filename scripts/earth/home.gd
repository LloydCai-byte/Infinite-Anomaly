extends RefCounted
# Each entry names a whole-room illustration. Missing art uses explicit interaction
# markers over the empty room; it never assembles people out of cutout sprites.
const ROOM_IDS = ["living","workroom","kitchen","bathroom","bedroom","balcony","corridor"]
const ROOM_NAMES = ["客厅","工作间","厨房","卫生间","卧室","阳台","走廊"]
const PRESETS = [
	{"living":[],"workroom":["gao","dadong"],"kitchen":["qiqi","wang"],"balcony":["fenfen"]},
	{"living":["fenfen"],"workroom":["wang"],"bedroom":["qiqi"],"balcony":["dadong","gao"]},
	{"living":["qiqi","wang"],"workroom":["fenfen"],"kitchen":["dadong","gao"]},
	{"living":["gao"],"kitchen":["qiqi"],"bedroom":["fenfen"],"balcony":["wang","dadong"]},
	{"living":["dadong"],"workroom":["wang","fenfen"],"kitchen":["gao"],"balcony":["qiqi"]},
	{"living":[],"workroom":["qiqi","gao"],"kitchen":["fenfen"],"bedroom":["wang"],"balcony":["dadong"]}
]
const LINKS = {
	"living":["workroom","corridor","balcony"],"workroom":["living"],
	"corridor":["living","kitchen","bathroom","bedroom"],
	"kitchen":["corridor"],"bathroom":["corridor"],"bedroom":["corridor"],"balcony":["living"]
}
const NAMES={"dadong":"大东老师","fenfen":"粉粉","gao":"高哥","wang":"老王","qiqi":"七七","xuan":"轩轩"}
const LINES={
	"dadong":["先把路线摸清楚，我来走前面。","门外不会总是同一种地方。我们得留一条退路。"],
	"fenfen":["装备准备好了就叫我。站在这里猜，不如出去看。","上次的异常有破绽。下一次我会更快。"],
	"gao":["人齐了再走。有什么情况，我会挡住。","别急着往前冲。先看看大家的状态。"],
	"wang":["我把见过的异常记下来了。规律通常藏在差别里。","门外带回的装备，或许能改变下一场战斗。"],
	"qiqi":["大家都回来了……这样就好。","我会看好你们的伤势。也别忘了照顾自己。"],
	"xuan":["这里暂时是你们的家。门后有什么，要你们自己去看。","打印舱可以制造整套战斗服。外门连接的世界，最好先看清再进入。"]
}

static func room_name(id: String) -> String:
	return ROOM_NAMES[ROOM_IDS.find(id)] if id in ROOM_IDS else "未知空间"

static func members(preset: int,room: String) -> Array:
	var result=PRESETS[clampi(preset,0,PRESETS.size()-1)].get(room,[]).duplicate()
	if room=="living": result.append("xuan")
	return result

static func image_id(preset: int,room: String) -> String:
	var people=members(preset,room)
	people.sort()
	return "home."+room+"."+"_".join(people) if not people.is_empty() else "room."+room

static func new_state() -> Dictionary:
	return {"room":"living","preset":0,"visits":0}

static func valid(data: Variant) -> bool:
	return data is Dictionary and data.get("room","") in ROOM_IDS and data.get("preset") is int and data.preset>=0 and data.preset<PRESETS.size() and data.get("visits") is int and data.visits>=0

static func reroll(data: Dictionary) -> void:
	data.preset=(data.preset+randi_range(1,PRESETS.size()-1))%PRESETS.size()
	data.visits+=1
	data.room="living"

static func hotspots(room: String,ids: Array) -> Array:
	var zones=[]
	for i in range(ids.size()):
		if ids[i]=="xuan": zones.append([1270,430,280,370])
		else: zones.append([520+i*300,365,230,320])
	return zones
