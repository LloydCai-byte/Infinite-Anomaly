extends RefCounted
## Physical room controls; opening these views never owns the exploration clock.
const ASSETS = "res://assets/continuity/companion/"
var game: Control
var last_pose = ""
var last_shot = ""

func _init(host: Control) -> void:
	game = host

func draw() -> void:
	last_pose = ""
	last_shot = ""
	match game.model.s.room:
		"bedroom":
			last_pose = game.model.companion_pose()
			game.image(game.content,ASSETS+last_pose+".png",Rect2(0,0,1920,1080)).name = "FullScene"
			game.add_spot("Heroine","和她说句话",Rect2(480,255,430,680),func(): game.perform("talk"))
			game.add_spot("Radio","转动收音机旋钮",Rect2(195,555,135,110),show_radio)
			game.add_spot("Timer","看看桌上计时器",Rect2(342,585,61,70),show_timer)
			game.add_spot("BackEntry","回到玄关",Rect2(1500,140,355,765),func(): game.perform("room_entry"))
			var display = game.text(game.content,"25:00",Rect2(351,604,41,22),12,Color("dae2cf"))
			display.name = "ClockFace"
			display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		"peephole":
			game.panel(game.content,Rect2(0,0,1920,1080),Color("ede6d8"))
			game.image(game.content,ASSETS+"peephole.png",Rect2(960,0,960,1080)).name = "FullScene"
			game.text(game.content,"门外",Rect2(48,34,780,50),27,game.INK)
			# One authored image per step, framed like a manga panel, with no random claim.
			game.panel(game.content,Rect2(33,144,894,515),Color("141918"))
			game.image(game.content,game.model.story.nodes[game.model.idle_node_id()].image,Rect2(42,153,876,497)).name = "IdleShot"
			game.text(game.content,"",Rect2(48,708,825,130),30,game.INK).name = "IdleLine"
			game.text(game.content,"",Rect2(48,877,825,60),22,Color("535e57")).name = "IdleProgress"
			game.button(game.content,"LeavePeephole","离开猫眼",Rect2(54,947,250,60),func(): game.perform("room_entry"),true)
		_:
			game.image(game.content,ASSETS+"entry.png",Rect2(0,0,1920,1080)).name = "FullScene"
			game.add_spot("Depart","转动门把手",Rect2(1060,403,285,375),show_dispatch)
			game.add_spot("Collection","打开柜子",Rect2(610,405,355,375),game.show_collection)
			game.add_spot("Peephole","透过猫眼看看",Rect2(1163,259,85,93),func():
				if game.model.s.idle.active:
					game.perform("peek")
				else:
					game.notify_player("门外很安静。探索开始后，再来看看。"))
			game.add_spot("Delivery","打开收货箱",Rect2(1680,695,232,255),show_delivery)
			game.button(game.content,"ToBedroom","↶",Rect2(32,790,70,75),func(): game.perform("room_bedroom"))
			game.content.get_node("ToBedroom").tooltip_text = "转身去卧室"
			game.text(game.content,"",Rect2(1720,855,150,38),22,Color("dfe4cb")).name = "BoxTag"
	refresh()

func refresh() -> void:
	if not is_instance_valid(game.content) or game.model.s.mode not in ["home","reward"]:
		return
	var state: Dictionary = game.model.s
	if state.room == "bedroom":
		var pose = game.model.companion_pose()
		if last_pose != pose:
			var scene = game.content.get_node_or_null("FullScene")
			if scene is TextureRect:
				scene.texture = load(ASSETS+pose+".png")
			last_pose = pose
		set_label("ClockFace",clock_text())
	elif state.room == "peephole":
		var id = game.model.idle_node_id()
		if id != last_shot:
			var shot = game.content.get_node_or_null("IdleShot")
			if shot is TextureRect:
				shot.texture = load(game.model.story.nodes[id].image)
			last_shot = id
		set_label("IdleLine",game.model.story.nodes[id].line)
		set_label("IdleProgress","第 %d 趟　·　%02d / %02d 秒%s" % [state.idle.next_round,int(state.idle.elapsed),int(game.model.round_seconds()),"　·　这趟结束后回家" if state.idle.stop_after else ""])
	else:
		set_label("BoxTag","%d 趟已送达" % state.box_rounds if state.box_rounds > 0 else "")
	if game.modal == "delivery":
		refresh_delivery()
	elif game.modal == "timer":
		set_label("TimerDigits",clock_text(),true)
		set_label("TimerPhase",("专注" if state.pomo.phase == "focus" else "休息") + "　·　已完成 %d 段" % state.pomo.completed,true)
	elif game.modal == "dispatch":
		set_label("DispatchStatus",dispatch_status(),true)

func set_label(id: String, value: String, modal: bool = false) -> void:
	var node = (game.modal_layer if modal else game.content).find_child(id,true,false)
	if node is Label:
		node.text = value

func clock_text() -> String:
	var seconds = int(ceil(game.model.s.pomo.remaining))
	return "%02d:%02d" % [seconds / 60,seconds % 60]

func dispatch_status() -> String:
	var task: Dictionary = game.model.s.idle
	if not task.active:
		return "这条路已经走通过了。可以让他再去一趟。"
	return "第 %d 趟　·　还剩 %d 秒%s" % [task.next_round,int(ceil(game.model.round_seconds()-task.elapsed)),"\n这趟结束后，他就回来。" if task.stop_after else "\n每趟结束后继续，东西直接送进家里的箱子。"]

