extends RefCounted
## All coordinates describe the native 1672x941 plates; hero height stays 132.
const IDS=["living","work","corridor","kitchen","bathroom","bedroom","balcony"]
const ART="res://art/feedback-round2-20261028/rooms/"
const SOURCE=Vector2(1672,941)
static func door(id:String,name:String,p:Vector2,to:String,spawn:Vector2) -> Dictionary:
	return {"id":id,"name":name,"point":p,"to":to,"spawn":spawn}
static func prop(id:String,name:String,p:Vector2) -> Dictionary:return {"id":id,"name":name,"point":p}
static func source_data(id:String) -> Dictionary:
	match id:
		"living":return {"name":"客厅","floor":Rect2(120,255,1430,620),"passages":[Rect2(80,330,60,85),Rect2(1540,375,55,115)],"spawn":Vector2(836,775),"blocks":[Rect2(130,478,148,304),Rect2(532,491,201,160),Rect2(1110,586,119,148),Rect2(1035,245,215,72),Rect2(140,747,55,80),Rect2(1450,730,95,100)],"objects":[
			prop("exit","黑门 · 安排出战",Vector2(530,296)),door("work","进入工作间",Vector2(890,296),"work",Vector2(836,750)),door("hall","进入生活走廊",Vector2(120,370),"corridor",Vector2(1040,460)),door("balcony","推开阳台门",Vector2(1535,435),"balcony",Vector2(710,440)),
			prop("archive","书柜 · 成长档案",Vector2(1130,359)),prop("tea","茶几 · 未凉的茶",Vector2(630,690)),prop("chair","轩轩的座椅",Vector2(1170,775))]}
		"work":return {"name":"工作间","art_scale":.78,"floor":Rect2(122,385,1428,495),"passages":[Rect2(700,860,270,40)],"spawn":Vector2(836,750),"blocks":[],"objects":[
			door("living","回到客厅",Vector2(836,842),"living",Vector2(890,350)),prop("equipment","打印舱 · 装备整备",Vector2(350,445)),prop("relic","收集阵 · 支援装置",Vector2(1240,415)),prop("work_archive","工作记录 · 小队档案",Vector2(835,410))]}
		"corridor":return {"name":"生活走廊","art_scale":.90,"floor":Rect2(604,160,466,755),"passages":[Rect2(485,214,135,92),Rect2(485,427,135,92),Rect2(485,682,135,90),Rect2(1060,413,125,95)],"spawn":Vector2(1040,460),"blocks":[Rect2(968,125,70,72)],"objects":[
			door("living","回到客厅",Vector2(1115,460),"living",Vector2(210,370)),door("kitchen","进入厨房",Vector2(560,265),"kitchen",Vector2(1300,485)),door("bathroom","进入卫生间",Vector2(560,472),"bathroom",Vector2(1090,535)),door("bedroom","进入卧室",Vector2(560,730),"bedroom",Vector2(1250,560)),prop("hall_picture","墙边的合照",Vector2(1025,220))]}
		"kitchen":return {"name":"厨房","art_scale":.72,"floor":Rect2(280,410,1115,455),"passages":[Rect2(1385,420,50,115)],"spawn":Vector2(1300,485),"blocks":[Rect2(278,410,83,253)],"objects":[
			door("hall","回到走廊",Vector2(1385,480),"corridor",Vector2(710,265)),prop("sink","水槽边的杯子",Vector2(665,445)),prop("fridge","冰箱上的便签",Vector2(410,450)),prop("stove","灶台上的锅",Vector2(910,445))]}
		"bathroom":return {"name":"卫生间","art_scale":.85,"floor":Rect2(516,350,640,496),"passages":[Rect2(1140,490,145,82)],"spawn":Vector2(1090,535),"blocks":[Rect2(520,468,188,276),Rect2(618,350,81,98),Rect2(900,350,180,100)],"objects":[
			door("hall","回到走廊",Vector2(1185,535),"corridor",Vector2(710,472)),prop("mirror","洗手台与镜子",Vector2(980,495)),prop("shower","淋浴间",Vector2(770,640))]}
		"bedroom":return {"name":"卧室","art_scale":.78,"floor":Rect2(325,260,987,585),"passages":[Rect2(1300,505,160,98)],"spawn":Vector2(1250,560),"blocks":[Rect2(460,255,291,360),Rect2(354,275,100,101),Rect2(915,260,310,98)],"objects":[
			door("hall","回到走廊",Vector2(1345,555),"corridor",Vector2(710,730)),prop("bed","床边的归来记录",Vector2(820,530)),prop("wardrobe","衣柜",Vector2(1075,415))]}
		"balcony":return {"name":"阳台","art_scale":.90,"floor":Rect2(632,270,345,636),"passages":[Rect2(505,388,145,92)],"spawn":Vector2(710,440),"blocks":[Rect2(638,644,160,248)],"objects":[
			door("living","回到客厅",Vector2(595,440),"living",Vector2(1450,435)),prop("plants","架上的植物",Vector2(815,312)),prop("laundry","晾着的衣服",Vector2(855,835)),prop("window","栏杆外的虚无",Vector2(939,600))]}
	return {}
static func scale_for(id:String) -> float:return float(source_data(id).get("art_scale",1.0))
static func to_screen(id:String,point:Vector2) -> Vector2:
	return Vector2(800,450)+(point*Vector2(1600,900)/SOURCE-Vector2(800,450))*scale_for(id)
static func rect_to_screen(id:String,rect:Rect2) -> Rect2:return Rect2(to_screen(id,rect.position),rect.size*Vector2(1600,900)/SOURCE*scale_for(id))
static func image_rect(id:String) -> Rect2:return rect_to_screen(id,Rect2(Vector2.ZERO,SOURCE))
static func data(id:String) -> Dictionary:
	var result=source_data(id).duplicate(true)
	if result.is_empty():return result
	result.floor=rect_to_screen(id,result.floor);result.spawn=to_screen(id,result.spawn)
	result.blocks=result.blocks.map(func(rect):return rect_to_screen(id,rect))
	if result.has("passages"):result.passages=result.passages.map(func(rect):return rect_to_screen(id,rect))
	for entry in result.objects:
		entry.point=to_screen(id,entry.point)
		if entry.has("to"):entry.spawn=to_screen(entry.to,entry.spawn)
	return result
static func image_path(id:String) -> String:
	if id=="living":return "res://art/home-life-20261029/living.png"
	if id=="bathroom":return "res://art/feedback-round3-20261028/rooms/bathroom.png"
	return ART+id+".png"
