extends Control
signal closed
signal feedback(message: String)
signal memory_requested(index: int)
const UI = preload("res://scripts/home/ui.gd")
var page: String = "home"
var selected: String = ""
var screen: Panel
var body: Control
var food_label: Label
var xp_label: Label
var status_label: Label
var food_bar: ColorRect
var last_mode: String = ""
var last_xp: int = -1
var notice: String = ""
var notice_label: Label

func _ready() -> void:
	size = Vector2(1920,1080)
	theme = UI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	UI.line(self,Rect2(0,0,1920,1080),Color(0.015,0.023,0.02,0.20))
	var shadow = UI.panel(self,Rect2(1230,41,626,1002),Color(0,0,0,0.32),50)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.panel(self,Rect2(1244,35,604,1000),Color("#080c0d"),48,Color("#626b67"))
	screen = UI.panel(self,Rect2(1260,53,572,964),UI.SCREEN,36,Color("#28352e"))
	UI.panel(screen,Rect2(220,12,132,20),Color("#050809"),12)
	UI.text(screen,"23:59",Rect2(25,12,120,26),17)
	UI.text(screen,"—  ·  ◉",Rect2(451,12,97,26),17)
	UI.button(screen,"×",Rect2(494,56,48,40),func():closed.emit())
	UI.text(screen,"无  名  连  接",Rect2(27,55,390,40),24,UI.INK)
	food_label = UI.text(screen,"",Rect2(27,106,285,30),19,UI.MUTED)
	xp_label = UI.text(screen,"",Rect2(320,106,225,30),19,UI.ACCENT)
	UI.line(screen,Rect2(27,145,516,1),Color("#36443b"))
	body = Control.new()
	UI.place(body,screen,Rect2(27,170,518,665))
	notice_label = UI.text(screen,"",Rect2(27,837,518,35),18,UI.GOLD)
	var names: Array = [["home","连接"],["skills","成长"],["memories","记忆"],["supply","补给"]]
	for i in range(names.size()):
		var item: Array = names[i]
		var b = UI.button(screen,item[1],Rect2(25+i*134,882,121,44),func():page=item[0];selected="";notice="";render())
		b.name = "PhoneTab_"+item[0]
		b.add_theme_font_size_override("font_size",20)
	UI.line(screen,Rect2(215,945,145,4),Color("#69756e"))
	Home.event.connect(on_event)
	render()

func _process(_delta: float) -> void:
	var s: Dictionary = Home.model.s
	food_label.text = "生活储备  %05.1f / 100" % s.food
	food_label.add_theme_color_override("font_color",UI.WARNING if s.food < 25 else UI.MUTED)
	xp_label.text = "经验  %d" % s.xp
	notice_label.text = notice
	if is_instance_valid(food_bar):
		food_bar.size.x = 518 * float(s.food) / 100.0
	if is_instance_valid(status_label):
		status_label.text = "记忆接收中  %02d:%02d" % [int(ceil(s.remaining))/60,int(ceil(s.remaining))%60] if s.mode == "MEMORY" else ("自动出门  ·  %d 秒" % int(ceil(s.auto_wait)) if s.auto else "房门在等你。")

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and event.position.x < 1210:
		closed.emit()
		accept_event()

func on_event(kind: String) -> void:
	if kind in ["settled","departed","restored","upgrade","supply","absorb","absorb_all"]:
		call_deferred("render")

func act(action: String, arg: String = "") -> void:
	if Home.action(action,arg):
		match action:
			"upgrade": notice = "身体记住了。下一次出门时生效。"
			"supply": notice = "厨房里，多了一些足够生活的食物。"
			"absorb","absorb_all": notice = "重复经历已吸收，首份记忆仍然保留。"
		feedback.emit(notice)
	else:
		notice = "暂时无法完成，请检查条件。"
	call_deferred("render")