func sheet(id: String, title: String) -> Panel:
	game.open_modal(id,Color(0.035,0.045,0.04,0.63))
	var body = game.panel(game.modal_layer,Rect2(545,184,830,720),game.PAPER,Color("676e64"),8)
	game.text(body,title,Rect2(40,30,710,66),34,game.INK)
	game.button(body,"CloseHomePanel","×",Rect2(731,26,55,52),game.close_modal,true)
	return body

func show_dispatch() -> void:
	if not game.model.s.cards.has("stair"):
		game.perform("depart")
		return
	var body = sheet("dispatch","不存在的楼层")
	game.text(body,dispatch_status(),Rect2(40,132,748,140),25,game.INK).name = "DispatchStatus"
	if game.model.s.idle.active:
		game.button(body,"WatchAuto","看看猫眼",Rect2(40,317,748,74),func(): game.perform("peek"),true)
		var recall = game.button(body,"Recall","这趟结束后回家",Rect2(40,409,748,74),func():
			game.perform("recall")
			if game.fault == "":
				show_dispatch(),true)
		recall.disabled = game.model.s.idle.stop_after
	else:
		game.button(body,"StartAuto","让他继续探索",Rect2(40,317,748,74),func(): game.perform("start_auto"),true)
		game.button(body,"Replay","亲自再走一遍",Rect2(40,409,748,74),func(): game.perform("depart"),true)
	game.text(body,"关掉这个窗口，可以在家里走动。\n按 Esc 暂停；退出游戏后，这一趟留到下次继续。",Rect2(40,558,748,100),22,Color("616a61"))

func show_delivery() -> void:
	var body = sheet("delivery","收货箱")
	game.text(body,"",Rect2(40,118,738,75),24,game.INK).name = "DeliveryStatus"
	game.text(body,"",Rect2(40,222,738,130),28,game.INK).name = "DeliveryItems"
	game.text(body,"",Rect2(40,410,738,110),22,Color("59655d")).name = "BagItems"
	game.button(body,"Claim","把东西收好",Rect2(40,571,748,75),func():
		game.perform("claim")
		if game.fault == "":
			show_delivery(),true)
	refresh_delivery()

func item_text(items: Dictionary) -> String:
	var lines = PackedStringArray()
	for id in game.model.idle_config.items:
		if items.has(id):
			lines.append("%s × %d" % [game.model.idle_config.items[id].name,items[id]])
	return "\n".join(lines)

func refresh_delivery() -> void:
	var state: Dictionary = game.model.s
	set_label("DeliveryStatus","%d 趟的东西已经送到家里。" % state.box_rounds if state.box_rounds > 0 else "箱子里暂时没有新东西。",true)
	set_label("DeliveryItems",item_text(state.inbox),true)
	set_label("BagItems","已经收好：\n" + (item_text(state.bag) if not state.bag.is_empty() else "还没有。"),true)
	var claim = game.modal_layer.find_child("Claim",true,false)
	if claim is Button:
		claim.disabled = state.inbox.is_empty()

func show_radio() -> void:
	var body = sheet("radio","桌上的收音机")
	game.text(body,"窗边的慢拍",Rect2(40,148,738,75),30,game.INK)
	game.text(body,"没有人声，轻一点就好。",Rect2(40,218,738,65),24,Color("626c62"))
	game.button(body,"MusicToggle","音乐：" + ("播放中" if game.model.s.music_on else "已关"),Rect2(40,324,748,75),func():
		game.perform("music")
		if game.fault == "":
			show_radio(),true)
	game.button(body,"AmbienceToggle","环境声：" + ("开" if game.model.s.ambience_on else "关"),Rect2(40,425,748,75),func():
		game.perform("ambience")
		if game.fault == "":
			show_radio(),true)
	game.text(body,"转身去看看箱子也没关系，音乐会继续。",Rect2(40,578,748,74),22,Color("626c62"))

func show_timer() -> void:
	var body = sheet("timer","桌上的计时器")
	var digits = game.text(body,clock_text(),Rect2(40,115,748,114),76,game.INK)
	digits.name = "TimerDigits"
	digits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game.text(body,"",Rect2(40,234,748,59),23,game.INK).name = "TimerPhase"
	game.button(body,"PomoToggle","暂停计时" if game.model.s.pomo.running else "开始计时",Rect2(40,327,748,69),func(): timer_action("pomo_toggle"),true)
	game.button(body,"Pomo5","5 分钟",Rect2(40,420,355,60),func(): timer_action("pomo_5"),true)
	game.button(body,"Pomo25","25 分钟",Rect2(422,420,366,60),func(): timer_action("pomo_25"),true)
	game.button(body,"PomoReset","重新开始这一段",Rect2(40,502,748,60),func(): timer_action("pomo_reset"),true)
	game.text(body,"专注后休息 5 分钟，再自动开始下一段。\n计时器与门外探索各自运行。",Rect2(40,602,748,90),21,Color("626c62"))
	refresh()

func timer_action(action: String) -> void:
	game.perform(action)
	if game.fault == "":
		show_timer()
