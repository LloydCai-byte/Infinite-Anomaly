extends Control
const UI = preload("res://scripts/ui_style.gd")
const Art = preload("res://scripts/wire_art.gd")
const Room = preload("res://scripts/room_view.gd")
const Comic = preload("res://scripts/comic_view.gd")

var room
var terminal_comic
var overlay: Panel
var page: String = ""
var collection_id: String = "A01"
var selected_card: String = ""
var reading_id: String = "OPEN"
var revision: int = -1
var header_credits: Button
var header_energy: Button
var header_power: Button
var state_label: Label
var stage_label: Label
var case_label: Label
var countdown_label: Label
var comic_title: Label
var gap_label: Label
var collection_label: Label
var room_title: Label
var next_label: Label
var event_label: Label
var save_label: Label
var progress: ProgressBar
var steps: Label
var retry_button: Button
var stop_button: Button
var result_button: Button
var archive_button: Button
var reader
var page_note: Label
var save_dialog: ConfirmationDialog
var last_fault: String = ""
var last_result_id: int = 0

func place(control: Control, parent: Node, x: float, y: float, w: float, h: float) -> Control:
	parent.add_child(control)
	control.position = Vector2(x,y)
	control.size = Vector2(w,h)
	return control

func label(parent: Node, text: String, x: float, y: float, w: float, h: float, font_size: int = 20, color: Color = UI.INK, word_wrap: bool = false) -> Label:
	var node = Label.new()
	place(node,parent,x,y,w,h)
	node.text = text
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if word_wrap:
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		node.clip_text = true
	return node

func button(parent: Node, text: String, x: float, y: float, w: float, h: float, callback: Callable, primary: bool = false) -> Button:
	var node = Button.new()
	place(node,parent,x,y,w,h)
	node.text = text
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.pressed.connect(callback)
	if primary:
		node.add_theme_stylebox_override("normal",UI.box(Color("233d34"),UI.MINT))
		node.add_theme_color_override("font_color",UI.MINT)
	return node

func panel(parent: Node, x: float, y: float, w: float, h: float, color: Color = UI.PANEL, border: Color = UI.LINE) -> Panel:
	var node = Panel.new()
	place(node,parent,x,y,w,h)
	node.add_theme_stylebox_override("panel",UI.box(color,border))
	return node

func _ready() -> void:
	theme = UI.theme()
	reading_id = Game.model.s.reading
	get_window().min_size = Vector2i(1152,648)
	var background = ColorRect.new()
	background.color = UI.BG
	place(background,self,0,0,1920,1080)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label(self,"∞",38,28,66,62,57,UI.MINT)
	label(self,"无限异常",115,26,400,50,37,UI.INK)
	label(self,"主神空间   /   收容记录 001",117,77,510,26,17,UI.MUTED)
	label(self,"WIREFRAME  /  MVP 0.1",646,56,355,34,18,UI.MUTED)
	header_credits = button(self,"",1050,36,254,55,func(): open_page("resources"))
	header_energy = button(self,"",1320,36,234,55,func(): open_page("resources"))
	header_power = button(self,"",1570,36,181,55,func(): open_page("abilities"))
	button(self,"设置",1767,36,113,55,func(): open_page("settings"))
	var divider = ColorRect.new()
	divider.color = UI.LINE
	place(divider,self,40,113,1840,1)
	var room_frame = panel(self,40,136,1134,754)
	room_title = label(room_frame,"",24,16,600,35,25)
	label(room_frame,"点击设施，管理你在这里的生活",683,20,425,30,17,UI.MUTED)
	room = Room.new()
	place(room,room_frame,16,66,1102,628)
	room.facility_pressed.connect(open_page)
	next_label = label(room_frame,"",24,703,1080,32,19,UI.MINT)
	var nav_items: Array = [["任务档案","missions"],["收容卡册","cards"],["行动能力","abilities"],["空间设施","upgrades"],["漫画档案","comics"]]
	for i in range(nav_items.size()):
		var entry: Array = nav_items[i]
		button(self,entry[0],40+i*230,912,214,54,func(): open_page(entry[1])).name = "Nav_"+entry[1]
	build_terminal()
	var footer = panel(self,40,986,1840,66,Color("111d20"))
	button(footer,"记录",12,12,80,41,func(): open_page("events"))
	event_label = label(footer,"",110,5,1295,55,17,UI.MUTED,true)
	save_label = label(footer,"",1440,7,378,51,15,UI.MUTED,true)
	Game.changed.connect(refresh)
	Game.fault.connect(show_fault)
	refresh()
	if Game.recovery_needed:
		show_fault(Game.error_message)
	elif not Game.model.s.tutorial:
		open_page("intro")
	if "--smoke" in OS.get_cmdline_user_args() or "--capture" in OS.get_cmdline_user_args():
		call_deferred("smoke_run")

