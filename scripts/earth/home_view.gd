extends RefCounted
const Home=preload("res://scripts/earth/home.gd")
const Assets=preload("res://scripts/earth/assets.gd")
const C=preload("res://scripts/earth/catalog.gd")
var g: Control

func _init(game: Control) -> void: g=game

func draw(kind: String) -> void:
	match kind:
		"base": base()
		"map": map_screen()
		"squad": squad()
		"dialogue": dialogue()
		"printer": printer()
		"collection": collection()

func room_backdrop() -> bool:
	var h=g.model.s.home
	var id=Home.image_id(h.preset,h.room)
	var fused=Assets.final_available(id) and id.begins_with("home.")
	g.picture(Assets.texture(id) if fused else Assets.texture("room."+h.room),Rect2(0,0,1600,900))
	return fused

func top() -> void:
	g.button("settings","设置",Rect2(1210,24,140,55),g.open_settings)
	g.button("squad","小队情况",Rect2(1370,24,205,55),func():g.navigate("squad"))

func base() -> void:
	var fused=room_backdrop()
	var h=g.model.s.home
	match h.room:
		"living":
			g.hotspot("depart","异境出口 · 选择任务",Rect2(325,164,218,375),func():g.selected_stage=g.model.s.max_stage;g.mission_page=int((g.selected_stage-1)/10);g.navigate("missions"))
			g.hotspot("door_workroom","进入工作间",Rect2(745,157,193,412),func():g.change_room("workroom"))
			g.hotspot("door_corridor","进入走廊",Rect2(133,125,100,312),func():g.change_room("corridor"))
			g.hotspot("door_balcony","进入阳台",Rect2(1287,113,183,443),func():g.change_room("balcony"))
		"workroom":
			g.hotspot("printer","通体打印舱 · 制造与空间升级",Rect2(270,220,550,490),func():g.navigate("printer"))
		"corridor":
			g.hotspot("door_bedroom","进入卧室",Rect2(217,134,273,620),func():g.change_room("bedroom"))
			g.hotspot("door_bathroom","进入卫生间",Rect2(670,134,260,620),func():g.change_room("bathroom"))
			g.hotspot("door_kitchen","进入厨房",Rect2(1138,134,268,620),func():g.change_room("kitchen"))
	if h.room!="living":
		var dest="living" if h.room in ["workroom","corridor","balcony"] else "corridor"
		g.button("door_back","← 返回"+Home.room_name(dest),Rect2(28,818,225,54),func():g.change_room(dest))
	var ids=Home.members(h.preset,h.room)
	var zones=Home.hotspots(h.room,ids)
	var configured=g.home_hotspots.get(Home.image_id(h.preset,h.room),{})
	for i in range(ids.size()):
		var id=ids[i]
		var r=configured.get(id,zones[i])
		var bounds=Rect2(r[0],r[1],r[2],r[3])
		if fused:
			g.hotspot("talk_"+id,"与"+Home.NAMES[id]+"交谈",bounds,func():g.dialogue_id=id;g.navigate("dialogue"))
		else:
			# Temporary controls, not pretend-final pasted character sprites.
			g.button("talk_"+id,Home.NAMES[id]+" · 交谈",Rect2(bounds.position.x,720 if id!="xuan" else 785,210,50),func():g.dialogue_id=id;g.navigate("dialogue"))
	if not fused and not ids.is_empty():
		g.panel(Rect2(375,828,850,47))
		g.text("人物整图待替换 · 姓名标记用于体验交互",Rect2(397,832,806,37),18,g.MUTED)
	top()

func map_screen() -> void:
	room_backdrop()
	g.picture(Assets.ui("dim"),Rect2(0,0,1600,900))
	g.panel(Rect2(90,75,1420,755))
	g.text("家中位置",Rect2(135,95,1000,50),34)
	g.picture(Assets.texture("floorplan"),Rect2(125,168,800,615),true)
	# The archived SVG uses (72,140) + 83 pixels per metre on a 1440x1020 canvas.
	# Match TextureRect's aspect-preserving letterbox before mapping each room.
	var layout=JSON.parse_string(FileAccess.get_file_as_string("res://assets/earth/home/layout.json"))
	var scale=800.0/1440.0
	var origin=Vector2(125,168+(615-1020*scale)/2)
	for room in layout.rooms:
		var id=str(room.id).substr(3)
		var r=room.r
		var bounds=Rect2(origin+Vector2(72+r[0]*83,140+r[1]*83)*scale,Vector2(r[2],r[3])*83*scale)
		g.hotspot("maparea_"+id,"前往"+Home.room_name(id),bounds,func():g.change_room(id,true))
	for i in range(Home.ROOM_IDS.size()):
		var id=Home.ROOM_IDS[i]
		var labels=[]
		for member in Home.members(g.model.s.home.preset,id): labels.append(Home.NAMES[member])
		g.button("map_"+id,Home.room_name(id)+"  ·  "+("无人" if labels.is_empty() else "、".join(labels)),Rect2(970,163+i*77,490,65),func():g.change_room(id,true),false,"primary" if id==g.model.s.home.room else "neutral")
	g.button("back","返回房间",Rect2(1200,747,260,57),func():g.navigate("base"))

