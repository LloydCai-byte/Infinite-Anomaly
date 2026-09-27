extends RefCounted
var game: Control
var selected_card = ""
var card_filter = "all"
var ending_page = 0
var panel_scroll = 0

func _init(host: Control) -> void:
	game = host

func sheet(id: String, title: String, wide: bool = false, closable: bool = true) -> Panel:
	game.open_modal(id)
	var width = 1600 if wide else 1060
	var body = game.panel(game.modal_layer,Rect2((1920-width)/2,100,width,870),game.PAPER,Color("818677"),12)
	game.text(body,title,Rect2(42,26,width-150, sixty()),33,game.INK)
	if closable:
		game.button(body,"ClosePanel","×",Rect2(width-90,24,52,52),func():
			if game.model.s.mode == "dead": death_screen()
			elif game.model.s.mode == "reward": collection(true)
			else: game.close_modal(),true)
	return body

func sixty() -> int:
	return 60

func info(parent: Node, value: String, area: Rect2, size: int = 24) -> Label:
	return game.text(parent,value,area,size,game.INK)

func action(parent: Node, id: String, title: String, area: Rect2, callback: Callable, disabled: bool = false) -> Button:
	var b = game.button(parent,id,title,area,callback,true)
	b.disabled = disabled
	b.add_theme_color_override("font_disabled_color",Color("89877d"))
	return b

func title_screen() -> void:
	game.open_modal("title",Color(0.035,0.045,0.043,0.87))
	game.text(game.modal_layer,"无限异常",Rect2(160,220,900,125),76)
	game.text(game.modal_layer,"门外，寻找异常。\n门内，有人等你回家。",Rect2(169,379,780,140),30)
	game.button(game.modal_layer,"LoadSlots","进入记录",Rect2(170,600,440,78),slots)
	game.button(game.modal_layer,"ExitTitle","退出",Rect2(170,703,440,66),game.quit_safely)
	game.text(game.modal_layer,"三十类收容 · 功能完整体验版",Rect2(169,899,1080,55),23,Color("bbc3b8"))

func slots() -> void:
	var body = sheet("slots","选择记录",true,false)
	for index in range(3):
		var number = index+1
		var storage = game.slot_store(number)
		var saved = storage.load_primary()
		var checker = game.Model.new()
		if not checker.restore(saved):
			saved = storage.load_backup()
		var valid = checker.restore(saved)
		var y = 125+index*207
		info(body,"记录 %d" % number,Rect2(45,y,240,48),29)
		info(body,"收容 %d / 30　金色 %d　闪光 %d\n%s" % [checker.counts().owned,checker.counts().gold,checker.counts().shiny,"探索中" if checker.s.mode == "story" else "在家"] if valid else ("记录损坏，原文件将保留" if storage.exists() else "空白记录"),Rect2(310,y,690,110),25)
		action(body,"ContinueSlot%d"%number,"继续",Rect2(1040,y,200,65),func(): game.load_slot(number),not valid)
		action(body,"NewSlot%d"%number,"重新开始" if storage.exists() else "开始",Rect2(1270,y,250,65),func():
			if storage.exists(): confirm_new(number)
			else: game.load_slot(number,true))
	info(body,"不同记录互相独立。每次操作自动保存，并保留最近一次有效备份。",Rect2(45,763,1320,65),23)
	action(body,"BackTitle","返回",Rect2(1320,768,195,60),title_screen)

func confirm_new(number: int) -> void:
	var body = sheet("slots","重新开始记录 %d"%number,false,false)
	info(body,"现有记录会先另存为备份，再创建一个新记录。\n其他记录与旧版本存档不受影响。",Rect2(48,190,940,165),28)
	action(body,"ConfirmNew","备份并开始",Rect2(50,440,950,78),func(): game.load_slot(number,true))
	action(body,"CancelNew","返回记录选择",Rect2(50,550,950,72),slots)

