extends Control
const UI = preload("res://scripts/home/ui.gd")
const Catalog = preload("res://scripts/campaign/catalog.gd")
const Rooms = preload("res://scripts/campaign/room.gd")
const Spot = preload("res://scripts/campaign/hotspot.gd")
const Sound = preload("res://scripts/campaign/sound.gd")
const PAPER = Color("ede8d9")
const INK = Color("252e32")
const FADED = Color("737872")
const GREEN = Color("a9d6c0")
var stage: Control
var hud: Control
var overlay: Control
var flash: ColorRect
var hint: Label
var toast_label: Label
var toast_time = 0.0
var narration: Label
var narration_time = 0.0
var progress_text: Label
var progress_bar: ColorRect
var progress_width = 260.0
var page = "title"
var modal = ""
var reveal = false
var spots: Array = []
var busy = false
var sound: Node
var choices_open = false
var memory_index = 0
var end_step = 0
var result_delay = 0.0
var auto_second: CanvasItem
var s: Dictionary:
	get: return Journey.s

func _ready() -> void:
	theme = UI.theme()
	stage = layer(self)
	hud = layer(self)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay = layer(self)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash = UI.line(self,Rect2(0,0,1920,1080),Color(0.04,0.05,0.08,0))
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sound = Sound.new()
	add_child(sound)
	Journey.event.connect(on_event)
	Journey.apply_settings()
	show_title()
	if "--campaign-capture" in OS.get_cmdline_user_args(): call_deferred("capture_all")

func layer(parent: Node) -> Control:
	var c = Control.new()
	UI.place(c,parent,Rect2(0,0,1920,1080))
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