func squad() -> void:
	g.text("五人小队",Rect2(48,35,600,60),38)
	g.text("积分 %d  /  合金 %d  /  核心 %d"%[g.model.s.credits,g.model.s.alloy,g.model.s.cores],Rect2(790,42,740,52),24,g.GOLD)
	for i in range(5):
		var x=45+i*307
		var p=g.model.s.people[i]
		g.panel(Rect2(x,145,282,567),"card")
		g.picture(C.portrait(i),Rect2(x+15,163,252,280),true)
		g.text(C.PEOPLE[i].name,Rect2(x+20,460,245,48),29)
		g.text("Lv.%d  ·  %s\n%s\n%s"%[p.level,C.PEOPLE[i].role,C.SUITS[p.suit-1].name,g.model.stats(i).weapon],Rect2(x+20,516,245,123),21,g.MUTED)
		g.button("member%d"%i,"成长与穿戴",Rect2(x+12,646,258,53),func():g.selected=i;g.navigate("growth"))
	g.button("back","返回房间",Rect2(1270,801,275,58),func():g.navigate("base"))
	g.button("equipment","装备与战利品",Rect2(50,801,300,58),func():g.open_equipment("squad"),false,"primary")
	g.button("support","支援装置",Rect2(375,801,250,58),func():g.navigate("support"))
	g.text("所有人返回后恢复状态；衣服和武器按整套穿戴。",Rect2(50,756,1100,70),23)

func dialogue() -> void:
	room_backdrop()
	var id=g.dialogue_id
	g.panel(Rect2(40,665,1520,205))
	g.speaker_portrait(id,Rect2(62,687,145,145))
	g.text(Home.NAMES[id],Rect2(234,676,1150,45),27,g.GOLD)
	var lines=Home.LINES[id]
	g.text(lines[g.model.s.home.visits%lines.size()],Rect2(234,727,1070,88),26)
	g.button("back","收起对话",Rect2(1330,802,195,49),func():g.navigate("base"))
	if id!="xuan":
		g.button("person_detail","查看成长",Rect2(1330,733,195,50),func():g.selected=person_index(id);g.navigate("growth"))

func person_index(id: String) -> int:
	for i in range(C.PEOPLE.size()):
		if C.PEOPLE[i].id==id:return i
	return 0

func printer() -> void:
	g.panel(Rect2(235,145,1130,595))
	g.text("通体打印舱",Rect2(285,180,1000,70),39)
	g.text("制造完整战斗套装，或扩建空间以开放更高等级。",Rect2(285,274,1000,78),27,g.MUTED)
	g.button("suits","制造战斗套装",Rect2(310,406,475,88),func():g.navigate("suits"),false,"primary")
	g.button("room","升级主神空间",Rect2(815,406,475,88),func():g.navigate("room"))
	g.button("back","返回工作间",Rect2(1020,629,270,58),func():g.navigate("base"))

func collection() -> void:
	g.panel(Rect2(55,62,1490,799))
	g.text("异常收集阵",Rect2(95,87,750,61),38)
	g.text("已肃清 %d / %d 个任务"%[g.model.s.wins.size(),C.STAGE_COUNT],Rect2(960,93,530,48),25,g.GOLD)
	for i in range(mini(10,C.STAGE_COUNT-g.collection_page*10)):
		var stage=g.collection_page*10+i+1
		var m=C.mission(stage)
		var wins=int(g.model.s.wins.get(str(stage),0))
		var label="已收录 · %d 次肃清"%wins if wins>0 else ("可挑战" if C.stage_unlocked(stage,g.model.s.max_stage) else "尚未开放")
		g.button("collection%d"%stage,"%03d · %s\n%s"%[stage,m.name,label],Rect2(93+(i%2)*730,175+int(i/2)*103,700,89),func():g.deploy(stage),not C.stage_unlocked(stage,g.model.s.max_stage),"primary" if wins>0 else "neutral")
	g.button("previous_page","上一组",Rect2(96,737,190,59),func():g.collection_page-=1;g.draw_view(),g.collection_page==0)
	g.button("next_page","下一组",Rect2(304,737,190,59),func():g.collection_page+=1;g.draw_view(),g.collection_page==int((C.STAGE_COUNT-1)/10))
	g.button("support","异常支援",Rect2(658,737,260,59),func():g.navigate("support"))
	g.button("back","返回工作间",Rect2(1210,737,270,59),func():g.navigate("base"))
