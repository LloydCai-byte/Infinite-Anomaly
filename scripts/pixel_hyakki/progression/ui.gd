extends Control

const Rules=preload("res://scripts/pixel_hyakki/progression/rules.gd")
const HEROES=["粉粉","高哥","七七","大东老师","老王"]
const IDS=["fenfen","gao","qiqi","dadong","wang"]
const INK=Color("ece1cd")
const GOLD=Color("dcb373")
const MUTED=Color("aaa497")
var host
var gear
var controls={}
var tab=0
var toast=""

func setup(owner_view,store)->void:
	host=owner_view;gear=store;size=Vector2(1600,900);mouse_filter=Control.MOUSE_FILTER_STOP
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	refresh()

func panel(rect:Rect2,color:Color,border:Color)->void:
	var p=Panel.new();p.position=rect.position;p.size=rect.size;p.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var style=StyleBoxFlat.new();style.bg_color=color;style.border_color=border;style.set_border_width_all(2)
	p.add_theme_stylebox_override("panel",style);add_child(p)

func label(value:String,rect:Rect2,font_size:int=20,color:Color=INK)->Label:
	var item=Label.new();item.text=value;item.position=rect.position;item.size=rect.size
	item.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;item.mouse_filter=Control.MOUSE_FILTER_IGNORE
	item.clip_text=true
	item.add_theme_font_override("font",host.font);item.add_theme_font_size_override("font_size",font_size);item.add_theme_color_override("font_color",color);add_child(item);return item

func button(value:String,rect:Rect2,fn:Callable,key:String,selected:bool=false,disabled:bool=false)->Button:
	var item=Button.new();item.text=value;item.position=rect.position;item.size=rect.size;item.disabled=disabled
	item.add_theme_font_override("font",host.font);item.add_theme_font_size_override("font_size",20)
	item.add_theme_color_override("font_color",GOLD);item.add_theme_color_override("font_disabled_color",MUTED)
	for state in ["normal","hover","pressed","disabled","focus"]:
		var style=StyleBoxFlat.new();style.bg_color=Color("4a3424") if selected or state=="hover" else Color("201d1b")
		style.border_color=GOLD if selected or state=="focus" else Color("655540");style.set_border_width_all(2)
		item.add_theme_stylebox_override(state,style)
	item.pressed.connect(fn);add_child(item);controls[key]=item;return item

func portrait(id:String,rect:Rect2)->void:
	var image=TextureRect.new();image.texture=host.texture(host.ART+"sprites/"+id+"/portrait.png")
	image.position=rect.position;image.size=rect.size;image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	image.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(image)

func room_progress()->bool:return gear.has_method("record_room_result")
func editable()->bool:
	if room_progress():return host.model.phase in ["ready","victory","defeat"] or (host.model.phase=="clear" and host.model.is_level_end())
	return host.model.phase!="fight"

func changed(message:String)->void:
	toast=message if gear.persist() else "保存失败："+gear.last_error
	refresh()

func choose_skill(hero:int,choice:int)->void:
	if editable() and gear.choose_mode(hero,choice):changed("已选择 "+HEROES[hero]+" · "+Rules.MODES[hero][choice])

func toggle_card(id:String)->void:
	if not editable():return
	var slots=gear.growth.slots.duplicate()
	if id in slots:slots.erase(id)
	elif slots.size()<Rules.MAX_SLOTS:slots.append(id)
	else:toast="已携带三张卡牌，请先卸下一张。";refresh();return
	if gear.choose_cards(slots):changed("卡牌配置已保存；下一场景生效。")

func refresh()->void:
	for child in get_children():remove_child(child);child.queue_free()
	controls={}
	panel(Rect2(0,0,1600,900),Color("11100f"),Color("11100f"))
	panel(Rect2(35,26,1530,845),Color("191817"),Color("806544"))
	label("成长档案",Rect2(65,42,400,55),38,GOLD)
	button("返回战斗 [G]",Rect2(1300,48,230,49),host.close_growth,"back")
	label("队伍 Lv.%d  ·  经验 %d / %d  ·  金币 %d"%[gear.s.level,gear.s.xp,gear.xp_required(),gear.s.gold],Rect2(65,103,1100,40),23)
	var bar=ProgressBar.new();bar.position=Vector2(65,152);bar.size=Vector2(1465,10);bar.max_value=gear.xp_required();bar.value=gear.s.xp;bar.show_percentage=false;bar.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(bar)
	for i in range(3):
		var next=i
		button(["技能分支","异常卡牌  %d / 7"%gear.owned_card_count(),"房间记录  %d"%gear.campaign.levels.size() if room_progress() else "探索记录  %d / 20"%gear.growth.scenes.size()][i],Rect2(65+i*345,183,325,45),func():tab=next;toast="";refresh(),"tab_%d"%i,tab==i)
	label("战斗中仅查看" if not editable() else "战斗外免费调整",Rect2(1180,187,345,40),20,MUTED)
	if tab==0:skills()
	elif tab==1:cards()
	else:records()
	label(toast if toast!="" else "等级与战利品持续保留；挑战失利不会清空已获得的成长。",Rect2(65,817,1460,43),18,GOLD)
	if gear.last_error!="":label(gear.last_error,Rect2(65,852,1460,28),16,Color("f1a38b"))