func empty(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func label(parent: Node, value: String, rect: Rect2, pixels: int = 24, color: Color = Color("eeeadd")) -> Label:
	return UI.text(parent,value,rect,pixels,color,true)

func button(parent: Node, value: String, rect: Rect2, action: Callable, key: String = "", paper: bool = false) -> Button:
	var b = UI.button(parent,value,rect,func(): sound.cue("click"); action.call())
	if key != "": b.name = key
	if paper:
		b.add_theme_color_override("font_color",INK)
		b.add_theme_color_override("font_hover_color",INK)
		b.add_theme_color_override("font_disabled_color",FADED)
		b.add_theme_stylebox_override("normal",UI.box(Color("e0dbce"),Color("aca99e"),2))
		b.add_theme_stylebox_override("hover",UI.box(Color("f9f6ea"),Color("6e8e80"),2))
		b.add_theme_stylebox_override("disabled",UI.box(Color("e7e2d5"),Color("d2ccbc"),2))
		b.add_theme_stylebox_override("pressed",UI.box(Color("c8d4c8"),Color("6e8e80"),2))
	return b

func picture(parent: Node, path: String, rect: Rect2) -> TextureRect:
	if ResourceLoader.exists(path): return UI.image(parent,path,rect)
	var missing = TextureRect.new()
	UI.place(missing,parent,rect)
	label(parent,"素材尚未导入："+path,rect,24)
	return missing

func reset_view(id: String) -> void:
	page = id
	spots.clear()
	narration = null
	progress_text = null
	progress_bar = null
	auto_second = null
	empty(stage)
	empty(hud)
	hint = label(hud,"",Rect2(470,996,980,45),24)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label = label(hud,"",Rect2(520,60,880,64),22,GREEN)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button(hud,"Ⅱ",Rect2(1826,30,60,50),show_pause,"Pause")

func close_modal() -> void:
	empty(overlay)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal = ""
	if hint: hint.text = ""

func shade(kind: String, alpha: float = 0.66) -> void:
	close_modal()
	modal = kind
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var veil = UI.line(overlay,Rect2(0,0,1920,1080),Color(0.025,0.035,0.05,alpha))
	veil.mouse_filter = Control.MOUSE_FILTER_STOP

func toast(value: String) -> void:
	if is_instance_valid(toast_label):
		toast_label.text = value
		toast_time = 4.5

func show_title() -> void:
	close_modal()
	reset_view("title")
	empty(hud)
	picture(stage,Catalog.asset("home","entry"),Rect2(0,0,1920,1080))
	UI.line(stage,Rect2(0,0,790,1080),Color("eae7dcea"))
	label(stage,"INFINITE ANOMALY",Rect2(114,205,600,30),20,FADED)
	label(stage,"无限异常",Rect2(107,261,620,118),92,INK)
	label(stage,"门外是异常，门内是你最后的日常。",Rect2(117,405,560,65),26,INK)
	UI.line(stage,Rect2(117,502,70,3),Color("668b7a"))
	if Journey.has_save:
		button(stage,"继续这段记忆",Rect2(117,558,410,62),func(): Journey.resume_save(),"Continue",true)
		label(stage,"上次记录  "+str(Journey.saved_state.get("saved_at","")),Rect2(120,632,560,35),19,FADED)
	button(stage,"推开门",Rect2(117,700,410,62),confirm_new,"NewGame",true)
	button(stage,"声音与设置",Rect2(117,782,195,50),show_pause,"Settings",true)
	button(stage,"离开",Rect2(332,782,195,50),func(): get_tree().quit(),"Quit",true)
	label(stage,"完整故事版  1.0  /  鼠标探索 · Tab 提示 · Esc 暂停",Rect2(117,943,600,55),19,FADED)
	if Journey.fault != "": label(stage,Journey.fault,Rect2(117,848,560,90),20,Color("9d5744"))
	if Journey.recovered: label(stage,"已找到可恢复的轮换存档。",Rect2(117,668,500,30),20,Color("527563"))

func confirm_new() -> void:
	if not Journey.has_save:
		Journey.start_new()
		return
	shade("confirm")
	UI.panel(overlay,Rect2(550,330,820,360),Color("182225"),10)
	label(overlay,"开始新的故事？",Rect2(610,370,700,60),34)
	label(overlay,"当前进度将进入轮换备份，新故事从玄关开始。",Rect2(610,452,700,90),25)
	button(overlay,"保留当前故事",Rect2(610,585,320,60),close_modal,"CancelNew")
	button(overlay,"开始新故事",Rect2(955,585,350,60),func(): Journey.start_new(),"ConfirmNew")

func render() -> void:
	close_modal()
	match s.mode:
		"EXPLORE": show_explore()
		"RESULT": show_room(); show_result()
		"ENDING": show_ending()
		"GAMEOVER": show_gameover()
		_: show_room()

func on_event(kind: String) -> void:
	match kind:
		"new": end_step=0; show_room(); show_intro()
		"resume": end_step=0; render()
		"pause":
			if modal != "pause" and Journey.started: show_pause()
		"save_error": show_pause(); toast(Journey.fault)
		"saved": toast("记忆已保存")
		"checkpoint_held": toast("补给已不足以继续，保留上一份可恢复的记录。")
		"gameover": show_gameover()
		"result":
			sound.cue("return")
			render()
		"auto_next","depart": render()
		"low": render(); toast(s.notice)

func show_intro() -> void:
	Journey.paused = true
	shade("intro",0.5)
	UI.panel(overlay,Rect2(490,220,940,620),PAPER,3)
	label(overlay,"23:59",Rect2(560,273,800,60),38,INK)
	label(overlay,"你记得自己刚刚开过这扇门。\n\n门外不该是一层。你明明住在七楼。\n手机没有信号，只剩下一个从没装过的程序。\n冰箱里的食物正在减少，时间却停在原地。",Rect2(560,365,800,280),27,INK)
	label(overlay,"移动鼠标观察物件。点击门把手出门。\nTab 显示可互动位置；P 拿起手机。",Rect2(560,638,800,90),23,FADED)
	button(overlay,"起身",Rect2(1050,740,300,58),func(): Journey.paused=false; close_modal(),"Begin",true)

func add_spot(parent: Node, caption: String, rect: Rect2, action: Callable, visited: bool = false) -> Button:
	var p = Spot.new()
	p.caption = caption
	p.visited = visited
	p.reveal = reveal
	UI.place(p,parent,rect)
	p.pressed.connect(func(): if not busy: sound.cue("click"); action.call())
	p.pointed.connect(func(value): if is_instance_valid(hint): hint.text = value)
	spots.append(p)
	return p

func normal_rect(values: Array) -> Rect2:
	return Rect2(float(values[0])*1920,float(values[1])*1080,float(values[2])*1920,float(values[3])*1080)

func show_room() -> void:
	reset_view("home")
	picture(stage,Catalog.asset("home",s.room),Rect2(0,0,1920,1080))
	var room: Dictionary = Rooms.MAP[s.room]
	for item in room.spots:
		add_spot(stage,item[0],normal_rect(item[2]),func(): activate(item[1]))
	button(hud,"‹",Rect2(30,985,72,60),func(): change_room(room.back),"BackRoom")
	var phone = button(hud,"▯",Rect2(1810,958,82,96),show_phone,"Phone")
	phone.add_theme_font_size_override("font_size",50)
	label(hud,"P",Rect2(1840,1027,35,26),16,GREEN)
	if s.mode in ["AUTO","WAIT"]:
		if s.room == "entry": draw_door_progress()
		else:
			button(hud,"门口有动静",Rect2(1510,975,240,62),func(): change_room("entry"),"ReturnToDoor")
	if s.food < 25: label(hud,"手机亮起：补给不足",Rect2(1490,920,370,40),22,Color("dfaa8e"))
	if s.room=="entry" and s.frontier == 0 and s.xp == 0: label(hud,"门把手似乎动了一下。",Rect2(55,55,510,40),23,Color("4d5d58"))

func activate(action: String) -> void:
	if action.begins_with("room:"): change_room(action.trim_prefix("room:")); return
	if action.begins_with("look:"): toast(action.trim_prefix("look:")); return
	match action:
		"door","notes": show_door()
		"phone": show_phone()
		"monitor": show_monitor()
		"memories": show_memories()
		"supply": show_supply()
		"rest":
			Journey.paused = true
			shade("rest",0.45)
			UI.panel(overlay,Rect2(520,350,880,355),PAPER,3)
			label(overlay,"把今天记下来。",Rect2(580,392,760,70),34,INK)
			label(overlay,"房间安静下来。休息时资源消耗暂停。",Rect2(580,479,760,70),24,FADED)
			button(overlay,"记录并休息",Rect2(580,588,350,62),func(): if Journey.persist(): toast("保留上一份可恢复的记录。" if Journey.last_save_held else "已保存，可以安心离开。"),"SaveRest",true)
			button(overlay,"起身",Rect2(957,588,360,62),func(): Journey.paused=false; close_modal(),"Wake",true)

func change_room(id: String) -> void:
	if busy: return
	s.room = id
	sound.cue("step")
	show_room()
	fade_in()

func fade_in() -> void:
	if not s.motion: return
	flash.color = Color(0.025,0.035,0.05,0.45)
	create_tween().tween_property(flash,"color:a",0.0,0.35)

func show_door() -> void:
	if s.mode in ["AUTO","WAIT"]: show_monitor(); return
	if s.mode != "HOME": return
	shade("door",0.19)
	UI.panel(overlay,Rect2(122,115,742,855),Color("403b32"),5)
	UI.panel(overlay,Rect2(142,100,700,846),PAPER,2)
	label(overlay,"门边的记录",Rect2(197,135,590,65),37,INK)
	label(overlay,"熟悉的路可以重走。未见过的地方，留给自己。",Rect2(197,215,590,52),22,FADED)
	for i in Journey.model.nodes.size():
		var node: Dictionary = Journey.model.nodes[i]
		var available: bool = i <= s.frontier
		var mark = "✓" if s.cleared.has(str(i)) else ("○" if available else "—")
		var name_text: String = node.name if available else "尚未到达"
		var b = button(overlay,"%s  %02d  %s" % [mark,i+1,name_text],Rect2(192,291+i*51,598,44),func(): Journey.model.select_node(i); s.auto=false; show_door(),"Stage%d"%i,true)
		b.disabled = not available
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if i == int(s.selected): b.add_theme_stylebox_override("normal",UI.box(Color("c2d4c9"),Color("618b74"),2,2))
	button(overlay,"转动把手",Rect2(193,795,289,62),func(): departure(false),"Manual",true)
	button(overlay,"重走记得的路",Rect2(500,795,289,62),func(): departure(true),"Auto",true)
	label(overlay,"出门消耗 3.5 补给 · 手机可强化能力与补充食物",Rect2(194,879,598,35),19,FADED)
	button(overlay,"×",Rect2(859,108,62,56),close_modal,"CloseDoor")

func departure(automatic: bool) -> void:
	if s.food <= 5: toast("食物不够了。先打开冰箱或手机补充。需要 3 经验。"); return
	if not Journey.model.depart(automatic): return
	close_modal()
	sound.cue("door")
	if automatic:
		render()
		return
	busy = true
	reset_view("opening")
	picture(stage,Catalog.asset("home","entry"),Rect2(0,0,1920,1080))
	var portal = picture(stage,Catalog.asset("home","entry_open"),Rect2(0,0,1920,1080))
	portal.modulate.a=0
	var t = create_tween()
	t.tween_property(portal,"modulate:a",1.0,0.7 if s.motion else 0.01)
	t.tween_interval(0.25)
	t.tween_callback(func():
		busy=false
		render()
		fade_in()
		if Journey.paused: show_pause())

func show_explore() -> void:
	reset_view("explore")
	choices_open = false
	var node = Journey.model.current()
	picture(stage,Catalog.asset("world",node.id),Rect2(0,0,1920,1080))
	UI.line(stage,Rect2(0,0,1920,57),Color("10161de0"))
	label(stage,Catalog.CHAPTERS[int(node.chapter)]+"   /   "+node.name,Rect2(60,15,1400,39),21)
	for i in node.points.size():
		var point: Dictionary = node.points[i]
		add_spot(stage,point.label,normal_rect(point.rect),func(): inspect_point(i),s.observed.has(str(i)))
	UI.line(stage,Rect2(0,900,1920,180),Color("11191eed"))
	label(stage,"心 声",Rect2(90,913,240,35),19,GREEN)
	narration = label(stage,node.intro,Rect2(90,953,1350,85),26)
	narration_time = 0
	button(stage,"作出行动  ›",Rect2(1510,924,320,67),show_choices,"Choose")
	label(stage,"观察至少两处线索后行动。Tab 显示位置。",Rect2(90,1040,1100,28),18,Color("929c9f"))
	button(hud,"‹  撤回家中",Rect2(25,70,195,48),confirm_withdraw,"Withdraw")
	hint.position.y = 850
	hint.add_theme_color_override("font_color",Color("f4eccc"))
	if not s.observed.is_empty(): toast("已观察 %d / 3" % s.observed.size())

func inspect_point(index: int) -> void:
	var info = Journey.model.observe(index)
	if info.is_empty(): return
	narration.text = info.text
	narration_time = 0
	spots[index].visited = true
	spots[index].queue_redraw()
	toast(info.label + (" · 新的发现，经验 +1" if info.first else " · 你记得这里"))
	sound.cue("paper")

func show_choices() -> void:
	if s.observed.size() < 2:
		toast("再看一看周围。至少观察两处，再决定如何行动。")
		reveal = true
		update_spots()
		return
	shade("choices",0.32)
	choices_open = true
	UI.panel(overlay,Rect2(965,457,865,541),Color("172127f5"),7)
	label(overlay,"你准备怎么做？",Rect2(1010,494,730,55),32)
	var idx = 0
	for skill in Catalog.SKILLS:
		var have = Journey.model.stat(skill)
		var need = Journey.model.required(skill)
		var action_text = Journey.model.current().choices[skill]
		button(overlay,action_text,Rect2(1010,569+idx*119,767,64),func(): commit_choice(skill),"Choice_"+skill)
		label(overlay,"%s %d / %d   ·   %s" % [Catalog.SKILLS[skill],have,need,"身体记得该怎么做" if have >= need else "能力不足，仍可冒险"],Rect2(1021,638+idx*119,745,32),20,GREEN if have>=need else Color("daa38b"))
		idx += 1
	button(overlay,"×",Rect2(1750,480,50,50),func(): choices_open=false; close_modal(),"CloseChoices")

func commit_choice(skill: String) -> void:
	if s.timer < 2: toast("先稳住呼吸。"); return
	var outcome = Journey.model.attempt(skill)
	if outcome.is_empty(): return
	sound.cue("success" if outcome.won else "return")
	choices_open = false
	render()
	if s.mode == "ENDING": Journey.persist()
	else: fade_in()

func confirm_withdraw() -> void:
	shade("withdraw")
	UI.panel(overlay,Rect2(550,350,820,340),Color("172127"),10)
	label(overlay,"沿着记得的路退回去？",Rect2(610,390,700,60),32)
	label(overlay,"保留已经发现的线索。出门消耗的补给不会退还。",Rect2(610,467,700,70),25)
	button(overlay,"继续观察",Rect2(610,590,320,60),close_modal,"Stay")
	button(overlay,"回到家中",Rect2(950,590,320,60),func(): Journey.model.withdraw(); render(),"Retreat")

func show_result() -> void:
	shade("result",0.58)
	var r: Dictionary = s.result
	if r.is_empty(): return
	UI.panel(overlay,Rect2(315,130,1290,817),PAPER,2)
	var index: int = int(r.stage)
	draw_memory_slice(overlay,index,Rect2(352,178,602,583))
	label(overlay,"又回到了家。",Rect2(1010,184,540,64),36,INK)
	label(overlay,Journey.model.nodes[index].name,Rect2(1010,263,520,46),24,FADED)
	label(overlay,r.text,Rect2(1010,340,520,215),27,INK)
	label(overlay,"经验 +%d" % int(r.xp),Rect2(1010,578,500,44),31,Color("51725f"))
	label(overlay,r.hint if not r.won else ("新的突破已记入漫画册。" if r.breakthrough else "熟悉的路线，稳定的收获。"),Rect2(1010,645,500,140),22,FADED)
	label(overlay,"这段经历只记一次。突破，会让它多出新的意义。",Rect2(352,803,615,88),21,FADED)
	button(overlay,"合上这一页",Rect2(1010,815,520,66),func(): s.auto=false; Journey.model.return_home(); render(),"ResultContinue",true)
	if s.auto: label(overlay,"重复探索将在片刻后继续。点击合页可停下。",Rect2(1010,904,560,35),18,FADED)

func show_phone() -> void:
	shade("phone",0.3)
	UI.panel(overlay,Rect2(1150,64,620,964),Color("030709"),42,Color("6c7270"))
	UI.panel(overlay,Rect2(1170,84,580,916),Color("152225"),30)
	UI.line(overlay,Rect2(1370,99,178,8),Color("020406"))
	label(overlay,"23:59                         无服务",Rect2(1203,127,510,35),20,Color("a4b6b7"))
	label(overlay,"身体记得",Rect2(1213,198,490,65),43)
	label(overlay,"经验  %d     /     补给  %.0f%%" % [s.xp,s.food],Rect2(1213,276,490,45),26,GREEN)
	var index = 0
	for skill in Catalog.SKILLS:
		var level: int = s.skills[skill]
		var y = 355 + index*159
		label(overlay,Catalog.SKILLS[skill]+"   "+str(level+1),Rect2(1213,y,460,48),32)
		label(overlay,["辨认反常的细节","把经验变成力量","活到规则的尽头"][index],Rect2(1213,y+58,330,35),20,Color("8fa5a4"))
		var b = button(overlay,"已完成" if level>=6 else "%d 经 验  ↑"%Catalog.COSTS[level],Rect2(1482,y+53,220,58),func(): if Journey.model.upgrade(skill): show_phone(); sound.cue("success"),"Upgrade_"+skill)
		b.disabled = level>=6 or (level<6 and s.xp<Catalog.COSTS[level]) or s.mode not in ["HOME","WAIT","RESULT"]
		index+=1
	button(overlay,"补充食物   3 经验 / 35 补给",Rect2(1210,854,494,64),func(): if Journey.model.supply(): show_phone(); toast("冰箱里多了足够下一段路的食物。"),"SupplyPhone").disabled = s.xp<3 or s.food>65 or s.mode not in ["HOME","WAIT","RESULT"]
	label(overlay,"补给低于 65 时可补充；探索与居家时缓慢消耗。",Rect2(1210,935,500,48),17,Color("8fa5a4"))
	button(overlay,"×",Rect2(1790,83,60,56),close_modal,"ClosePhone")

func show_supply() -> void:
	shade("supply",0.45)
	UI.panel(overlay,Rect2(570,238,780,610),PAPER,3)
	label(overlay,"冰箱里的食物",Rect2(633,287,650,66),37,INK)
	label(overlay,"剩余  %.0f%%" % s.food,Rect2(633,398,650,80),57,Color("5d7966"))
	label(overlay,"门外的经历可以换来新的补给。\n3 点经验，补充 35 点食物。\n\n补给耗尽后，本次游戏结束，从存档重新继续。",Rect2(633,505,650,179),24,INK)
	button(overlay,"取出新的食物",Rect2(633,737,365,62),func(): if Journey.model.supply(): show_supply(); sound.cue("success"),"Supply",true).disabled=s.food>65 or s.xp<3 or s.mode not in ["HOME","WAIT","RESULT"]
	button(overlay,"关上冰箱",Rect2(1020,737,260,62),close_modal,"CloseSupply",true)

func draw_door_progress() -> void:
	if s.mode=="AUTO":
		UI.panel(stage,Rect2(1100,153,276,642),Color("e9e7de"),0)
		draw_memory_panel(stage,int(s.selected),0,Rect2(1107,160,262,304))
		auto_second=draw_memory_panel(stage,int(s.selected),1,Rect2(1107,475,262,304))
	add_spot(stage,"门缝里的记忆",Rect2(1100,153,276,642),show_monitor)
	progress_text = label(stage,"",Rect2(1065,823,405,68),23,Color("eae9de"))
	UI.panel(stage,Rect2(1072,822,392,116),Color("142024dd"),3)
	stage.move_child(progress_text,stage.get_child_count()-1)
	progress_text.position=Vector2(1090,835)
	UI.line(stage,Rect2(1090,909,355,3),Color("526367"))
	progress_width = 355
	progress_bar = UI.line(stage,Rect2(1090,909,1,3),GREEN)

func show_monitor() -> void:
	shade("monitor",0.63)
	UI.panel(overlay,Rect2(243,105,1434,854),Color("090e13"),16,Color("596062"))
	label(overlay,"门 的 另 一 面",Rect2(305,156,1200,52),32)
	if s.mode=="AUTO":
		draw_memory_panel(overlay,int(s.selected),0,Rect2(307,239,418,478))
		auto_second=draw_memory_panel(overlay,int(s.selected),1,Rect2(737,239,418,478))
	elif s.mode=="WAIT":
		UI.panel(overlay,Rect2(307,239,850,478),Color("0b131a"),0)
		label(overlay,"门外传来了陌生的声音。",Rect2(426,438,661,73),35,Color("809394"))
	else:
		picture(overlay,Catalog.asset("home","entry"),Rect2(307,239,850,478))
	progress_text = label(overlay,"",Rect2(309,739,850,75),25,GREEN)
	UI.line(overlay,Rect2(309,827,847,5),Color("334549"))
	progress_width=847
	progress_bar = UI.line(overlay,Rect2(309,827,1,5),GREEN)
	label(overlay,"行动习惯",Rect2(1205,247,400,46),29)
	var k=0
	for skill in Catalog.SKILLS:
		button(overlay,("●  " if s.focus==skill else "○  ")+Catalog.SKILLS[skill],Rect2(1205,320+k*76,404,60),func(): s.focus=skill; show_monitor(),"Focus_"+skill)
		k+=1
	button(overlay,"连续向前" if s.chain else "循环当前路线",Rect2(1205,574,404,60),func(): s.chain=not s.chain; show_monitor(),"AutoMode")
	label(overlay,"连续向前：已知路段自动走，\n遇到新内容停下，等待你接手。\n等待时不消耗补给。",Rect2(1205,657,400,132),22,Color("9caeb0"))
	if s.mode in ["WAIT","AUTO"]:
		button(overlay,"亲自接手",Rect2(310,865,400,59),func(): Journey.model.take_control(); render(),"TakeControl")
		button(overlay,"停止并回家",Rect2(736,865,420,59),func(): Journey.model.withdraw(); render(),"StopAuto")
	else:
		label(overlay,"还没有出门。转动门把手，选择下一段路。",Rect2(310,867,850,60),24,Color("9caeb0"))
	button(overlay,"×",Rect2(1692,112,62,56),func(): close_modal(); show_room(),"CloseMonitor")

func memory_texture(index: int, panel_index: int = -1) -> Texture2D:
	var path = Catalog.asset("memories","chapter%d"%(index/3+1))
	if not ResourceLoader.exists(path): return null
	var source: Texture2D = load(path)
	var tex = AtlasTexture.new()
	tex.atlas = source
	var rows=[[[0.004,0.322],[0.328,0.629],[0.638,0.995]],[[0.004,0.325],[0.332,0.629],[0.639,0.995]],[[0.004,0.337],[0.346,0.661],[0.672,0.995]]]
	var bounds: Array=rows[index/3][index%3]
	tex.region=Rect2(0,float(bounds[0])*source.get_height(),source.get_width(),(float(bounds[1])-float(bounds[0]))*source.get_height())
	if panel_index>=0:
		tex.region.position.x=source.get_width()*0.5*panel_index
		tex.region.size.x=source.get_width()*0.5
	return tex

func draw_memory_panel(parent: Node, index: int, panel_index: int, rect: Rect2) -> TextureRect:
	var pic=TextureRect.new()
	UI.place(pic,parent,rect)
	pic.texture=memory_texture(index,panel_index)
	pic.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return pic

func draw_memory_slice(parent: Node, index: int, rect: Rect2) -> void:
	var pic = TextureRect.new()
	UI.place(pic,parent,rect)
	pic.texture=memory_texture(index)
	pic.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.mouse_filter=Control.MOUSE_FILTER_IGNORE

func show_memories(index: int = -1) -> void:
	if index >= 0: memory_index=index
	shade("memories",0.69)
	UI.panel(overlay,Rect2(184,71,1552,942),Color("544d41"),5)
	UI.panel(overlay,Rect2(211,53,1498,930),PAPER,2)
	UI.line(overlay,Rect2(938,60,3,907),Color("c9c2b0"))
	label(overlay,"留 在 家 里 的 记 忆",Rect2(264,103,640,50),30,INK)
	for i in Journey.model.nodes.size():
		var known = s.memories.has(str(i))
		var node = Journey.model.nodes[i]
		var value = "%02d    %s"%[i+1,node.name if known else "还没有这一页"]
		var b=button(overlay,value,Rect2(264,192+i*73,620,58),func(): show_memories(i),"Memory%d"%i,true)
		b.disabled=not known
		b.alignment=HORIZONTAL_ALIGNMENT_LEFT
		if i==memory_index: b.add_theme_stylebox_override("normal",UI.box(Color("c8d4c8"),Color("809381"),2))
	label(overlay,"相同的经历不会重复收录。新的突破会留下批注。",Rect2(264,891,620,58),20,FADED)
	if s.memories.has(str(memory_index)):
		var record: Dictionary=s.memories[str(memory_index)]
		draw_memory_slice(overlay,memory_index,Rect2(988,107,668,444))
		label(overlay,Journey.model.nodes[memory_index].name,Rect2(1000,574,633,52),33,INK)
		label(overlay,Journey.model.nodes[memory_index].memory if record.won else "画面在这里中断了。你还记得那种感觉。\n\n"+Journey.model.nodes[memory_index].hint[s.failures.get(str(memory_index),"perception")],Rect2(1000,655,633,178),26,INK)
		label(overlay,"已突破 · "+Catalog.SKILLS[record.route] if record.won else "未完成的记忆",Rect2(1000,866,633,58),23,Color("52735e"))
	else:
		label(overlay,"这一页，还是空白。",Rect2(1030,365,590,150),39,INK)
		label(overlay,"从门外带回的经历，会留在这里。",Rect2(1030,535,590,130),25,FADED)
	button(overlay,"×",Rect2(1750,68,60,58),close_modal,"CloseMemories")

func show_pause() -> void:
	Journey.paused=true
	shade("pause",0.70)
	UI.panel(overlay,Rect2(531,129,858,830),Color("172225"),13,Color("526564"))
	label(overlay,"让时间停一会儿",Rect2(600,179,720,64),40)
	label(overlay,"暂停、阅读新事件的等待、窗口失去焦点时，资源不消耗。",Rect2(600,267,718,92),23,Color("a1b3b0"))
	label(overlay,"声音",Rect2(600,385,140,40),25)
	var slider=HSlider.new()
	UI.place(slider,overlay,Rect2(782,385,500,46))
	slider.min_value=0; slider.max_value=1; slider.step=0.05; slider.value=s.volume
	slider.value_changed.connect(func(v): s.volume=v; Journey.apply_settings())
	button(overlay,"全屏："+("开" if s.fullscreen else "关"),Rect2(600,471,320,56),func(): s.fullscreen=not s.fullscreen; Journey.apply_settings(); show_pause(),"Fullscreen")
	button(overlay,"镜头过渡："+("开" if s.motion else "关"),Rect2(958,471,320,56),func(): s.motion=not s.motion; show_pause(),"Motion")
	button(overlay,"文字："+("立即显示" if s.text_speed==0 else "逐字显示"),Rect2(600,551,678,56),func(): s.text_speed=0.025 if s.text_speed==0 else 0; show_pause(),"TextSpeed")
	label(overlay,"每 20 分钟自动存档，保留三个轮换备份。\n存档时间："+str(s.saved_at),Rect2(600,644,718,88),23,Color("a1b3b0"))
	if Journey.fault!="": label(overlay,Journey.fault,Rect2(600,737,718,64),22,Color("e1ac96"))
	button(overlay,"继续",Rect2(600,823,205,63),resume_play,"Resume")
	button(overlay,"保存并离开",Rect2(824,823,234,63),save_quit,"SaveQuit").disabled=not Journey.started or s.mode=="GAMEOVER"
	button(overlay,"返回标题",Rect2(1078,823,200,63),return_title,"Title")

func save_quit() -> void:
	if Journey.persist(): get_tree().quit()
	else: show_pause()

func resume_play() -> void:
	Journey.paused=false
	if Journey.started: render()
	else: show_title()

func return_title() -> void:
	if Journey.started and s.mode!="GAMEOVER" and not Journey.persist(): show_pause(); return
	Journey.started=false
	Journey.paused=false
	show_title()

func show_gameover() -> void:
	close_modal()
	reset_view("gameover")
	picture(stage,Catalog.asset("home","entry"),Rect2(0,0,1920,1080)).modulate=Color("495159")
	UI.line(stage,Rect2(0,0,1920,1080),Color("0a101cd0"))
	label(stage,"灯灭了。",Rect2(570,282,800,112),79)
	label(stage,"GAME OVER",Rect2(575,417,740,50),27,Color("aeb8b9"))
	label(stage,"食物已经耗尽。最后的记忆还在。\n这次中断不会覆盖之前的存档。",Rect2(575,514,820,136),29)
	button(stage,"从最后一次记录继续",Rect2(575,724,770,70),reload_game,"Reload")
	button(stage,"返回标题",Rect2(575,818,770,60),return_title,"GameoverTitle")

func reload_game() -> void:
	if Journey.reload_checkpoint(): render()
	else: toast(Journey.fault)

func show_ending() -> void:
	close_modal()
	reset_view("ending")
	var final_path=Catalog.asset("world","ending")
	picture(stage,final_path if ResourceLoader.exists(final_path) else Catalog.asset("world","ledger"),Rect2(0,0,1920,1080))
	UI.line(stage,Rect2(0,740,1920,340),Color("0e1c24ea"))
	var lines=["笔落下。\n巡层员的名字，成为登记册的最后一行。", "它第一次想从门口逃走。\n可它亲手写下的规则，已经关上了门。", "整栋楼的房门同时打开。\n被抹掉的声音，一个一个回来了。", "你转动把手。楼下有人在喊收衣服。\n这一次，门外是七楼。"]
	label(stage,"最后一名住户",Rect2(97,777,1600,42),23,GREEN)
	label(stage,lines[mini(end_step,3)],Rect2(97,850,1450,145),35)
	button(stage,"继续  ›" if end_step<3 else "走出去",Rect2(1570,920,270,66),ending_next,"EndingNext")
	sound.ending=true

func ending_next() -> void:
	if end_step<3:
		end_step+=1
		show_ending()
		return
	s.ending_seen=true
	Journey.persist()
	shade("credits",0.63)
	UI.panel(overlay,Rect2(460,197,1000,682),PAPER,2)
	label(overlay,"这一次，你替所有人关上了门。",Rect2(525,260,870,123),43,INK)
	label(overlay,"无限异常  /  完整故事版\n\n九段经历，二十七处发现。\n每一次记住的细节，都把你带到了这里。\n\n故事与玩法依据你的规划制作。\n场景以你的家为原型；美术素材为本项目生成。",Rect2(525,420,860,280),25,INK)
	button(overlay,"翻看留下的漫画",Rect2(525,758,410,62),func(): show_memories(8),"FinalMemories",true)
	button(overlay,"回到标题",Rect2(960,758,420,62),return_title,"FinalTitle",true)

func update_spots() -> void:
	for p in spots:
		if is_instance_valid(p): p.reveal=reveal; p.queue_redraw()

func _process(delta: float) -> void:
	if is_instance_valid(auto_second): auto_second.modulate.a=1.0 if s.timer>=7.5 else 0.12
	if is_instance_valid(narration):
		narration_time+=delta
		narration.visible_characters=-1 if s.text_speed==0 else int(narration_time / maxf(0.001,s.text_speed))
	if is_instance_valid(toast_label):
		toast_time-=delta
		if toast_time<=0: toast_label.text=""
	if is_instance_valid(progress_text):
		match s.mode:
			"AUTO": progress_text.text=Journey.model.current().name+"\n"+["门缝里出现了熟悉的画面","越过了上一次停留的位置","这次，身体知道该怎么做"][mini(2,int(s.timer/5))]
			"WAIT": progress_text.text="前面是没见过的地方。\n等待你接手 · 补给消耗已暂停"
			_: progress_text.text="门外静悄悄的。"
	if is_instance_valid(progress_bar): progress_bar.size.x=progress_width*(clampf(float(s.timer)/15,0,1) if s.mode=="AUTO" else (1.0 if s.mode=="WAIT" else 0.0))

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_ESCAPE:
			if modal=="result":
				s.auto=false
				Journey.model.return_home()
				render()
			elif modal=="pause": resume_play()
			elif modal in ["rest","intro"]:
				Journey.paused=false
				close_modal()
			elif modal!="": close_modal()
			else: show_pause()
		KEY_TAB:
			reveal=not reveal
			update_spots()
			get_viewport().set_input_as_handled()
		KEY_P:
			if Journey.started and not Journey.paused and page=="home" and modal not in ["result","credits"]:
				if modal=="phone": close_modal()
				else: show_phone()
		KEY_F11:
			s.fullscreen=not s.fullscreen
			Journey.apply_settings()
		KEY_SPACE:
			if is_instance_valid(narration): narration_time=100000
		KEY_1,KEY_2,KEY_3:
			if modal=="choices": commit_choice(["perception","combat","survival"][event.keycode-KEY_1])

func capture_all() -> void:
	Journey.paused=true
	await capture("00-title")
	Journey.start_new()
	Journey.paused=true
	await capture("01-intro")
	close_modal()
	for room in Catalog.ROOM_NAMES:
		s.room=room
		show_room()
		await capture("home-"+room)
	s.room="entry"
	show_room()
	show_door()
	await capture("02-door")
	show_phone()
	await capture("03-phone")
	show_pause()
	await capture("04-pause")
	s.frontier=8
	s.skills={"perception":6,"combat":6,"survival":6}
	for index in 9:
		s.mode="HOME"
		s.selected=index
		Journey.model.depart(false)
		render()
		narration_time=1000
		await capture("world-%02d"%index)
		for point in 3: inspect_point(point)
		s.timer=3
		show_choices()
		if index==1: await capture("05-choice")
		Journey.model.attempt("perception")
		if index==0:
			render()
			await capture("06-result")
		Journey.model.return_home()
	s.mode="HOME"
	s.selected=0
	s.frontier=8
	s.chain=true
	Journey.model.depart(true)
	s.timer=7
	render()
	await capture("07-auto-door")
	show_monitor()
	await capture("08-monitor")
	s.mode="WAIT"
	show_monitor()
	await capture("09-new-story-wait")
	s.mode="HOME"
	show_memories(7)
	await capture("10-memories")
	s.mode="ENDING"
	end_step=3
	show_ending()
	await capture("11-ending")
	ending_next()
	await capture("12-credits")
	s.mode="GAMEOVER"
	show_gameover()
	await capture("13-gameover")
	print("CAMPAIGN_CAPTURE complete")
	get_tree().quit()

func capture(id: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var directory=ProjectSettings.globalize_path("res://.local/campaign-captures")
	DirAccess.make_dir_recursive_absolute(directory)
	var shot=get_viewport().get_texture().get_image()
	shot.save_png(directory.path_join(id+".png"))