func build_terminal() -> void:
	var terminal = panel(self,1200,136,680,830)
	label(terminal,"探索终端",24,17,300,37,27)
	state_label = label(terminal,"",436,22,219,31,18,UI.MINT)
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	case_label = label(terminal,"",24,69,629,32,20,UI.MUTED)
	stage_label = label(terminal,"",24,110,629,44,29)
	steps = label(terminal,"",24,162,629,34,19,UI.MUTED)
	progress = ProgressBar.new()
	place(progress,terminal,24,211,632,9)
	progress.show_percentage = false
	progress.add_theme_font_size_override("font_size",1)
	for style_name in ["background","fill"]:
		var progress_style = UI.box(UI.MINT if style_name=="fill" else Color("0d1517"),UI.MINT if style_name=="fill" else UI.LINE,1,2)
		progress_style.set_content_margin_all(0)
		progress.add_theme_stylebox_override(style_name,progress_style)
	progress.size = Vector2(632,9)
	progress.max_value = 100
	countdown_label = label(terminal,"",24,233,632,29,18,UI.MUTED)
	comic_title = label(terminal,"",24,275,400,28,18)
	archive_button = button(terminal,"展开漫画",470,273,186,33,expand_latest_comic)
	archive_button.add_theme_font_size_override("font_size",16)
	terminal_comic = Comic.new()
	place(terminal_comic,terminal,24,318,632,282)
	gap_label = label(terminal,"",24,616,632,61,19,UI.WARN,true)
	retry_button = button(terminal,"",24,688,425,49,retry_or_mission,true)
	stop_button = button(terminal,"返回空间",467,688,189,49,request_stop)
	result_button = button(terminal,"暂无结算 · 收益会自动入账",24,755,632,53,show_latest_card)
	result_button.add_theme_font_size_override("font_size",18)

func expand_latest_comic() -> void:
	reading_id = Game.model.s.latest_comic
	open_page("comics")

