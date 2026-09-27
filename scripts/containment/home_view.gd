extends RefCounted
var game: Control
var last_shot = ""
const ROOMS = {
	"entry":["玄关 · 门","res://assets/continuity/companion/entry.png"],
	"entry_wall":["玄关 · 收藏墙","res://assets/home/hall.png"],
	"hall":["过道 · 房门","res://assets/home/hall.png"],
	"hall_table":["过道 · 休息处","res://assets/home/hall.png"],
	"bedroom":["卧室 · 床","res://assets/home/bedroom.png"],
	"desk":["卧室 · 书桌","res://assets/home/desk.png"],
	"kitchen":["厨房 · 灶台","res://assets/home/kitchen.png"],
	"kitchen_table":["厨房 · 操作台","res://assets/home/kitchen.png"],
	"bathroom":["卫生间 · 淋浴处","res://assets/home/bathroom.png"],
	"bathroom_laundry":["卫生间 · 洗衣处","res://assets/home/bathroom.png"],
	"balcony":["阳台 · 窗边","res://assets/home/balcony.png"],
	"balcony_sky":["阳台 · 星空","res://assets/home/balcony.png"]}

func _init(host: Control) -> void:
	game = host

func draw() -> void:
	var state: Dictionary = game.model.s
	last_shot = ""
	if state.room == "peephole":
		draw_peephole()
		return
	var info: Array = ROOMS.get(state.room,ROOMS.entry)
	var path: String = info[1]
	var replacement = "res://assets/containment/rooms/"+state.room+".png"
	if ResourceLoader.exists(replacement): path = replacement
	var seated = state.room == "bedroom" and game.model.companion_room() == "bedroom"
	if seated:
		path = "res://assets/continuity/companion/"+("reading" if int(state.companion_time/15)%2 == 0 else "tea")+".png"
	game.image(game.content,path,Rect2(0,0,1920,1080)).name = "FullScene"
	game.panel(game.content,Rect2(30,25,410,68),Color(0.07,0.08,0.08,0.85))
	game.text(game.content,info[0],Rect2(48,35,380,55),25)
	if state.room == "entry":
		game.add_spot("Depart","转动门把手",Rect2(1075,475,270,310),game.ui.door)
		game.add_spot("LockDoor","反锁／解锁",Rect2(1120,365,130,110),func(): game.perform("lock"))
		game.add_spot("Collection","查看收藏",Rect2(610,340,355,400),func(): game.ui.collection())
		game.add_spot("Peephole","看看门外",Rect2(1150,245,120,115),func():
			if state.idle.active: game.perform("peek")
			else: game.notify_player("男主出门继续收容后，可以在这里看见他的进度。"))
		game.add_spot("Delivery","打开收货箱",Rect2(1640,640,260,255),game.ui.delivery)
		game.text(game.content,"%d 件待收" % item_count(state.inbox),Rect2(1650,836,240,40),23).name = "BoxTag"
	elif state.room == "entry_wall":
		var board = game.panel(game.content,Rect2(400,165,860,500),Color("d5cbbb"),Color("46483e"),10)
		game.text(board,"收容记录",Rect2(35,20,730,60),29,game.INK)
		for index in range(30):
			var entry: Dictionary = game.model.catalog[index]
			var owned = state.cards.has(entry.id)
			var b = game.button(board,"Wall_"+entry.id,"%02d" % (index+1),Rect2(35+(index/5)*132,100+(index%5)*72,112,58),func(): game.ui.card_detail(entry.id),owned)
			if game.model.tier(entry.id) in ["gold","shiny"]:
				b.modulate = Color("f8d37c")
	elif state.room == "desk":
		game.add_spot("Workbench","收容夹 · 整理与分解物品",Rect2(895,535,140,150),game.ui.workshop)
		game.add_spot("Abilities","笔记本 · 查看能力记录",Rect2(760,515,180,190),game.ui.skills)
		game.add_spot("ComputerMusic","电脑 · 音乐与环境声",Rect2(280,260,420,250),game.ui.radio)
		game.add_spot("DeskBalcony","走到阳台",Rect2(1210,200,540,440),func(): game.perform("room_balcony"))
	elif state.room == "bedroom":
		game.add_spot("Timer","专注计时器",Rect2(335,570,90,95),game.ui.timer)
		game.add_spot("Radio","收音机",Rect2(160,545,170,120),game.ui.radio)
		game.add_spot("BedRest","在床边休息",Rect2(930,520,600,330),func(): game.notify_player("这里很安全。随时可以暂停，或者开着音乐坐一会儿。"))
	elif state.room.begins_with("kitchen"):
		game.add_spot("KitchenTalk","看看准备好的餐食",Rect2(550,470,580,370),func(): game.notify_player("她留了一份热饭。吃饭不会消耗资源，也没有饥饿倒计时。"))
	elif state.room.begins_with("bathroom"):
		game.add_spot("Laundry","看看洗好的衣服",Rect2(220,430,390,245) if state.room == "bathroom_laundry" else Rect2(560,475,260,360),func(): game.notify_player("换下的衣服已经洗好。她把袖口仔细抚平了。"))
	elif state.room.begins_with("balcony"):
		game.add_spot("Sky","看一会儿窗外",Rect2(550,120,820,600),func(): game.notify_player("夜色很安静。屋里的音乐还在继续。"))
	else:
		if state.room == "hall_table":
			game.add_spot("HallRadio","听音乐",Rect2(380,555,135,125),game.ui.radio)
	if state.room == game.model.companion_room() or state.mode in ["reward","ending"]:
		if seated: game.add_spot("Heroine","和她聊聊，或者一起想想线索",Rect2(475,250,425,640),game.ui.companion)
		else: draw_companion()
	var ids: Array = game.model.room_ids()
	var index = ids.find(state.room)
	var other: String = ids[index+1 if index%2 == 0 else index-1]
	game.button(game.content,"TurnRoom","转身 · "+ROOMS[other][0],Rect2(60,808,430,66),func(): game.perform("room_"+other))
	game.button(game.content,"ToHall","前往过道",Rect2(60,724,250,62),func(): game.perform("room_hall"))
	if state.room in ["hall","hall_table"]:
		game.add_spot("ToBedroom","进入卧室",Rect2(110,180,430,530),func(): game.perform("room_bedroom"))
		game.add_spot("ToKitchen","进入厨房",Rect2(1460,180,390,540),func(): game.perform("room_kitchen"))
		game.button(game.content,"ToEntry","走回玄关",Rect2(60,642,250,62),func(): game.perform("room_entry"))
		game.button(game.content,"ToBathroom","走向卫生间",Rect2(330,642,250,62),func(): game.perform("room_bathroom"))