func pause_screen() -> void:
	if game.modal in ["death","reward","ending","title","slots","fault"]: return
	game.model.s.paused = true
	if not game.save_progress():
		show_fault()
		return
	var body = sheet("pause","暂停",false,false)
	info(body,"收容与专注计时已暂停。",Rect2(48,110,950,60),25)
	action(body,"Resume","继续",Rect2(50,210,960,75),game.close_modal)
	action(body,"Settings","声音与显示",Rect2(50,307,960,75),settings)
	action(body,"Guide","玩法说明",Rect2(50,404,960,75),guide)
	action(body,"BackToTitle","保存并返回标题",Rect2(50,501,960,75),func():
		game.model.s.paused = false
		if game.save_progress(): title_screen()
		else: show_fault())
	action(body,"Quit","保存并退出",Rect2(50,598,960,75),func():
		game.model.s.paused = false
		game.quit_safely())
	info(body,"后台运行正常继续。启用离线收容时，关闭游戏后最多结算八小时；达到闪光会自动结束。",Rect2(50,720,950,105),22)

func settings() -> void:
	var body = sheet("settings","声音与显示")
	info(body,"音乐音量",Rect2(48,134,245,50))
	info(body,"环境与音效",Rect2(48,225,245,50))
	for entry in [["music_volume",151],["sound_volume",242]]:
		var key: String = entry[0]
		var slider = HSlider.new()
		game.place(slider,body,Rect2(315,entry[1],670,38))
		slider.min_value = 0
		slider.max_value = 1
		slider.step = 0.05
		slider.value = game.model.s[key]
		slider.value_changed.connect(func(value):
			game.model.s[key] = value
			game.apply_mute())
		slider.drag_ended.connect(func(_changed): persist())
	action(body,"ToggleMute","声音："+("静音" if game.model.s.muted else "开启"),Rect2(48,330,465,70),func():
		game.model.s.muted = not game.model.s.muted
		game.apply_mute()
		persist()
		if game.fault == "": settings())
	action(body,"ToggleHints","交互提示："+("开启" if game.model.s.show_hints else "关闭"),Rect2(533,330,470,70),func():
		game.model.s.show_hints = not game.model.s.show_hints
		for spot in game.spots:
			spot.reveal = game.model.s.show_hints
			spot.queue_redraw()
		persist()
		if game.fault == "": settings())
	action(body,"ToggleOffline","离线收容："+("开启" if game.model.s.offline_on else "关闭"),Rect2(48,429,955,70),func():
		game.model.s.offline_on = not game.model.s.offline_on
		persist()
		if game.fault == "": settings())
	action(body,"FullScreen","切换全屏 / 窗口",Rect2(48,527,955,70),func(): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN))
	info(body,"番茄钟只统计游戏运行时的专注。\n窗口失焦不会暂停；按 Esc 才暂停。",Rect2(48,650,950,100),23)

func persist() -> void:
	if not game.save_progress():
		game.model.restore(game.last_committed)
		show_fault()

func guide() -> void:
	var body = sheet("settings","怎样继续")
	info(body,"调查：点击场景物件，选择行动，记录线索。\n收容：验证目标后打开收容夹；每次尝试只有一次机会。\n回溯：从时间线选择已到达节点，保留成长与已知线索，恢复当时的剧情状态。\n换路：在家反锁门，再解锁，换一个未收容故事。\n挂机：点击墙上已收容的类型，每轮送回记录与物品。\n成长：收货后到书桌分解，使用不同能力点升级。\n完成：类型过半变金，全部完成变闪；全金可进入假结局，全闪进入最终揭秘。",Rect2(48,130,945,640),27)

