extends Control
var home
var next_button:Button
var resonance_buttons:Array=[]
var save_notice:Label
func _init(owner_home) -> void:home=owner_home
func label(value:String,rect:Rect2,point_size:int=22,color:Color=Color("d5dce3")) -> Label:
	var node=Label.new();node.text=value;node.position=rect.position;node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;node.clip_text=true
	node.add_theme_font_override("font",home.font);node.add_theme_font_size_override("font_size",point_size);node.add_theme_color_override("font_color",color);add_child(node);node.size=rect.size;return node
func button(value:String,rect:Rect2,action:Callable) -> Button:
	var node=home.add_button(value,action,self);node.position=rect.position;node.size=rect.size;return node
func _ready() -> void:refresh()
func refresh() -> void:
	for node in get_children():remove_child(node);node.queue_free()
	resonance_buttons=[];size=Vector2(1600,900);mouse_filter=MOUSE_FILTER_STOP
	var bg=ColorRect.new();bg.color=Color("10151f");bg.size=size;bg.mouse_filter=MOUSE_FILTER_IGNORE;add_child(bg)
	var gear=home.gear;var cycle=gear.campaign.cycle;var factor=gear.Cycles.difficulty(cycle)
	label("轮回档案 · "+("全剧终" if gear.cycles.game_complete else "第%d周目"%cycle),Rect2(65,35,1100,60),34,Color("e9cb94"))
	button("返回房间 [Esc]",Rect2(1275,35,265,48),home.close_cycles)
	label("当前敌人：生命 ×%.2f   攻击 ×%.2f    队伍 Lv.%d"%[factor.hp,factor.attack,gear.s.level],Rect2(65,108,1400,45),22)
	for i in range(3):
		var panel=Panel.new();panel.position=Vector2(65+i*500,175);panel.size=Vector2(470,230);panel.add_theme_stylebox_override("panel",home.style());panel.mouse_filter=MOUSE_FILTER_IGNORE;add_child(panel)
		var done=gear.cycles.history.size()>i
		var status="已完成" if done else "当前征途" if cycle==i+1 else "尚未抵达"
		label("第%d周目 · %s"%[i+1,status],Rect2(90+i*500,195,420,40),26,Color("e9cb94"))
		var descriptions=["地球训练 → 星球征途\n星核与星际技能\n摧毁当前航线的中枢","继承全部装备，等级回到1\n解锁第二支援槽\n解除其它征战航线","继承全部装备，等级回到1\n解锁三种记忆共鸣\n抵达源点，迎来完整结局"]
		label(descriptions[i],Rect2(90+i*500,253,415,135),22)
	label("保留的东西",Rect2(65,455,930,40),26,Color("e9cb94"))
	save_notice=label("",Rect2(65,417,1470,32),19,Color("f4a79a"))
	label("所有装备与星核、词条与锁定、当前穿戴、卡牌与培养、支援装置、材料与金币、已学技能和世界档案。\n\n新旅程从等级1、经验0开始。房间的十波通关与难度徽记重新计算，旧旅程另存完整档案；原有物品不会降级。",Rect2(65,513,945,205),24)
	label("记忆共鸣 · 三周目开放",Rect2(1090,452,450,40),24,Color("e9cb94"))
	for choice in range(3):
		var selected=choice;var info=gear.Cycles.catalog().resonances[choice]
		var node=button(("✓ " if gear.cycles.resonance==choice else "")+info.name,Rect2(1090,505+choice*66,450,54),func():
			if gear.choose_resonance(selected):refresh()
			else:save_notice.text="共鸣未保存："+gear.last_error)
		node.disabled=cycle<3;resonance_buttons.append(node)
	if cycle==3:label(gear.Cycles.catalog().resonances[gear.cycles.resonance].description,Rect2(1090,715,450,110),19)
	next_button=button("旅程已经完整结束" if gear.cycles.game_complete else "进入第%d周目"%(cycle+1) if cycle<3 else "最后一次征途",Rect2(65,765,470,62),func():home.close_cycles();home.confirm_next_cycle())
	next_button.disabled=not gear.can_start_cycle()
	label("完成当前周目结局后可开启下一次旅程。第三周目后不再轮回。",Rect2(565,774,475,80),20)
func _unhandled_input(event:InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:home.close_cycles();get_viewport().set_input_as_handled()