func draw_companion() -> void:
	var x = 1170 if game.model.s.room in ["hall_table","bathroom_laundry","balcony_sky"] else 565
	var y = 320 if game.model.s.room in ["bathroom_laundry","balcony_sky"] else 210
	var height = 740 if y == 320 else 690
	if game.model.s.room == "kitchen":
		x = 765
		y = 260
		height = 800
	var portrait = game.image(game.content,"res://assets/containment/heroine.png",Rect2(x,y,465,height))
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.name = "Companion"
	portrait.pivot_offset = Vector2(232,height)
	var tween = portrait.create_tween().set_loops()
	tween.tween_property(portrait,"scale",Vector2(1.0,1.006),2.4).set_trans(Tween.TRANS_SINE)
	tween.tween_property(portrait,"scale",Vector2.ONE,2.4).set_trans(Tween.TRANS_SINE)
	game.add_spot("Heroine","和她聊聊，或者一起想想线索",Rect2(x+50,y+25,365,minf(height-25,900-y)),game.ui.companion)

func draw_peephole() -> void:
	game.panel(game.content,Rect2(0,0,1920,916),game.PAPER)
	game.image(game.content,"res://assets/containment/peephole-back.png",Rect2(960,0,960,916))
	game.text(game.content,"门外的收容记录",Rect2(45,34,780,55),29,game.INK)
	game.image(game.content,game.model.story.nodes[game.model.idle_node_id()].image,Rect2(40,145,880,498)).name = "IdleShot"
	game.text(game.content,"",Rect2(45,674,865,155),25,game.INK).name = "IdleLine"
	game.text(game.content,"",Rect2(45,838,865,45),22,game.INK).name = "IdleProgress"
	game.button(game.content,"LeavePeephole","离开猫眼",Rect2(1490,816,325,63),func(): game.perform("room_entry"))
	refresh()

func item_count(items: Dictionary) -> int:
	var total = 0
	for count in items.values(): total += int(count)
	return total

func refresh() -> void:
	if game.model.s.mode != "home": return
	if game.model.s.room == "peephole":
		var id = game.model.idle_node_id()
		var shot = game.content.get_node_or_null("IdleShot")
		if shot != null and last_shot != id:
			shot.texture = load(game.model.story.nodes[id].image)
			last_shot = id
		var line = game.content.get_node_or_null("IdleLine")
		if line: line.text = game.model.sample_description()
		var progress = game.content.get_node_or_null("IdleProgress")
		if progress: progress.text = "本轮 %02d / %02d 秒　·　已送回 %d 趟" % [game.model.s.idle.elapsed,game.model.round_seconds(),game.model.s.idle.settled]
	var tag = game.content.get_node_or_null("BoxTag")
	if tag: tag.text = "%d 件待收" % item_count(game.model.s.inbox)