func floor_plan() -> void:
	var body = sheet("map","家里的房间",true)
	var room_pairs = [["玄关","entry","entry_wall",Rect2(55,435,405,230)],["过道","hall","hall_table",Rect2(520,395,440,270)],["卧室","bedroom","desk",Rect2(520,130,440,225)],["厨房","kitchen","kitchen_table",Rect2(1020,130,520,225)],["卫生间","bathroom","bathroom_laundry",Rect2(1020,435,520,230)],["阳台","balcony","balcony_sky",Rect2(55,130,405,225)]]
	for points in [[Vector2(460,240),Vector2(520,240)],[Vector2(740,355),Vector2(740,395)],[Vector2(460,550),Vector2(520,550)],[Vector2(960,550),Vector2(1020,550)],[Vector2(960,420),Vector2(990,420),Vector2(990,240),Vector2(1020,240)]]:
		var connector = Line2D.new()
		connector.points = PackedVector2Array(points)
		connector.width = 8
		connector.default_color = Color("8d9587")
		body.add_child(connector)
	for i in range(6):
		var pair: Array = room_pairs[i]
		var area: Rect2 = pair[3]
		var here = game.model.s.room in [pair[1],pair[2]]
		var tile = game.panel(body,area,Color("d1dbc9") if here else Color("ded8cb"),Color("657560") if here else Color("969b8b"),4)
		info(tile,pair[0]+(" · 当前位置" if here else ""),Rect2(22,12,area.size.x-44,46),27)
		for j in range(2):
			var id: String = pair[j+1]
			var title: String = game.home_view.ROOMS[id][0].split(" · ")[1]
			if game.model.companion_room() == id: title += " · 她在这里"
			if game.model.s.room == id: title += " ✓"
			action(tile,"Map_"+id,title,Rect2(20,73+j*70,area.size.x-40,58),func(): game.perform("room_"+id))
	info(body,"点击房内点位前往。连线表示通路；她会在家里活动。",Rect2(55,741,1480,64),24)

func door() -> void:
	var body = sheet("door","门外")
	var state: Dictionary = game.model.s
	if state.idle.active:
		info(body,"他正在处理「%s」。\n本轮剩余 %d 秒。"%[game.model.by_id[state.idle.case_id].name,ceil(game.model.round_seconds()-state.idle.elapsed)],Rect2(48,130,960,160),28)
		action(body,"WatchAuto","去猫眼看看",Rect2(48,343,960,76),func(): game.perform("peek"))
		action(body,"Recall","这一趟结束后回家",Rect2(48,446,960,76),func(): game.perform("recall"),state.idle.stop_after)
	else:
		var door_line = "门后仍是调查 %02d。\n可以继续，也可以先换一条路。"%game.model.current_case().index
		if state.cards.has(state.case_id): door_line = "门后传来新的动静。\n打开门，调查下一个异常。"
		if state.cards.size()==30: door_line = "门外出现了新的路。"
		info(body,"门已经反锁。" if state.locked else door_line,Rect2(48,130,960,160),28)
		action(body,"EnterStory","打开门",Rect2(48,343,960,76),func(): game.perform("depart"),state.locked)
		action(body,"LockToggle","解锁，切换门外的异常" if state.locked else "反锁门",Rect2(48,446,960,76),func(): game.perform("lock"))
		action(body,"ResumeTimeline","从已到达的时间点继续",Rect2(48,549,960,76),timeline,state.cases[state.case_id].checkpoints.is_empty() or state.locked)
	info(body,"新异常从这里进入；重复收容请点击墙上的对应记录。",Rect2(48,731,960,72),23)

func choices(data: Dictionary) -> void:
	var body = sheet("choices",data.title)
	var y = 125
	for option in data.choices:
		var title: String = option.label
		var allowed = game.model.available(option)
		if option.has("stat"):
			var stat = game.model.stat_id(option)
			var need = game.model.requirement(option)
			title += "\n%s %d / %d%s"%[game.model.balance.skills[stat].name,game.model.s.skills[stat],need," · 还差 %d"%(need-game.model.s.skills[stat]) if not allowed else ""]
		action(body,option.id,title,Rect2(48,y,960,118),func(): game.perform(option.id),not allowed)
		y += 145

