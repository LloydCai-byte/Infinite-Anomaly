extends Control
const Cosmos=preload("res://scripts/pixel_home/cosmos.gd")
const HEROES=["粉粉","高哥","七七","大东老师","老王"]
var home
var hero=0
var selected=0
var page=0
var confirm_salvage=false
var controls={}
var layer:Control
var message="每人可装一枚星核。原装备、卡牌与技能分支继续生效。"

func _init(owner_home) -> void:home=owner_home
func _ready() -> void:
	size=Vector2(1600,900);mouse_filter=MOUSE_FILTER_STOP;refresh()

func label(value:String,rect:Rect2,size_value:int=20,color=Color("c7d1dc")) -> Label:
	var c=Label.new();c.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;c.clip_text=true;c.text=value;c.position=rect.position
	c.add_theme_font_override("font",home.font);c.add_theme_font_size_override("font_size",size_value);c.add_theme_color_override("font_color",color)
	layer.add_child(c);c.size=rect.size;return c

func button(value:String,rect:Rect2,callback:Callable,key:String,disabled:bool=false,active:bool=false) -> Button:
	var c=home.add_button(value,callback,layer);c.position=rect.position;c.size=rect.size;c.disabled=disabled
	var style=home.style();style.content_margin_top=5;style.content_margin_bottom=5
	if active:style.bg_color=Color("28404d");style.border_color=Color("e6cc91")
	for state in ["normal","hover","pressed","disabled","focus"]:c.add_theme_stylebox_override(state,style)
	c.size=rect.size;controls[key]=c;return c

func changed(ok:bool,success:String) -> void:
	message=success if ok else home.gear.last_error if home.gear.last_error!="" else "当前无法执行此操作。"
	confirm_salvage=false;refresh()

func refresh() -> void:
	if is_instance_valid(layer):remove_child(layer);layer.queue_free()
	layer=Control.new();layer.size=size;layer.mouse_filter=MOUSE_FILTER_IGNORE;add_child(layer);controls={}
	var shade=ColorRect.new();shade.color=Color("0d141e");shade.size=size;shade.mouse_filter=MOUSE_FILTER_IGNORE;layer.add_child(shade)
	var state=home.gear.cosmos
	label("星际整备",Rect2(55,28,420,55),32,Color("edd29e"))
	label("星尘 %d   ·   星球阅历 %d"%[state.stardust,state.mastery],Rect2(640,36,570,48),21)
	button("返回房间 [Esc]",Rect2(1295,28,250,48),home.close_cosmos,"close")
	for i in range(5):
		var h=i
		button(HEROES[i],Rect2(55+i*300,102,280,48),func():hero=h;confirm_salvage=false;refresh(),"hero_%d"%i,false,hero==i)
	label("星核仓库 · %d枚"%state.inventory.size(),Rect2(55,180,440,42),23)
	label(HEROES[hero]+"的星核",Rect2(540,180,430,42),23,Color("edd29e"))
	label("星际技能 · 每景每3次行动触发",Rect2(1015,180,540,42),23,Color("9cd4df"))
	page=clampi(page,0,maxi(0,ceili(state.inventory.size()/10.0)-1))
	for i in range(10):
		var offset=page*10+i
		if offset>=state.inventory.size():break
		var core=state.inventory[offset];var id=int(core.id);var who=Cosmos.owner(state,id)
		var title=Cosmos.title(core)+(" · "+HEROES[who] if who>=0 else "")+(" · 锁" if core.locked else "")
		button(title,Rect2(55,236+i*51,435,44),func():selected=id;confirm_salvage=false;refresh(),"core_%d"%id,false,id==selected).add_theme_font_size_override("font_size",18)
	button("上一页",Rect2(55,770,140,44),func():page-=1;refresh(),"previous",page==0)
	label("%d / %d"%[page+1,maxi(1,ceili(state.inventory.size()/10.0))],Rect2(220,775,140,40),18)
	button("下一页",Rect2(350,770,140,44),func():page+=1;refresh(),"next",(page+1)*10>=state.inventory.size())
	var equipped=Cosmos.item(state,state.slots[hero])
	label("已装配："+("空" if equipped.is_empty() else Cosmos.title(equipped)),Rect2(540,235,420,65),20)
	var core=Cosmos.item(state,selected)
	if core.is_empty():
		label("选择左侧星核查看词条。\n\n星球战斗会掉落星核与星尘。\n星尘可强化星核，最高阶3。\n\n返家后可自由装配、转交和切换技能。",Rect2(540,320,410,310),22)
	else:
		label(Cosmos.title(core),Rect2(540,315,420,50),25,Color(Cosmos.catalog().core_types[core.kind].color))
		label(Cosmos.description(core),Rect2(540,375,420,245),21)
		var owner=Cosmos.owner(state,core.id)
		button("转交给"+HEROES[hero] if owner>=0 and owner!=hero else "装配星核",Rect2(540,635,205,45),func():changed(home.gear.equip_core(core.id,hero),"已装配，下一场战斗生效。"),"equip",owner==hero)
		button("卸下",Rect2(760,635,205,45),func():changed(home.gear.equip_core(0,hero),"星核已放回仓库。"),"unequip",owner!=hero)
		button("已达最高阶" if core.rank==3 else "强化 · %d星尘"%Cosmos.upgrade_cost(core),Rect2(540,690,425,45),func():changed(home.gear.upgrade_core(core.id),"星核强化完成，词条品质保留。"),"upgrade",core.rank==3 or state.stardust<Cosmos.upgrade_cost(core))
		button("解除锁定" if core.locked else "锁定星核",Rect2(540,745,425,40),func():changed(home.gear.lock_core(core.id),"锁定状态已保存。"),"lock")
		button("再次确认分解" if confirm_salvage else "分解 · 获得%d星尘"%Cosmos.salvage_value(core),Rect2(540,793,425,40),func():
			if not confirm_salvage:confirm_salvage=true;refresh();return
			changed(home.gear.salvage_core(core.id),"分解完成，星尘已入库。"),"salvage",core.locked or owner>=0)
	for choice in range(3):
		var index=choice;var skill=Cosmos.catalog().skills[hero][choice];var enabled=Cosmos.skill_available(state,choice)
		var y=236+choice*195
		button(skill.name+(" · 已选择" if state.skills[hero]==choice else ""),Rect2(1015,y,530,44),func():changed(home.gear.choose_cosmic_skill(hero,index),"星际技能已切换，下一场战斗生效。"),"skill_%d"%choice,not enabled,state.skills[hero]==choice)
		label(skill.description,Rect2(1020,y+58,520,95),20)
		label("毕业后开放" if choice==0 else "累计通关%d个不同星球后开放"%int(Cosmos.catalog().skill_clear_thresholds[choice]),Rect2(1020,y+155,520,35),17,Color("83bfa7") if enabled else Color("9b9b9b"))
	label(message,Rect2(55,851,1490,38),18,Color("e5c691"))

func _unhandled_input(event:InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		home.close_cosmos();get_viewport().set_input_as_handled()