func refresh() -> void:
	var m = Game.model
	var s: Dictionary = m.s
	header_credits.text = "信用点  %s" % s.credits
	header_energy.text = "异常能量  %s" % s.energy
	header_power.text = "处置等级  %d" % m.power()
	room_title.text = "主神空间 / " + ("稳定据点" if s.upgrades.living > 0 else "临时避难所")
	room.update_state(s.upgrades,s.cards.size())
	var names: Dictionary = {"IDLE":"○ 小队待命","PUSH":"● 自动推进","FARM":"● 回响采集","BLOCKED":"△ 前线受阻"}
	state_label.text = names[s.mode]
	case_label.text = "%s  /  %s" % [s.dungeon,m.db.dungeons[s.dungeon].name]
	var target_name: String = "等待派遣"
	if s.mode == "PUSH":
		target_name = m.db.stages[s.target].name
	elif s.mode == "FARM":
		target_name = "封存回响" if s.dungeon in s.completed else m.db.farms[s.target].name
	elif s.mode == "BLOCKED":
		target_name = "条件不足，等待调整"
	stage_label.text = target_name
	var markers: Array[String] = []
	var dungeon_stages: Array = m.db.dungeons[s.dungeon].stages
	for i in range(dungeon_stages.size()):
		var stage_id: String = dungeon_stages[i]
		markers.append(("●" if stage_id in s.cleared else ("◉" if s.target == stage_id else "○")) + " %02d" % (i+1))
	steps.text = "    ".join(markers)
	progress.value = (1.0 - float(s.remaining)/float(s.duration))*100.0 if s.duration > 0 else 0.0
	if s.mode in ["PUSH","FARM"]:
		countdown_label.text = "下一次结算  %02d:%02d  /  本轮 %d 秒" % [floori(ceil(s.remaining)/60.0),int(ceil(s.remaining))%60,int(s.duration)]
	else:
		countdown_label.text = "选择任务后，小队将自动探索"
	var comic_id: String = s.latest_comic
	comic_title.text = m.db.comics[comic_id].title
	terminal_comic.display(m.db.comics[comic_id],int(s.comic_progress.get(comic_id,1)),true)
	if s.blocked != "":
		gap_label.text = ("条件已满足：可主动重试前线。" if m.missing(s.blocked).is_empty() else "前线受阻：" + s.block_reason) + "\n" + ("当前仍在安全采集，收益正常到账。" if s.mode == "FARM" else "可改派已开放的旧副本。")
	elif s.mode == "FARM":
		var pool_id: String = m.db.farms[s.target].pool
		var missing: Array = m.missing_cards(pool_id)
		gap_label.text = "本池已收齐 · 重复回响自动解析为能量" if missing.is_empty() else "本池缺 %d 张  /  连续重复 %d / 4\n连续 4 次重复后，下次必得本池未收容异常。" % [missing.size(),s.pity.get(pool_id,0)]
	elif s.mode == "PUSH":
		gap_label.text = "小队正在自动探索。阅读漫画、查看卡册或升级设施均不影响计时。"
	else:
		gap_label.text = "一次派遣，一支小队。选择下一份异常档案。"
	gap_label.add_theme_color_override("font_color",UI.WARN if s.blocked != "" else UI.MUTED)
	retry_button.text = "重试前线" if s.blocked != "" and m.missing(s.blocked).is_empty() else ("升级行动中枢" if s.blocked != "" and m.power()<2 else "选择任务 / 刷取点")
	stop_button.disabled = s.mode == "IDLE" or not s.tutorial
	if not s.last_result.is_empty():
		var result: Dictionary = s.last_result
		var card_name: String = m.db.cards[result.card].name if result.card != "" else "阶段完成"
		result_button.text = "%s%s   +%d 信用 / +%d 能量" % ["新收容 · " if result.new else "",card_name,result.credits,result.energy]
		if int(result.attempt) != last_result_id:
			last_result_id = int(result.attempt)
			result_button.modulate = UI.MINT if result.new else UI.INK
			create_tween().tween_property(result_button,"modulate",Color.WHITE,1.4)
			if result.new:
				result_button.pivot_offset = result_button.size*0.5
				result_button.scale.x = 0.06
				create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).tween_property(result_button,"scale:x",1.0,0.4)
	var objective: String = "在任务档案选择目的地，开始第一次派遣。"
	if not s.tutorial:
		objective = "登记门卡，建立你的第一处回归锚点。"
	elif s.blocked != "":
		objective = "下一目标 / " + ("重试前线，继续调查十三层。" if m.missing(s.blocked).is_empty() else "升级行动中枢：60 信用点 + 20 异常能量。")
	elif s.mode == "PUSH":
		objective = "下一目标 / " + m.db.stages[s.target].name + " · 小队正在记录异常。"
	elif s.mode == "FARM":
		objective = "收藏进度 / %s  %d / %d" % [m.db.collections[s.dungeon].name,m.collection_count(s.dungeon),m.db.collections[s.dungeon].cards.size()]
		if s.dungeon in s.completed:
			objective += "  · 金边结案已完成，可继续采集或选择下一副本。"
	next_label.text = objective
	var messages: Array[String] = []
	for i in range(mini(2,s.events.size())):
		messages.append("· " + s.events[i].text)
	event_label.text = "\n".join(messages) if not messages.is_empty() else "终端已就绪。等待第一份收容记录。"
	save_label.text = "本地自动保存 · 关闭游戏不计算收益\n最小化继续探索   /   F11 全屏"
	if Game.recovery_needed:
		save_label.text = "存档异常 · 已暂停运行"
		show_fault(Game.error_message)
	if page in ["comics","intro"] and is_instance_valid(reader):
		reader.display(m.db.comics[reading_id],int(s.comic_progress.get(reading_id,0)))
		if page=="comics" and int(s.comic_progress.get(reading_id,0))==4 and reading_id not in s.read_comics:
			Game.act.call_deferred("read",reading_id)
		if is_instance_valid(page_note):
			var unread: int = s.comics.size()-s.read_comics.size()
			page_note.text = "探索继续运行  ·  未读 %d 页  ·  新记录不会打断当前阅读" % unread
	if int(s.revision) != revision:
		revision = int(s.revision)
		if page in ["missions","cards","abilities","upgrades","resources","events","debug"]:
			build_page()

func open_page(id: String) -> void:
	if not Game.model.s.tutorial and id != "intro" and id != "settings":
		id = "intro"
	if id == "comics":
		if reading_id not in Game.model.s.comics:
			reading_id = Game.model.s.latest_comic
	page = id
	build_page()

func close_page() -> void:
	if not Game.model.s.tutorial:
		return
	page = ""
	if is_instance_valid(overlay):
		overlay.queue_free()
		overlay = null
	reader = null