func notebook() -> void:
	var body = sheet("notebook","调查记录 %02d"%game.model.current_case().index,true)
	var lines = PackedStringArray()
	for id in game.model.s.cases[game.model.s.case_id].knowledge:
		lines.append(("● 本轮已确认　" if game.model.s.flags.has(id) else "○ 记得这条线索　")+game.model.story.evidence[id])
	info(body,"\n\n".join(lines) if not lines.is_empty() else "还没有记录。先观察场景里的物件与人物。",Rect2(50,124,1470,570),26)
	info(body,"回溯保留记忆，但会恢复当时的调查状态。收容前需要在本轮完成验证。",Rect2(50,750,1470,70),23)

func timeline() -> void:
	var body = sheet("timeline","已经走过的时间点",true)
	var record: Dictionary = game.model.s.cases[game.model.s.case_id]
	var i = 0
	for id in game.model.story.nodes:
		if id == "threshold": continue
		var available = record.checkpoints.has(id)
		var title = game.model.story.nodes[id].name if available else "尚未到达"
		if available:
			title = "%02d  %s\n%d 条当时线索"%[i+1,title,record.checkpoints[id].flags.size()]
		action(body,"Checkpoint_"+id,title,Rect2(48+(i%3)*502,125+(i/3)*156,475,130),func(): game.perform("rewind:"+id),not available or game.model.tier(game.model.s.case_id)=="shiny")
		i += 1
	info(body,"只回到已到达的节点。能力和已收容类型保留；剧情状态恢复到该时点。\n已走过 %d 段分支连接。首次收容奖励不会重复发放。"%record.edges.size(),Rect2(48,655,1460,130),24)
	if game.model.s.mode == "dead":
		action(body,"TimelineHome","先回家",Rect2(1150,782,360,60),func(): game.perform("wake"))

func containment() -> void:
	var body = sheet("containment","收容夹 · 仅一次机会")
	var verified = game.model.verified()
	info(body,"现场验证完成。选择你认定的目标。" if verified else "现在还不能确定目标。\n结合纸背、脚步或划痕，先完成现场验证。",Rect2(48,120,955,110),26)
	var i = 0
	for option in game.model.story.judgments:
		action(body,"Target_"+option.id,option.name+"\n"+option.reason,Rect2(48,285+i*150,960,118),func(): confirm_containment(option),not verified or game.model.s.used)
		i += 1

func confirm_containment(option: Dictionary) -> void:
	var body = sheet("containment","最后确认")
	info(body,"收容目标：%s\n\n你的判断：%s\n\n夹片一旦闭合，本次机会即被消耗。"%[option.name,option.reason],Rect2(48,140,960,300),29)
	action(body,"ConfirmContain_"+option.id,"闭合收容夹",Rect2(48,510,960,85),func(): game.perform("contain:"+option.id))
	action(body,"Reconsider","重新考虑",Rect2(48,630,960,70),containment)

func death_screen() -> void:
	var body = sheet("death","这次没能回来",false,false)
	info(body,game.model.s.last_line,Rect2(50,150,950,240),30)
	action(body,"RewindDeath","选择时间点继续",Rect2(50,445,960,80),timeline)
	action(body,"Wake","先回到家里",Rect2(50,551,960,75),func(): game.perform("wake"))
	action(body,"ExitDeath","保存并退出",Rect2(50,657,960,70),game.quit_safely)