func skills()->void:
	var rank=gear.rank()
	label("技能阶段 %d / 5  ·  队伍 3、10、20、35、50 级提升；每人选择一个分支。"%rank,Rect2(65,241,1460,35),19,MUTED)
	for h in range(5):
		var hero=h;var y=289+h*102
		panel(Rect2(65,y,1465,94),Color("24211d"),Color("4b4032"))
		portrait(IDS[h],Rect2(80,y+17,60,60));label(HEROES[h],Rect2(153,y+15,170,55),22,GOLD)
		for branch in range(2):
			var choice=branch;var x=330+branch*600
			button(Rules.MODES[h][branch],Rect2(x,y+7,145,32),func():choose_skill(hero,choice),"skill_%d_%d"%[h,branch],rank>0 and gear.mode(h)==branch,not editable() or rank==0)
			label(Rules.skill_description(h,branch,maxi(1,rank)),Rect2(x,y+45,575,46),16)
	if rank==0:toast="队伍 3 级解锁技能分支；以下展示首阶效果。"

func cards()->void:
	label("已携带 %d / 3  ·  只有携带的卡牌生效；累计 1 / 3 / 8 / 20 / 40 张升至 1—5 阶。"%gear.growth.slots.size(),Rect2(65,241,1460,36),19,MUTED)
	for i in range(Rules.CARD_IDS.size()):
		var id=Rules.CARD_IDS[i];var record=gear.growth.cards.get(id,{"copies":0,"kills":0,"misses":0})
		var rank=Rules.card_rank(record.copies);var active=id in gear.growth.slots
		var x=65+(i%4)*370;var y=292+int(i/4)*250
		panel(Rect2(x,y,355,234),Color("2c241c") if active else Color("211e1a"),GOLD if active else Color("554736"))
		if i<5:portrait(id,Rect2(x+14,y+12,40,40))
		label(Rules.CARD_NAMES[i],Rect2(x+(70 if i<5 else 16),y+12,275,34),22,GOLD)
		label("%d 阶 · 累计 %d 张"%[rank,record.copies] if rank>0 else "尚未获得 · 首阶效果预览",Rect2(x+16,y+55,325,28),17,MUTED)
		label(Rules.card_description(id,maxi(1,rank)),Rect2(x+16,y+89,325,60),18)
		var next=Rules.CARD_THRESHOLDS[rank]-record.copies if rank<5 else 0
		var source="击败同种敌人：6%%；距保底至多 %d 次"%(Rules.CARD_PITY-record.misses) if i<5 else "完整通关「%s」必得一张"%Rules.CARD_NAMES[i]
		label(source+ ("\n下一阶还需 %d 张"%next if rank<5 and rank>0 else "\n已达最高阶" if rank==5 else ""),Rect2(x+16,y+145,325,47),15,MUTED)
		button("卸下" if active else "携带" if rank>0 else "未获得",Rect2(x+16,y+195,323,29),func():toggle_card(id),"card_"+id,active,not editable() or rank==0).add_theme_font_size_override("font_size",17)

func room_records()->void:
	label(gear.Campaign.GOLD_RULE,Rect2(65,241,1460,45),19,MUTED)
	var scroll=ScrollContainer.new();scroll.position=Vector2(65,295);scroll.size=Vector2(1465,492);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;add_child(scroll)
	var list=VBoxContainer.new();list.size_flags_horizontal=SIZE_EXPAND_FILL;list.add_theme_constant_override("separation",12);scroll.add_child(list)
	var known=gear.encountered_levels(host.model.level_defs)
	for level in host.model.level_defs:
		var id=int(level.get("room_id",0))
		if id not in known:continue
		var record=gear.campaign.levels.get(gear.Campaign.key(id),{});var mark=gear.Campaign.badge(record)
		var row=Label.new();row.custom_minimum_size=Vector2(1420,42);row.add_theme_font_override("font",host.font);row.add_theme_font_size_override("font_size",21)
		row.add_theme_color_override("font_color",Color("bdf1ff") if mark=="shimmer" else GOLD if mark=="gold" else Color("c3d4e2") if mark=="silver" else INK)
		row.text="%03d   ·   %s   ·   %d/10种难度"%[id,gear.Campaign.badge_title(mark),gear.Campaign.difficulty_count(record)]
		list.add_child(row)
	if known.is_empty():
		var row=Label.new();row.text="抵达过的房间和完成的难度会记录在这里。";row.add_theme_font_override("font",host.font);row.add_theme_font_size_override("font_size",21);list.add_child(row)

func records()->void:
	if room_progress():room_records();return
	label("最高通关强度 %d  ·  已开放 1—%d 档  ·  建议回刷 %d 档，可自行选择更低强度。"%[gear.best_depth(),gear.unlocked_depth(),maxi(1,gear.best_depth()-2)],Rect2(65,241,1460,35),19,MUTED)
	for world in range(2):
		var id=["hyakki","sleepbeast"][world];var level=host.model.level_defs[world];var x=65+world*750
		var total=gear.growth.worlds.get(id,{}).get("clears",0)
		label(level.title+"  ·  完整通关 %d 次"%total,Rect2(x,285,715,45),25,GOLD)
		for i in range(level.scenes.size()):
			var scene=level.scenes[i];var record=gear.growth.scenes.get(id+":"+scene.id,{})
			panel(Rect2(x,339+i*45,715,40),Color("24211d"),Color("40382c"))
			label("%02d  %s"%[i+1,scene.title],Rect2(x+12,342+i*45,385,35),18)
			label("未通关" if record.is_empty() else "最高 %d 档 · %d 次"%[record.best_depth,record.clears],Rect2(x+410,342+i*45,295,35),18,MUTED if record.is_empty() else GOLD)