func build_page() -> void:
	if is_instance_valid(overlay):
		remove_child(overlay)
		overlay.queue_free()
	reader = null
	page_note = null
	if page == "":
		return
	overlay = panel(self,40,136,1134,754,Color("142125"),UI.MUTED)
	var titles: Dictionary = {"missions":"任务档案","cards":"永久收容卡册","card_detail":"异常档案","abilities":"行动能力","upgrades":"空间设施","preview":"升级预览","comics":"漫画档案","intro":"开场 · 一张写着你姓名的门卡","resources":"资源与来源","events":"事件记录","settings":"设置与存档","debug":"开发调试 / F3","ending":"金边结案"}
	label(overlay,titles.get(page,page),28,18,925,42,29)
	if Game.model.s.tutorial:
		button(overlay,"关闭",1001,18,105,42,close_page)
	match page:
		"missions": build_missions()
		"cards": build_cards()
		"card_detail": build_card_detail()
		"abilities": build_abilities()
		"upgrades": build_upgrades()
		"preview": build_preview()
		"comics","intro": build_comics()
		"resources": build_resources()
		"events": build_events()
		"settings": build_settings()
		"debug": build_debug()
		"ending": build_ending()

func build_missions() -> void:
	var m = Game.model
	label(overlay,"选择探索目标。首通进度永久保留，旧副本可以直接进入已开放刷取点。",28,72,1068,42,19,UI.MUTED,true)
	var index: int = 0
	for id in m.db.dungeons:
		var dungeon: Dictionary = m.db.dungeons[id]
		var unlocked: bool = m.is_unlocked(id)
		var y: float = 132 + index*281
		var block = panel(overlay,28,y,1078,252,Color("101c1f"))
		label(block,id,21,15,70,32,17,UI.MINT)
		label(block,dungeon.name,103,10,488,41,29)
		label(block,dungeon.subtitle,21,61,751,31,18,UI.MUTED)
		label(block,dungeon.description,21,101,747,74,20,UI.INK,true)
		label(block,"收容  %d / %d%s" % [m.collection_count(id),m.db.collections[id].cards.size(),"  · 金边结案" if id in m.s.completed else ""],811,69,247,37,19,UI.GOLD if id in m.s.completed else UI.MUTED)
		var dispatch_button = button(block,"派遣 / 继续" if unlocked else "通关末班电梯后开放",810,117,247,49,func(): request_dispatch(id),true)
		dispatch_button.name = "Dispatch_"+id
		dispatch_button.disabled = not unlocked
		var farm_index: int = 0
		for farm_id in dungeon.farms:
			var farm: Dictionary = m.db.farms[farm_id]
			var farm_button = button(block,farm.name,21+farm_index*255,191,240,42,func(): request_dispatch(id,farm_id))
			farm_button.name = "Farm_"+farm_id
			farm_button.disabled = farm_id not in m.available_farms(id)
			farm_button.tooltip_text = "30 秒 / 轮；首通 %s 后开放" % m.db.stages[farm.unlock_stage].name
			farm_index += 1
		index += 1
	label(overlay,"换任务会清除当前轮未完成计时；已到账资源、卡牌与各池保底全部保留。",28,714,1070,27,17,UI.MUTED)

func build_cards() -> void:
	var m = Game.model
	var s: Dictionary = m.s
	button(overlay,"A01 末班电梯",28,75,237,41,func(): collection_id="A01"; build_page())
	var tab = button(overlay,"B01 空站来信",281,75,237,41,func(): collection_id="B01"; build_page())
	tab.disabled = not m.is_unlocked("B01")
	var complete: bool = collection_id in s.completed
	label(overlay,"%d / %d  %s" % [m.collection_count(collection_id),m.db.collections[collection_id].cards.size(),"永久金边" if complete else "已收容"],722,79,378,34,22,UI.GOLD if complete else UI.MINT)
	var cards: Array = m.db.collections[collection_id].cards
	for i in range(cards.size()):
		var id: String = cards[i]
		var card: Dictionary = m.db.cards[id]
		var owned: bool = id in s.cards
		var x: float = 28+(i%4)*275
		var y: float = 137+floori(i/4.0)*262
		var tile = button(overlay,"",x,y,253,244,func(): selected_card=id; Game.act("card_read",id); open_page("card_detail"))
		tile.name = "Card_"+id
		tile.add_theme_stylebox_override("normal",UI.box(Color("111d20"),UI.GOLD if complete else UI.LINE,2 if complete else 1))
		label(tile,id.replace("_"," / "),13,9,170,26,15,UI.MUTED)
		if id in s.unread_cards:
			label(tile,"NEW",190,9,54,26,14,UI.MINT)
		var art = Art.new()
		place(art,tile,17,37,219,137)
		art.kind = card.art
		art.concealed = not owned
		label(tile,card.name if owned else "未收容异常",14,179,227,30,21,UI.INK if owned else UI.MUTED)
		label(tile,("能力 · "+m.db.tags[card.tag]) if owned and card.tag!="" else ("已永久登记" if owned else card.source.split("；")[0]),14,210,227,26,16,UI.MINT if owned else UI.MUTED)
	if complete:
		button(overlay,"查看结案与后续",28,690,294,42,func(): open_page("ending"),true).name = "ReadEnding"
	else:
		label(overlay,"集齐本套基础收容物后，永久获得金边、一次性奖励与结案后续。",28,688,1070,42,18,UI.MUTED,true)

