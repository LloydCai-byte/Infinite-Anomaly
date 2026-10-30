extends RefCounted
## Authored pose loops: planted feet/hips, shared scale, no whole-character bobbing.
const ART="res://art/home-life-20261029/"
const XUAN_ART="res://art/xuan-motion-20261029/"
const NPCS=[
	{"id":"fenfen","name":"粉粉","room":"living","source":Vector2(240,625),"approach":Vector2(350,645),"seated":true,"line":"别一直站着。茶还热，坐一会儿再开门。刀上的那些字……等回来再慢慢看。"},
	{"id":"gao","name":"高哥","room":"balcony","source":Vector2(910,530),"approach":Vector2(840,555),"line":"外面没有风，叶子却一直在动。你先进去，我在这里看一会儿。出发时叫我。"},
	{"id":"qiqi","name":"七七","room":"living","source":Vector2(1165,487),"approach":Vector2(1140,545),"line":"老王说刚才只是水管响。可我听得很清楚，那声音叫的是我们的名字。"},
	{"id":"dadong","name":"大东老师","room":"work","source":Vector2(430,410),"approach":Vector2(520,465),"line":"没有人按打印，它却多吐出了一页。日期是明天，纸上写着我们下一次出发的时间。"},
	{"id":"wang","name":"老王","room":"living","source":Vector2(1300,487),"approach":Vector2(1325,545),"line":"我不是说你听错了。我是想知道——如果这里没有别人，到底是谁在叫我们？"}
]
var atlas:Dictionary
func _init() -> void:
	atlas=JSON.parse_string(FileAccess.get_file_as_string(ART+"frames.json")).actors
	atlas.xuan=JSON.parse_string(FileAccess.get_file_as_string(XUAN_ART+"frames.json"))

func texture_path(id:String) -> String:
	var file:String=atlas[id].file
	return file if file.begins_with("res://") else ART+file

func player_frame(direction:int,moving:bool,time:float) -> int:
	var data=atlas.xuan
	var column:int=data.walk_columns[floori(time*data.walk_fps)%data.walk_columns.size()] if moving else data.idle_columns[direction]
	return direction*int(data.columns)+column

func player_stride_seconds(distance:float,speed:float) -> float:
	# Only actual travelled distance advances a step, including diagonal wall sliding.
	return distance/maxf(speed,1.0)

func actors(room:String) -> Array:
	var result=[]
	for data in NPCS:
		if data.room!=room:continue
		var actor=data.duplicate(true)
		actor.foot=preload("res://scripts/pixel_home/rooms.gd").to_screen(room,data.source)
		actor.point=preload("res://scripts/pixel_home/rooms.gd").to_screen(room,data.approach)
		result.append(actor)
	return result

func frame_index(id:String,time:float) -> int:
	# Conversation is a shared beat: Qiqi speaks first; Wang listens, then answers.
	if id=="qiqi":
		var t=fposmod(time,8.0)
		if t<1.2:return 0
		if t<2.5:return 1
		if t<3.2:return 2
		return 3
	if id=="wang":
		var t=fposmod(time,8.0)
		if t<2.7:return 0
		if t<3.15:return 1
		if t<4.1:return 0
		if t<6.1:return 2
		return 3
	var sequence=[]
	match id:
		"fenfen":sequence=[[0,2.8],[1,.18],[0,.7],[2,.65],[3,1.8]]
		"gao":sequence=[[0,2.3],[1,1.0],[0,1.2],[2,.22],[3,1.5]]
		"dadong":sequence=[[0,1.8],[1,.7],[2,1.0],[1,.45],[3,1.7]]
		_:return 0
	var total=0.0
	for beat in sequence:total+=beat[1]
	var elapsed=fposmod(time,total)
	for beat in sequence:
		if elapsed<beat[1]:return beat[0]
		elapsed-=beat[1]
	return 0

func draw_actor(canvas:Node2D,id:String,index:int,anchor:Vector2) -> void:
	var data=atlas[id];var frame=data.frames[index];var rect=frame.rect
	var src=Rect2(rect[0],rect[1],rect[2],rect[3])
	var height=float(data.reference_height)
	var scale=132.0/height
	var pivot=Vector2(frame.pivot[0],frame.pivot[1])*scale
	canvas.draw_texture_rect_region(canvas.texture(texture_path(id)),Rect2((anchor-pivot).round(),(src.size*scale).round()),src)