func render() -> void:
	if not is_instance_valid(body):
		return
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	food_bar = null
	status_label = null
	match page:
		"home": draw_home()
		"skills": draw_skills()
		"memories": draw_memories()
		"supply": draw_supply()

func draw_home() -> void:
	var s: Dictionary = Home.model.s
	UI.text(body,"第 %03d 个你" % s.generation,Rect2(0,0,518,50),34)
	UI.text(body,"信号无法到达外面。\n这里却一直保持连接。",Rect2(0,66,518,80),22,UI.MUTED,true)
	status_label = UI.text(body,"",Rect2(0,161,518,37),24,UI.ACCENT)
	UI.text(body,"%s · %s" % [Home.model.db.episode.name,Home.model.current_stage().name],Rect2(0,203,518,31),20,UI.MUTED)
	var apps: Array = [
		["skills","Ⅰ","身体记住了","战斗 / 感知 / 生存"],
		["memories","Ⅱ","留在你身上的事","%d / 6 份记忆" % s.cards.size()],
		["supply","Ⅲ","维持生活","食物自动消耗，补给由你决定"]]
	for i in range(apps.size()):
		var a: Array = apps[i]
		var y: float = 264+i*115
		var b = UI.button(body,"",Rect2(0,y,518,96),func():page=a[0];notice="";render())
		b.name = "App_"+a[0]
		UI.text(b,a[1],Rect2(20,19,48,45),31,UI.ACCENT)
		UI.text(b,a[2],Rect2(83,11,380,38),25)
		UI.text(b,a[3],Rect2(83,53,397,29),18,UI.MUTED)
	UI.text(body,"P 收起手机  ·  房门展示探索记忆",Rect2(0,629,518,30),18,UI.MUTED)

func draw_skills() -> void:
	var m = Home.model
	UI.text(body,"身体记住了",Rect2(0,0,518,49),32)
	UI.text(body,"升级需要经验。不同路径都能越过异常。",Rect2(0,54,518,41),19,UI.MUTED,true)
	var i: int = 0
	for branch in m.db.branches:
		var info: Dictionary = m.db.branches[branch]
		var x: float = i*176
		var tint = Color(info.color)
		var focus = UI.button(body,info.name+"  %d" % m.stats()[branch],Rect2(x,110,165,55),func():act("focus",branch))
		focus.name = "Focus_"+branch
		focus.add_theme_stylebox_override("normal",UI.box(Color("#293731") if m.s.focus==branch else UI.PANEL,tint,12))
		UI.text(body,"优先路径" if m.s.focus==branch else info.verb,Rect2(x,174,165,30),18,tint)
		for n in range(3):
			UI.line(body,Rect2(x+80,214+n*135,2,30),Color("#48544b"))
			var owned: bool = int(m.s.skills[branch]) > n
			var next: bool = int(m.s.skills[branch]) == n
			var cost: int = m.db.balance.skill_costs[n]
			var b = UI.button(body,"",Rect2(x,239+n*135,165,108),func():act("upgrade",branch))
			b.name = "Skill_"+branch+"_"+str(n)
			b.disabled = not next or m.s.xp < cost or not m.can_act()
			if owned:
				b.add_theme_stylebox_override("disabled",UI.box(Color("#2b3931"),tint,12))
			UI.text(b,info.nodes[n],Rect2(10,11,148,35),21,tint if owned else UI.INK)
			UI.text(b,"已记住  ·  +1" if owned else ("经验 %d" % cost if next else "前置尚未记住"),Rect2(10,61,148,28),17,UI.MUTED)
			b.tooltip_text = info.effects[n]+("\n需要 %d 经验" % cost if next else "")
		i += 1
	UI.text(body,"出门时固定能力；接收中的记忆保持原样。",Rect2(0,627,518,35),18,UI.MUTED,true)