func build_card_detail() -> void:
	var m = Game.model
	var card: Dictionary = m.db.cards[selected_card]
	var owned: bool = selected_card in m.s.cards
	button(overlay,"← 返回卡册",28,77,202,40,func(): open_page("cards"))
	var plate = panel(overlay,28,146,346,450,Color("101b1e"),UI.GOLD if card.case in m.s.completed else UI.LINE)
	var art = Art.new()
	place(art,plate,20,45,306,288)
	art.kind = card.art
	art.concealed = not owned
	label(plate,selected_card,23,19,296,30,17,UI.MUTED)
	label(plate,card.name if owned else "待收容",23,339,296,43,29)
	label(plate,"永久收容登记" if owned else "形象与规则尚未揭晓",23,394,296,30,18,UI.MINT if owned else UI.MUTED)
	label(overlay,"异常规则",410,147,675,33,23,UI.MINT)
	label(overlay,card.rule if owned else "完成对应调查后，异常规则与收容档案将开放。",410,194,675,101,23,UI.INK,true)
	label(overlay,"收容记录",410,308,675,35,23,UI.MINT)
	label(overlay,card.containment if owned else "尚未登记",410,357,675,91,21,UI.INK,true)
	label(overlay,"获取来源  /  "+card.source,410,465,675,68,20,UI.INK,true)
	var effect: String = "首次登记解锁 "+m.db.tags[card.tag] if card.tag!="" else "属于基础卡册；集齐后解锁金边与结案。"
	label(overlay,effect,410,545,675,62,21,UI.MINT,true)
	label(overlay,"重复回响样本自动解析为 5 能量，已收容本体永久保留。",28,623,1060,36,19,UI.MUTED)
	if owned:
		label(overlay,"首次登记  "+m.s.first_obtained.get(selected_card,"已记录"),28,673,704,37,18,UI.MUTED)
	button(overlay,"前往任务档案",843,674,259,43,func(): open_page("missions"))

func build_abilities() -> void:
	var m = Game.model
	label(overlay,"处置等级  %d" % m.power(),28,91,680,59,41,UI.MINT)
	label(overlay,"等级与永久能力共同决定能否通过阶段。已满足条件的尝试会在计时结束后成功。",28,164,1058,63,22,UI.MUTED,true)
	var index: int = 0
	for id in m.db.tags:
		var unlocked: bool = id in m.s.tags
		var area = panel(overlay,28,266+index*166,1078,144,Color("101b1e"))
		label(area,m.db.tags[id],22,16,327,42,27,UI.MINT if unlocked else UI.MUTED)
		label(area,"常驻生效" if unlocked else "尚未解锁",832,21,224,33,19,UI.MINT if unlocked else UI.MUTED)
		label(area,"教程首次收容无主门卡，建立小队的回归坐标。" if id=="anchor" else "末班电梯第三阶段首通，确定获得白噪声听筒。",22,76,1012,47,21,UI.INK,true)
		index += 1
	button(overlay,"查看行动中枢升级",28,632,363,52,func(): open_page("upgrades"),true)
	label(overlay,"升级影响下一次尝试；当前任务计时与判定快照保持不变。",28,704,1067,29,18,UI.MUTED)