func collection(reward: bool = false) -> void:
	var total = game.model.counts()
	var body = sheet("reward" if reward else "collection","收容记录   %d / 30   ·   金色 %d   ·   闪光 %d"%[total.owned,total.gold,total.shiny],true,not reward)
	var index = 0
	for entry in game.model.catalog:
		var column = index / 5
		var row = index % 5
		if row == 0: info(body,entry.group,Rect2(40+column*257,91,235,38),21)
		var owned = game.model.s.cards.has(entry.id)
		var tier = game.model.tier(entry.id)
		var title = "%02d\n尚未识别"%entry.index
		if owned:
			title = "%s\n%d / %d　%s"%[entry.name,game.model.s.cards[entry.id].progress,entry.sample_total,{"normal":"记录中","gold":"金色","shiny":"闪光"}[tier]]
		var b = action(body,"Card_"+entry.id,title,Rect2(37+column*257,139+row*125,241,110),func(): card_detail(entry.id))
		b.add_theme_font_size_override("font_size",22)
		if tier == "gold": b.modulate = Color("eacb7b")
		if tier == "shiny":
			var foil = ShaderMaterial.new()
			foil.shader = load("res://scripts/containment/foil.gdshader")
			b.material = foil
		index += 1
	if reward:
		action(body,"PutAway","把记录留在墙上",Rect2(1135,778,422,62),func(): game.perform("put_away"))
		info(body,"首次收容收益已送进箱子。",Rect2(45,786,1000,55),23)
	else:
		info(body,"点击已收容类型继续收容。闪光意味着这一类型已经完成，入口会关闭。",Rect2(45,782,1460,62),23)

func card_detail(id: String) -> void:
	selected_card = id
	var entry: Dictionary = game.model.by_id[id]
	var owned = game.model.s.cards.has(id)
	var tier = game.model.tier(id)
	var reward = game.model.s.mode == "reward"
	var body = sheet("card","记录 %02d · %s"%[entry.index,entry.name if owned else "未识别"])
	game.image(body,game.model.story.nodes.landing.image,Rect2(48,121,426,302))
	info(body,"尚未收容。打开门，继续调查未知的异常。" if not owned else "%s\n进度 %d / %d\n%s"%[entry.name,game.model.s.cards[id].progress,entry.sample_total,{"normal":"同类样本仍在等待收容","gold":"已稳定大部分样本，资源收益降低","shiny":"样本记录完整，入口已关闭"}[tier]],Rect2(515,130,490,280),27)
	if owned:
		info(body,"每趟 %d 秒　·　主要带回：%s\n普通收益 3 份；金色收益 1 份。\n金色 %d / %d，闪光 %d / %d。"%[entry.round_seconds,game.model.balance.items[entry.item].name,ceil(entry.sample_total/2.0),entry.sample_total,entry.sample_total,entry.sample_total],Rect2(48,465,960,145),24)
		action(body,"StartAuto","继续收容同类异常",Rect2(48,643,960,70),func(): game.perform("auto:"+id),tier == "shiny" or game.model.s.idle.active or game.model.s.locked or reward)
		action(body,"ReplayStory","回顾首次调查",Rect2(48,733,466,66),func(): game.perform("replay:"+id),tier == "shiny" or game.model.s.idle.active or reward)
		action(body,"BackCollection","返回收藏",Rect2(539,733,470,66),func(): collection(reward))

func delivery() -> void:
	var body = sheet("delivery","门边的收货箱")
	info(body,"每轮收容后，物品直接送到家里。",Rect2(48,115,960,60))
	info(body,"",Rect2(48,210,960,345),29).name = "DeliveryItems"
	info(body,"",Rect2(48,580,960,65)).name = "DeliveryCount"
	action(body,"Claim","把物品收进背包",Rect2(48,688,960,79),func(): game.perform("claim"))
	refresh()

func item_lines(items: Dictionary) -> String:
	var lines = PackedStringArray()
	for id in items:
		lines.append("%s  × %d"%[game.model.balance.items[id].name,items[id]])
	return "\n".join(lines) if not lines.is_empty() else "暂时没有物品。"

func points_line(points: Dictionary) -> String:
	var parts = PackedStringArray()
	for id in points:
		parts.append("%s %d"%[game.model.balance.points[int(id)],points[id]])
	return "  ·  ".join(parts)