func draw_memories() -> void:
	var m = Home.model
	if selected != "":
		var index: int = m.card_ids().find(selected)
		if index >= 0 and m.s.cards.has(selected):
			var chapter: Dictionary = m.db.stages[index]
			UI.button(body,"‹  记忆册",Rect2(0,0,152,43),func():selected="";render())
			UI.button(body,"回看这一段",Rect2(329,0,189,43),func():memory_requested.emit(index))
			UI.image(body,"res://assets/memory/"+chapter.image+".png",Rect2(0,67,518,241))
			UI.text(body,chapter.memory,Rect2(0,331,518,45),31)
			UI.text(body,chapter.lore,Rect2(0,389,518,114),22,UI.MUTED,true)
			var copies: int = m.s.cards[selected]
			UI.text(body,"经历 %d 次  ·  永久保留 1 份" % copies,Rect2(0,515,518,35),20,UI.ACCENT)
			var absorb = UI.button(body,"吸收 %d 份重复记忆  ·  +%d 经验" % [maxi(0,copies-1),maxi(0,copies-1)*m.db.balance.absorb_xp],Rect2(0,573,518,61),func():act("absorb",selected),true)
			absorb.name = "AbsorbSelected"
			absorb.disabled = copies <= 1 or not m.can_act()
			return
	UI.text(body,"留在你身上的事",Rect2(0,0,518,47),30)
	UI.text(body,"每份经历都属于曾经的你。",Rect2(0,50,518,35),19,UI.MUTED)
	var duplicates: int = 0
	for value in m.s.cards.values():
		duplicates += maxi(0,int(value)-1)
	for i in range(m.db.stages.size()):
		var chapter: Dictionary = m.db.stages[i]
		var known: bool = m.s.cards.has(chapter.id)
		var x: float = (i%2)*269
		var y: float = 106+(i/2)*163
		var b = UI.button(body,"",Rect2(x,y,248,147),func():selected=chapter.id;render())
		b.name = "Memory_"+chapter.id
		b.disabled = not known
		if known:
			UI.image(b,"res://assets/memory/"+chapter.image+".png",Rect2(7,7,234,94))
			UI.text(b,chapter.memory,Rect2(11,106,186,30),19)
			UI.text(b,"×%d"%m.s.cards[chapter.id],Rect2(192,106,49,30),17,UI.ACCENT)
		else:
			UI.text(b,"%02d\n尚未经历"%(i+1),Rect2(20,27,210,90),22,UI.MUTED,true)
	var absorb = UI.button(body,"吸收全部重复记忆  ·  %d 份"%duplicates,Rect2(0,612,518,47),func():act("absorb_all"))
	absorb.disabled = duplicates == 0 or not m.can_act()
	absorb.name = "AbsorbAll"

func draw_supply() -> void:
	var m = Home.model
	UI.text(body,"让生活继续",Rect2(0,0,518,48),32)
	UI.text(body,"冰箱里的食物会自动消耗。\n你只需要决定何时补充。",Rect2(0,64,518,83),22,UI.MUTED,true)
	UI.image(body,"res://assets/home/kitchen.png",Rect2(0,173,518,244))
	UI.line(body,Rect2(0,441,518,7),Color("#344339"))
	food_bar = UI.line(body,Rect2(0,441,518*m.s.food/100.0,7),UI.ACCENT)
	UI.text(body,"生活储备  +25",Rect2(0,471,518,47),27)
	UI.text(body,"消耗 3 经验 · 最多储备 100\n储备耗尽后，需要从最近存档继续。",Rect2(0,524,518,75),20,UI.MUTED,true)
	var b = UI.button(body,"补充食物",Rect2(0,611,518,51),func():act("supply"),true)
	b.name = "Supply"
	b.disabled = m.s.xp < 3 or m.s.food >= 99.999 or not m.can_act()
	b.tooltip_text = "需要 3 经验" if m.s.xp < 3 else ("储备已满" if m.s.food >= 99.999 else "食物会直接出现在冰箱里")