func build_upgrades() -> void:
	var m = Game.model
	label(overlay,"功能成长与生活改善分别记录。购买后立即保存，空间中的设施同步变化。",28,74,1070,48,20,UI.MUTED,true)
	var index: int = 0
	for id in m.db.upgrades:
		var upgrade: Dictionary = m.db.upgrades[id]
		var built: bool = m.s.upgrades[id] >= upgrade.max
		var area = panel(overlay,28,141+index*181,1078,162,Color("101b1e"))
		label(area,upgrade.name,22,14,264,44,28)
		label(area,"已完成升级" if built else "等级 0 → 1",22,66,251,29,18,UI.MINT if built else UI.MUTED)
		button(area,"预览外观",22,109,206,37,func(): selected_card=id; open_page("preview"))
		label(area,upgrade.effect,289,19,459,78,20,UI.INK,true)
		var deficit: String = "" if built else "差额：信用 %d / 能量 %d" % [maxi(0,int(upgrade.credits)-int(m.s.credits)),maxi(0,int(upgrade.energy)-int(m.s.energy))]
		label(area,deficit,289,110,463,32,17,UI.MUTED)
		label(area,"%d 信用 / %d 能量" % [upgrade.credits,upgrade.energy],775,26,285,36,20,UI.MINT)
		var buy_button = button(area,"已升级" if built else "升级设施",783,94,267,51,func(): buy_upgrade(id),true)
		buy_button.name = "Buy_"+id
		buy_button.disabled = built or m.s.credits < upgrade.credits or m.s.energy < upgrade.energy
		buy_button.tooltip_text = "资源可由已开放刷取点持续获得。出征不消耗资源。"
		index += 1
	label(overlay,"资源不足可返回已通关内容继续采集。卡牌不会因展柜等级低而无法入库。",28,700,1071,35,18,UI.MUTED)

func build_preview() -> void:
	var m = Game.model
	var upgrade: Dictionary = m.db.upgrades[selected_card]
	label(overlay,upgrade.name+" / "+upgrade.preview,28,77,1067,58,21,UI.MINT,true)
	var preview = Room.new()
	place(preview,overlay,80,137,971,519)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var values: Dictionary = m.s.upgrades.duplicate()
	values[selected_card] = 1
	preview.update_state(values,m.s.cards.size())
	button(overlay,"← 返回设施",28,680,264,48,func(): open_page("upgrades"))
	var buy_button = button(overlay,"升级  %d 信用 / %d 能量" % [upgrade.credits,upgrade.energy],644,680,457,48,func(): buy_upgrade(selected_card); open_page("upgrades"),true)
	buy_button.disabled = m.s.upgrades[selected_card] >= upgrade.max or m.s.credits < upgrade.credits or m.s.energy < upgrade.energy

func build_comics() -> void:
	var m = Game.model
	if page == "intro":
		reading_id = "OPEN"
	var comic: Dictionary = m.db.comics[reading_id]
	label(overlay,comic.title,28,75,804,35,23,UI.MINT)
	if page == "comics":
		var picker = OptionButton.new()
		place(picker,overlay,608,73,491,42)
		for id in m.s.comics:
			picker.add_item(("● " if id not in m.s.read_comics else "")+m.db.comics[id].title)
		picker.select(m.s.comics.find(reading_id))
		picker.item_selected.connect(func(index): reading_id=m.s.comics[index]; Game.act("read",reading_id); build_page())
	reader = Comic.new()
	place(reader,overlay,28,130,1078,537)
	reader.display(comic,int(m.s.comic_progress.get(reading_id,0)))
	if page == "intro":
		label(overlay,"你留在主神空间，小队负责探索。先登记第一件收容物。",28,691,701,35,19,UI.MUTED)
		button(overlay,"登记门卡，进入空间",771,682,335,52,complete_intro,true).name = "BeginGame"
	else:
		page_note = label(overlay,"探索继续运行。漫画阅读位置会保存。",28,720,1065,25,16,UI.MUTED)
		button(overlay,"← 上一页",28,678,190,35,func(): turn_page(-1))
		button(overlay,"下一页 →",232,678,190,35,func(): turn_page(1))
		button(overlay,"回到最新记录",851,678,254,35,func(): reading_id=m.s.latest_comic; Game.act("read",reading_id); build_page())
		if int(m.s.comic_progress.get(reading_id,0)) == 4 and reading_id not in m.s.read_comics:
			Game.act.call_deferred("read",reading_id)

func build_ending() -> void:
	var m = Game.model
	var collection: Dictionary = m.db.collections[collection_id]
	label(overlay,collection.name+" / 收容完成",28,102,1058,62,39,UI.GOLD)
	label(overlay,"基础异常全部收容 · 永久金边已保存 · 完成奖励已自动入账",28,184,1058,41,22,UI.GOLD)
	label(overlay,collection.text,28,265,1046,325,26,UI.INK,true)
	label(overlay,"回响采集继续开放。已解决的事件不会再次发生，采集对象为封存后的残余记录。",28,594,1046,68,21,UI.MUTED,true)
	button(overlay,"阅读结案漫画",28,680,331,48,func(): reading_id=collection.ending; open_page("comics"),true)
	button(overlay,"返回金边卡册",774,680,331,48,func(): open_page("cards"))