func workshop() -> void:
	var body = sheet("workshop","书桌 · 物品分解",true)
	info(body,points_line(game.model.s.points),Rect2(48,108,1500,62),24)
	var i = 0
	for id in game.model.balance.items:
		var spec: Dictionary = game.model.balance.items[id]
		var count = int(game.model.s.bag.get(id,0))
		var y = 194+i*84
		info(body,"%s × %d"%[spec.name,count],Rect2(48,y,380,55),25)
		info(body,"每份 → "+points_line(spec.recipe),Rect2(435,y,665,55),23)
		action(body,"DecomposeOne_"+id,"分解 1",Rect2(1100,y-5,184,62),func(): game.perform("decompose:"+id+":1"),count==0)
		action(body,"DecomposeAll_"+id,"全部",Rect2(1309,y-5,210,62),func(): game.perform("decompose:"+id+":"+str(count)),count==0)
		i += 1
	action(body,"DecomposeAll","按上述配方分解全部",Rect2(48,734,790,77),func(): game.perform("decompose_all"),game.model.s.bag.is_empty())
	action(body,"OpenSkills","查看能力",Rect2(872,734,650,77),skills)

func skills() -> void:
	var body = sheet("skills","能力记录",true)
	info(body,points_line(game.model.s.points),Rect2(48,108,1500,62),24)
	var i = 0
	for id in game.model.balance.skills:
		var spec: Dictionary = game.model.balance.skills[id]
		var y = 204+i*91
		info(body,"%s  %d"%[spec.name,game.model.s.skills[id]],Rect2(48,y,260,60),29)
		info(body,spec.description+"\n消耗："+points_line(game.model.cost(id)),Rect2(350,y-8,800,85),24)
		action(body,"Upgrade_"+id,"提升一级" if game.model.s.skills[id]<spec.cap else "已满级",Rect2(1210,y,310,66),func(): game.perform("upgrade:"+id),not game.model.can_upgrade(id))
		i += 1
	info(body,"能力开放额外的行动路线；初始能力也有完整的推理通关路径。",Rect2(48,785,1480,60),23)

func radio() -> void:
	var body = sheet("radio","收音机")
	info(body,"窗边的慢拍\n\n没有人声，轻一点就好。",Rect2(48,140,950,190),30)
	action(body,"MusicToggle","音乐："+("播放中" if game.model.s.music_on else "关闭"),Rect2(48,420,960,77),func(): game.perform("music"))
	action(body,"AmbienceToggle","环境声："+("开启" if game.model.s.ambience_on else "关闭"),Rect2(48,529,960,77),func(): game.perform("ambience"))

func timer() -> void:
	var body = sheet("timer","专注计时器")
	var digits = info(body,"",Rect2(48,129,960,128),78)
	digits.name = "TimerDigits"
	digits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info(body,"",Rect2(48,283,960,64),25).name = "TimerPhase"
	action(body,"PomoToggle","暂停计时" if game.model.s.pomo.running else "开始计时",Rect2(48,391,960,75),func(): game.perform("pomo_toggle"))
	for i in range(3):
		var duration = [5,25,50][i]
		action(body,"Pomo%d"%duration,"%d 分钟"%duration,Rect2(48+i*327,499,305,68),func(): game.perform("pomo_%d"%duration))
	action(body,"PomoReset","重新开始这一段",Rect2(48,608,960,69),func(): game.perform("pomo_reset"))
	info(body,"专注结束后休息 5 分钟，再开始下一段。计时与收容独立运行。",Rect2(48,741,960,75),23)
	refresh()