func build_resources() -> void:
	label(overlay,"信用点",28,100,1040,45,32,UI.MINT)
	label(overlay,"阶段首通、常规刷取与一次性结案奖励提供信用点。用于行动中枢、收容展示和生活设施。",28,162,1036,94,24,UI.INK,true)
	label(overlay,"异常能量",28,288,1040,45,32,UI.MINT)
	label(overlay,"阶段与刷取直接产出。重复回响每份自动解析为 5 能量；永久收容的异常本体不会被销毁。能量用于行动与收容设施。",28,352,1036,107,24,UI.INK,true)
	label(overlay,"末班电梯刷取：每 30 秒，20 信用点 + 8 能量 + 1 份卡 / 回响样本。",28,514,1036,74,23,UI.MUTED,true)
	label(overlay,"所有收益直接入账，无需领取。出征不消耗货币，也没有体力与门票。",28,608,1036,75,23,UI.MINT,true)

func build_events() -> void:
	label(overlay,"最近 40 条记录。阅读记录不会再次发放奖励。",28,73,1044,36,19,UI.MUTED)
	var scroll = ScrollContainer.new()
	place(scroll,overlay,28,129,1075,589)
	var stack = VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation",17)
	scroll.add_child(stack)
	for entry in Game.model.s.events:
		var row = Label.new()
		row.text = "%03d   %s" % [entry.id,entry.text]
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.custom_minimum_size = Vector2(1000,43)
		row.add_theme_font_size_override("font_size",22)
		row.add_theme_color_override("font_color",UI.GOLD if entry.kind=="gold" else (UI.MINT if entry.kind=="new" else UI.INK))
		stack.add_child(row)

func build_settings() -> void:
	label(overlay,"运行与保存",28,91,1012,45,28,UI.MINT)
	label(overlay,"游戏最小化或失去焦点时，小队继续探索。关闭游戏后，本版不计算离线收益；再次进入会从已保存进度继续。",28,151,1038,97,24,UI.INK,true)
	label(overlay,"自动保存约每 12 秒执行；首通、新卡、升级、切换任务与结案会立即保存。保留最近一份可恢复备份。",28,276,1038,99,23,UI.INK,true)
	label(overlay,"存档位置",28,410,1044,35,22,UI.MINT)
	label(overlay,Game.store.path,28,457,1045,80,19,UI.MUTED,true)
	var preference = CheckBox.new()
	place(preference,overlay,28,555,1050,47)
	preference.text = "切换任务时不再提醒（未完成计时仍会清除）"
	preference.button_pressed = Game.model.s.skip_switch_warning
	preference.toggled.connect(func(value): Game.act("switch_preference","true" if value else "false"))
	button(overlay,"切换全屏 / F11",28,638,324,54,toggle_fullscreen)
	button(overlay,"保存并退出",778,638,324,54,request_quit)
	label(overlay,"所有场景、卡面与漫画均为程序绘制的线框占位。F3 打开开发调试。",28,711,1040,28,17,UI.MUTED)

func build_debug() -> void:
	var s: Dictionary = Game.model.s
	label(overlay,"调试按钮仅在 F3 开发面板显示；不改变正式计时配置。",28,79,1038,38,20,UI.WARN)
	button(overlay,"立即推进本轮",28,143,321,53,func(): Game.act("step"),true).name = "DebugStep"
	button(overlay,"增加测试资源 +200 / +100",370,143,412,53,func(): Game.act("resources"))
	label(overlay,"当前门槛："+(s.block_reason if s.blocked!="" else "无缺项"),28,226,1040,57,22,UI.MINT,true)
	label(overlay,"模式 %s   目标 %s\n尝试序号 %d   已结算 %d\n本轮快照 %s\n各池保底 %s\n存档版本 %d   修订 %d\n首通奖励记录 %s" % [s.mode,s.target,s.attempt_serial,s.settled_serial,JSON.stringify(s.snapshot),JSON.stringify(s.pity),s.save_version,s.revision,JSON.stringify(s.claimed)],28,302,1042,365,21,UI.INK,true)

func request_dispatch(dungeon_id: String, farm_id: String = "") -> void:
	var action: Callable = func(): Game.act("dispatch",dungeon_id,farm_id); close_page()
	if Game.model.s.mode in ["PUSH","FARM"] and not Game.model.s.skip_switch_warning:
		confirm("切换任务", "当前阶段的未完成计时将清除。\n已到账资源、收容卡与保底进度保留。", action, true)
	else:
		action.call()

func confirm(title_text: String, message: String, action: Callable, allow_skip: bool = false) -> void:
	var dialog = ConfirmationDialog.new()
	dialog.title = title_text
	dialog.dialog_text = message
	dialog.ok_button_text = "确认"
	dialog.cancel_button_text = "取消"
	dialog.min_size = Vector2i(680,240)
	add_child(dialog)
	dialog.confirmed.connect(action)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	if allow_skip:
		var checkbox = CheckBox.new()
		checkbox.text = "之后不再提醒"
		dialog.add_child(checkbox)
		checkbox.position = Vector2(20,140)
		checkbox.toggled.connect(func(value): Game.act("switch_preference","true" if value else "false"))
	dialog.popup_centered()

func retry_or_mission() -> void:
	var m = Game.model
	if m.s.blocked != "" and m.missing(m.s.blocked).is_empty():
		Game.act("retry")
	elif m.s.blocked != "" and m.power()<2:
		open_page("upgrades")
	else:
		open_page("missions")

func request_stop() -> void:
	confirm("返回空间","结束当前派遣，放弃本轮未完成计时。\n已到账收益全部保留。",func(): Game.act("stop"))

func buy_upgrade(id: String) -> void:
	Game.act("buy",id)
	refresh()

func complete_intro() -> void:
	Game.act("read","OPEN")
	Game.act("tutorial")
	close_page()
	open_page("missions")

func turn_page(direction: int) -> void:
	var pages: Array = Game.model.s.comics
	var index: int = clampi(pages.find(reading_id)+direction,0,pages.size()-1)
	reading_id = pages[index]
	Game.act("read",reading_id)
	build_page()

func show_latest_card() -> void:
	var result: Dictionary = Game.model.s.last_result
	if not result.is_empty() and result.card!="":
		selected_card = result.card
		collection_id = Game.model.db.cards[selected_card].case
		Game.act("card_read",selected_card)
		open_page("card_detail")
	else:
		open_page("events")

func toggle_fullscreen() -> void:
	var full: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)

func request_quit() -> void:
	confirm("保存并退出","关闭后不会产生离线收益。\n下次启动将继续已保存的探索进度。",save_and_quit)

func save_and_quit() -> void:
	Game.pulse()
	if Game.persist() and not Game.recovery_needed:
		get_tree().quit()
	else:
		show_fault(Game.error_message)

func show_fault(message: String) -> void:
	if message == last_fault:
		return
	last_fault = message
	if is_instance_valid(save_dialog):
		save_dialog.queue_free()
	save_dialog = ConfirmationDialog.new()
	save_dialog.title = "存档需要处理"
	save_dialog.dialog_text = message
	save_dialog.ok_button_text = "恢复最近备份"
	save_dialog.cancel_button_text = "保留文件并退出"
	save_dialog.min_size = Vector2i(740,260)
	add_child(save_dialog)
	save_dialog.confirmed.connect(func():
		last_fault=""
		if Game.recover_backup():
			save_dialog.queue_free()
		else:
			show_fault(Game.error_message))
	save_dialog.canceled.connect(func(): get_tree().quit())
	save_dialog.popup_centered()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_ESCAPE: close_page()
		KEY_F11: toggle_fullscreen()
		KEY_F3:
			Game.debug_enabled = not Game.debug_enabled
			if Game.debug_enabled:
				open_page("debug")
			else:
				close_page()

func smoke_run() -> void:
	# Isolated transient state: test/capture never changes the player's save.
	await get_tree().process_frame
	if "--capture" in OS.get_cmdline_user_args():
		await capture("00_intro")
	complete_intro()
	Game.model.dispatch("A01")
	Game.model.tick(60)
	Game.model.buy("action")
	Game.model.retry()
	Game.model.tick(20)
	Game.model.s.upgrades.living = 1
	refresh()
	close_page()
	await get_tree().process_frame
	if "--capture" in OS.get_cmdline_user_args():
		await capture("01_space")
	for id in ["missions","cards","abilities","upgrades","comics","resources","events","settings","debug"]:
		if id == "comics":
			reading_id = "A01_3"
		open_page(id)
		await get_tree().process_frame
		if "--capture" in OS.get_cmdline_user_args() and id in ["cards","comics","upgrades","missions"]:
			await capture("02_"+id)
	selected_card = "A01_03"
	open_page("card_detail")
	await get_tree().process_frame
	if "--capture" in OS.get_cmdline_user_args():
		await capture("03_card_detail")
	selected_card = "display"
	open_page("preview")
	await get_tree().process_frame
	Game.model.tick(80)
	for i in range(15):
		Game.model.tick(30)
	refresh()
	collection_id = "A01"
	open_page("ending")
	await get_tree().process_frame
	if "--capture" in OS.get_cmdline_user_args():
		await capture("04_ending")
	close_page()
	print("UI SMOKE: all 13 views rendered, no player save modified")
	get_tree().quit()

func capture(file_name: String) -> void:
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png("res://.local/"+file_name+".png")