func companion() -> void:
	var body = sheet("companion","和她聊聊")
	info(body,game.model.companion_hint(),Rect2(48,145,960,260),29)
	action(body,"TalkClues","一起想想当前线索",Rect2(48,460,960,79),func():
		game.close_modal()
		game.perform("talk"))
	action(body,"TalkDaily","今天在做什么",Rect2(48,570,960,79),func():
		game.close_modal()
		var lines = {"bedroom":"这本书还有几页。你可以在旁边坐着。","kitchen":"刚做好饭。等你忙完，我们一起吃。","bathroom_laundry":"衣服洗好了。等晾干，我帮你收起来。","balcony_sky":"我在看星星。你觉得最亮的那一颗叫什么？","hall_table":"我给你留了一杯水。不用急着出门。"}
		game.draw_bubble({"text":lines.get(game.model.companion_room(),"我在这里。"),"rect":[930,205,650,210],"tail":[875,450]}))

func ending() -> void:
	var kind: String = game.model.s.ending_kind
	var data = {
		"blocked":["门还没有完全打开","三十种记录都已点亮，但仍有不稳定的部分。\n\n她看着墙上的卡片：先让每一种记录都变成金色，再试一次。"],
		"false":["一个可以停下来的地方","门外出现了普通的街道。你终于可以走进去。\n\n你得到了自己的生活，却还没有看见这些记录背后的全部真相。\n\n结局记录已保存。继续完成全部闪光卡，可以再次打开最后的门。"],
		"true":["最后一扇门","全部异常记录已经完成。\n\n你曾以为自己在修复一个原本存在的世界。那些收容记录，最终成为了你创造世界的条件。\n\n她仍会继续寻找更远的答案。你可以走进自己的生活。\n\n最终揭秘已解锁，结局记录已保存。"]}
	var body = sheet("ending",data[kind][0],true,false)
	info(body,data[kind][1],Rect2(85,167,1400,420),32)
	info(body,"当前结局文字为功能占位，正式剧情后续替换。",Rect2(85,625,1400,70),22)
	action(body,"EndingHome","回家，保留这段记录",Rect2(850,745,660,79),func(): game.perform("ending_home"))
	var total = game.model.counts()
	info(body,"金色 %d / 30   ·   闪光 %d / 30"%[total.gold,total.shiny],Rect2(85,761,735,63),27)

func show_fault() -> void:
	var body = sheet("fault","保存没有完成",false,false)
	info(body,game.fault+"\n\n原记录已保留。未成功保存的操作不会继续结算。",Rect2(48,180,960,245),28)
	action(body,"RetrySave","重新读取" if game.load_fault else "重试保存",Rect2(48,520,960,76),func():
		game.fault = ""
		if game.load_fault: game.load_slot(game.slot)
		elif game.save_progress(): game.render()
		else: show_fault())
	action(body,"FaultSlots","返回记录选择",Rect2(48,628,960,76),func():
		game.fault = ""
		slots())

func reopen(id: String) -> void:
	match id:
		"delivery": delivery()
		"workshop": workshop()
		"skills": skills()
		"radio": radio()
		"timer": timer()
		"door": door()
		"collection": collection()
		"card": card_detail(selected_card)

func refresh() -> void:
	if game.modal == "delivery":
		var items = game.modal_layer.find_child("DeliveryItems",true,false)
		if items: items.text = item_lines(game.model.s.inbox)
		var count = game.modal_layer.find_child("DeliveryCount",true,false)
		if count: count.text = "%d 趟记录待收取"%game.model.s.box_rounds
		var claim = game.modal_layer.find_child("Claim",true,false)
		if claim: claim.disabled = game.model.s.inbox.is_empty() and game.model.s.box_rounds==0
	elif game.modal == "timer":
		var seconds = int(ceil(game.model.s.pomo.remaining))
		var digits = game.modal_layer.find_child("TimerDigits",true,false)
		if digits: digits.text = "%02d:%02d"%[seconds/60,seconds%60]
		var phase = game.modal_layer.find_child("TimerPhase",true,false)
		if phase: phase.text = ("专注" if game.model.s.pomo.phase=="focus" else "休息")+" · 已完成 %d 段"%game.model.s.pomo.completed
