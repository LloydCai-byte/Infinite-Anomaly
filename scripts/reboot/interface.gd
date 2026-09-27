extends RefCounted
const Art=preload("res://scripts/reboot/art.gd")
const C=preload("res://scripts/reboot/catalog.gd")
const INK=Color("e4e6d9")
const MUTED=Color("a2b5b0")
const ACCENT=Color("a5d6bd")
const GOLD=Color("e4c18a")
var g: Control
var live: Dictionary={}
var buttons: Dictionary={}
var form: LineEdit
var selected_gear=""
var recipe_role=0
var recipe_slot="weapon"
var recipe_mk=1
var talk_index=0
var gear_kind="weapon"

func _init(game: Control) -> void: g=game

func large() -> bool:
	return bool(g.settings_draft.get("large",g.model.s.settings.large)) if g.page=="settings" else bool(g.model.s.settings.large)

func clear(parent: Control) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func image(parent: Control, tex: Texture2D, r: Rect2, contain=false) -> TextureRect:
	var n=TextureRect.new()
	n.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	n.texture=tex
	n.position=r.position
	n.size=r.size
	n.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED if contain else TextureRect.STRETCH_SCALE
	n.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(n)
	return n

func panel(parent: Control,r: Rect2,style="panel") -> NinePatchRect:
	var n=NinePatchRect.new()
	n.texture=Art.ui(style)
	n.position=r.position
	n.size=r.size
	n.patch_margin_left=20
	n.patch_margin_top=20
	n.patch_margin_right=20
	n.patch_margin_bottom=20
	n.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(n)
	return n

func text(parent: Control, words: String,r: Rect2,fs=22,color=INK,align=HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var n=Label.new()
	n.text=words
	n.position=r.position
	n.size=r.size
	n.add_theme_font_size_override("font_size",fs+(2 if large() else 0))
	n.add_theme_color_override("font_color",color)
	n.horizontal_alignment=align
	n.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	n.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	n.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(n)
	return n

func style(name: String) -> StyleBoxTexture:
	var t=StyleBoxTexture.new()
	t.texture=Art.ui(name)
	for side in [SIDE_LEFT,SIDE_RIGHT]:
		t.set_texture_margin(side,20)
		t.set_content_margin(side,18)
	for side in [SIDE_TOP,SIDE_BOTTOM]:
		t.set_texture_margin(side,15)
		t.set_content_margin(side,9)
	return t

func button(parent: Control, id: String, title: String, r: Rect2, callback: Callable, icon="",kind="neutral",blocked=false) -> Button:
	var b=Button.new()
	b.name=id.validate_node_name()
	b.text=title
	b.position=r.position
	b.size=r.size
	b.disabled=blocked
	b.focus_mode=Control.FOCUS_ALL
	b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size",20+(2 if large() else 0))
	b.add_theme_color_override("font_color",INK)
	b.add_theme_color_override("font_hover_color",Color("ffffff"))
	b.add_theme_color_override("font_pressed_color",ACCENT)
	b.add_theme_color_override("font_disabled_color",Color("7c8c89"))
	for state in ["normal","hover","pressed","disabled","focus"]:
		b.add_theme_stylebox_override(state,style("button_"+kind+"_"+state))
	if icon!="":
		b.icon=Art.ui("icon_"+icon)
		b.expand_icon=true
		b.add_theme_constant_override("icon_max_width",26)
		b.add_theme_constant_override("h_separation",11)
	b.pressed.connect(func():
		g.auto_timer=-1
		g.play_sound("click")
		callback.call())
	parent.add_child(b)
	buttons[id]=b
	return b

func bar(parent: Control, r: Rect2, value: float, golden=false) -> TextureProgressBar:
	var n=TextureProgressBar.new()
	n.position=r.position
	n.size=r.size
	n.nine_patch_stretch=true
	n.stretch_margin_left=6
	n.stretch_margin_right=6
	n.stretch_margin_top=3
	n.stretch_margin_bottom=3
	n.texture_under=Art.ui("health_bg")
	n.texture_progress=Art.ui("progress_fill" if golden else "health_fill")
	n.value=clampf(value,0,100)
	n.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(n)
	return n

func separator(parent: Control,x: float,y: float,w: float) -> void:
	image(parent,Art.ui("separator"),Rect2(x,y,w,5))

func modal(title: String,subtitle: String="") -> Control:
	image(g.overlay,Art.ui("dim"),Rect2(0,0,1600,900))
	var blocker=Control.new()
	blocker.size=Vector2(1600,900)
	blocker.mouse_filter=Control.MOUSE_FILTER_STOP
	g.overlay.add_child(blocker)
	var p=panel(g.overlay,Rect2(120,106,1360,682))
	p.mouse_filter=Control.MOUSE_FILTER_STOP
	text(p,title,Rect2(38,20,1100,46),32)
	if subtitle!="": text(p,subtitle,Rect2(40,67,1210,36),19,MUTED)
	separator(p,38,108,1280)
	button(p,"back","",Rect2(1268,24,56,54),g.back,"close")
	return p

func draw() -> void:
	clear(g.ui_root)
	clear(g.overlay)
	live.clear()
	buttons.clear()
	form=null
	if g.view=="title": title_screen()
	elif g.view=="base": base_screen()
	else: battle_screen()
	match g.page:
		"slots": slots()
		"newsave": new_save()
		"delete": delete_save()
		"settings": settings()
		"intro": intro()
		"missions": missions()
		"ready": ready()
		"profile": profile()
		"equipment": equipment()
		"skills": skills()
		"training": training()
		"printer": printer()
		"facility": facility()
		"cards": cards()
		"card_detail": card_detail()
		"dialogue": dialogue()
		"result": result()
		"stats": stats()
		"recall": recall()
		"dismantle": dismantle()
		"pause": pause()
		"quit": quit_dialog()
		"recovery","save_error": recovery()
	refresh()

func title_screen() -> void:
	image(g.ui_root,Art.ui("vignette"),Rect2(0,0,1500,900))
	image(g.ui_root,Art.ui("emblem"),Rect2(99,101,106,106))
	text(g.ui_root,"INFINITE ANOMALY",Rect2(105,234,740,36),22,ACCENT)
	text(g.ui_root,"无限异常",Rect2(95,276,860,99),78)
	text(g.ui_root,"门外的世界，等你下达指令。",Rect2(103,392,750,40),25,MUTED)
	var recent=0
	var recent_time=0.0
	for n in range(1,4):
		var data=g.slot_store(n).load_primary()
		if float(data.get("saved_at",0))>recent_time:
			recent=n
			recent_time=data.saved_at
	if recent>0: button(g.ui_root,"continue","继续游戏",Rect2(105,485,300,64),func():g.load_game(recent),"play","primary")
	button(g.ui_root,"slots","开始新游戏" if recent==0 else "选择存档",Rect2(105,562 if recent>0 else 485,300,64),func():g.open("slots"),"door","primary" if recent==0 else "neutral")
	button(g.ui_root,"settings","设置",Rect2(105,639 if recent>0 else 562,300,64),func():g.open("settings"),"settings")
	button(g.ui_root,"quit","退出",Rect2(105,716 if recent>0 else 639,300,64),func():g.open("quit"),"exit")
	text(g.ui_root,"第一章 · 房间里的四个人",Rect2(103,825,870,32),19,MUTED)
	text(g.ui_root,"0.4.0",Rect2(1400,835,135,25),18,MUTED,HORIZONTAL_ALIGNMENT_RIGHT)

func topbar(title: String,subtitle: String) -> void:
	image(g.ui_root,Art.ui("topbar"),Rect2(0,0,1600,96))
	text(g.ui_root,title,Rect2(52,9,425,39),29)
	text(g.ui_root,subtitle,Rect2(53,47,515,26),18,MUTED)
	image(g.ui_root,Art.ui("icon_coin"),Rect2(1005,25,32,32))
	live.credits=text(g.ui_root,"",Rect2(1049,15,135,47),25,GOLD)
	image(g.ui_root,Art.ui("icon_alloy"),Rect2(1210,25,32,32))
	live.alloy=text(g.ui_root,"",Rect2(1257,15,130,47),25,ACCENT)
	button(g.ui_root,"menu","",Rect2(1490,17,60,53),func():g.open("pause"),"settings")

func base_screen() -> void:
	var m=g.model
	topbar(m.s.base_name,"整备室  /  基地 T%d  /  四名队员"%m.s.tier)
	var goal="从任务门出发，完成废弃地铁。"
	if m.s.wins.M01>0: goal="升级体质与装备，挑战封闭公寓。"
	if m.s.wins.M02>0: goal="清除高架桥底目标，解锁基地 T2。"
	if m.s.wins.M03>0: goal="升级基地 T2，继续收集金卡与钻石卡。"
	if m.active(): goal="小队出战中 · 可通过监控查看进度。"
	live.goal=text(g.ui_root,goal,Rect2(574,13,407,60),20,ACCENT)
	button(g.ui_root,"door_hotspot","任务门",Rect2(625,343,182,54),func():g.open("missions"),"door","primary")
	button(g.ui_root,"monitor_hotspot","战场监控" if m.active() else "任务档案",Rect2(867,244,174,50),func():
		if m.active():
			g.view="battle"
			g.render()
		else: g.open("cards"),"eye")
	button(g.ui_root,"printer_hotspot","装备打印",Rect2(1131,351,180,50),func():g.open("printer"),"printer")
	button(g.ui_root,"training_hotspot","训练舱",Rect2(1365,448,170,50),func():g.open("training"),"training")
	button(g.ui_root,"facility_hotspot","配电与设施",Rect2(865,415,180,50),func():g.open("facility"),"facility")
	if not m.active():
		for i in range(4):
			var x=[356,571,818,1033][i]
			button(g.ui_root,"person_%d"%i,C.PEOPLE[i].name,Rect2(x,652,174,49),func():select_person(i,"profile"),C.PEOPLE[i].icon)
	else:
		var p=panel(g.ui_root,Rect2(395,554,810,135))
		text(p,"队员正在执行任务",Rect2(25,16,475,44),27)
		live.base_battle=text(p,"",Rect2(25,62,470,40),20,MUTED)
		button(p,"view_battle","查看战斗",Rect2(554,39,220,59),func():g.view="battle";g.render(),"eye","primary")
	image(g.ui_root,Art.ui("bottom_bar"),Rect2(0,768,1600,132))
	var entries=[["队员","team","profile"],["装备打印","printer","printer"],["批量训练","training","training"],["基地设施","facility","facility"],["异常档案","cards","cards"],["派遣任务","door","missions"]]
	for i in range(entries.size()):
		var e=entries[i]
		button(g.ui_root,"nav_"+e[2],e[0],Rect2(41+i*254,805,237, sixty()),func():g.open(e[2]),e[1],"primary" if i==5 else "neutral")
	live.training_base=text(g.ui_root,"",Rect2(77,777,1010,25),18,ACCENT)

func sixty() -> float: return 60.0

func battle_screen() -> void:
	var b=g.model.s.battle
	if b.is_empty(): return
	var d=C.mission(b.mission)
	topbar(d.id+"  "+d.name,"自动作战  /  小队成长已锁定")
	live.wave=text(g.ui_root,"",Rect2(608,15,354,49),27,ACCENT,HORIZONTAL_ALIGNMENT_CENTER)
	button(g.ui_root,"base_monitor","基地监控",Rect2(34,114,202,54),func():g.view="base";g.render(),"home")
	live.phase=text(g.ui_root,"",Rect2(523,205,550,57),29,GOLD,HORIZONTAL_ALIGNMENT_CENTER)
	image(g.ui_root,Art.ui("bottom_bar"),Rect2(0,754,1600,146))
	for i in range(4):
		var x=38+i*258
		var p=panel(g.ui_root,Rect2(x,780,246,100),"card")
		image(p,Art.ui("icon_"+C.PEOPLE[i].icon),Rect2(17,18,31,31))
		text(p,C.PEOPLE[i].name,Rect2(58,10,166,33),21)
		live["hp_label_%d"%i]=text(p,"",Rect2(59,43,164,27),18,MUTED)
		live["hp_%d"%i]=bar(p,Rect2(18,77,210,9),100)
	button(g.ui_root,"speed","%d×速度"%g.model.s.speed,Rect2(1103,783,156,44),func():g.perform("speed"),"speed")
	button(g.ui_root,"stats","统计",Rect2(1274,783,125,44),func():g.open("stats"),"stats")
	button(g.ui_root,"recall","召回",Rect2(1414,783,144,44),func():g.open("recall"),"back","danger",not g.model.active())
	live.elapsed=text(g.ui_root,"",Rect2(1103,842,430,33),19,MUTED)

func refresh() -> void:
	var m=g.model
	if live.has("credits"): live.credits.text=str(m.s.credits)+" 积分"
	if live.has("alloy"): live.alloy.text=str(m.s.alloy)+" 合金"
	if live.has("training_base"): live.training_base.text="培养中 · 还需 %d 秒"%ceili(m.s.training.remaining) if not m.s.training.is_empty() else "点击场景设施或下方入口进行整备。"
	if not m.s.battle.is_empty():
		var b=m.s.battle
		var d=C.mission(b.mission)
		if live.has("wave"): live.wave.text="第 %d / %d 波"%[int(b.wave)+1,d.waves.size()]
		if live.has("phase"): live.phase.text="任务门连接中…" if b.phase=="travel" else ("本波完成 · 幸存队员恢复" if b.phase=="between" else "")
		if live.has("elapsed"): live.elapsed.text="%02d:%02d  ·  已获 %d 积分 / %d 合金"%[int(b.time)/60,int(b.time)%60,b.credits,b.alloy]
		if live.has("base_battle"): live.base_battle.text="%s  ·  第 %d / %d 波"%[d.name,int(b.wave)+1,d.waves.size()]
		for i in range(4):
			if not live.has("hp_%d"%i): continue
			var u=b.units[i]
			live["hp_%d"%i].value=maxf(0,u.hp/u.max_hp*100)
			live["hp_label_%d"%i].text=("%d / %d"%[ceili(u.hp),roundi(u.max_hp)]) if u.hp>0 else "已倒下 · 等待返回"
	if live.has("training_time"):
		live.training_time.text="剩余 %d 秒"%ceili(m.s.training.remaining) if not m.s.training.is_empty() else "训练已完成"
		live.training_progress.value=(30-m.s.training.remaining)/30*100 if not m.s.training.is_empty() else 100
	if live.has("auto_countdown"):
		live.auto_countdown.text="%d 秒后自动继续 · 点击任意按钮可取消"%ceili(g.auto_timer) if g.auto_timer>0 else "奖励已入账。选择下一步。"

func slots() -> void:
	var p=modal("基地记录","三个独立存档位。新建不会覆盖已有记录。")
	for i in range(3):
		var n=i+1
		var storage=g.slot_store(n)
		var data=storage.load_primary()
		var card=panel(p,Rect2(39+i*430,132,408,492),"card")
		image(card,Art.ui("emblem"),Rect2(131,28,146,146))
		text(card,"记录 0%d"%n,Rect2(25,185,358,42),28,ACCENT,HORIZONTAL_ALIGNMENT_CENTER)
		text(card,str(data.get("base_name","空记录" if not storage.exists() else "记录需要恢复")),Rect2(26,239,354,42),25,INK,HORIZONTAL_ALIGNMENT_CENTER)
		if not data.is_empty():
			text(card,"T%d  ·  积分 %d\n游玩 %d 分钟"%[data.tier,data.credits,int(data.playtime)/60],Rect2(30,292,348,75),20,MUTED,HORIZONTAL_ALIGNMENT_CENTER)
			button(card,"load_%d"%n,"继续",Rect2(42,379,324,59),func():g.load_game(n),"play","primary")
			button(card,"delete_%d"%n,"删除记录",Rect2(102,444,204,40),func():g.open("delete",{"slot":n}),"recycle","danger")
		else:
			text(card,"从四个人醒来的房间开始。" if not storage.exists() else "原文件保留，可尝试读取备份。",Rect2(30,290,348,79),20,MUTED,HORIZONTAL_ALIGNMENT_CENTER)
			button(card,"new_%d"%n,"建立基地" if not storage.exists() else "恢复记录",Rect2(42,379,324,59),func():
				if storage.exists(): g.load_game(n)
				else: g.open("newsave",{"slot":n}),"door","primary")

func field(parent: Control,r: Rect2,value="",placeholder="") -> LineEdit:
	var f=LineEdit.new()
	f.position=r.position
	f.size=r.size
	f.text=value
	f.placeholder_text=placeholder
	f.add_theme_stylebox_override("normal",style("button_neutral_normal"))
	f.add_theme_stylebox_override("focus",style("button_primary_focus"))
	f.add_theme_font_size_override("font_size",26)
	f.max_length=16
	parent.add_child(f)
	return f

func new_save() -> void:
	var p=modal("建立基地记录","这个代号将用于识别你的存档。")
	image(p,Art.ui("emblem"),Rect2(581,135,198,198))
	form=field(p,Rect2(420,373,520,62),"第 07 号基地")
	button(p,"create_save","建立连接",Rect2(515,499,330,65),func():g.new_game(int(g.payload.slot),form.text),"door","primary")

func delete_save() -> void:
	var p=modal("删除基地记录","只影响所选记录及其备份。请输入“删除”确认。")
	text(p,"记录 0%d"%int(g.payload.slot),Rect2(380,174,600,67),38,GOLD,HORIZONTAL_ALIGNMENT_CENTER)
	form=field(p,Rect2(431,300,500,60),"","删除")
	button(p,"confirm_delete","确认删除",Rect2(516,437,329,62),func():
		if form.text!="删除":
			g.toast("请输入“删除”后确认。")
			return
		var st=g.slot_store(int(g.payload.slot))
		for path in [st.path,st.path+".bak",st.path+".tmp"]:
			if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
		if g.slot==int(g.payload.slot):
			g.slot=0
			g.store=null
		g.back(),"recycle","danger")

func settings() -> void:
	var p=modal("设置","修改先预览，点击应用后保存；取消会恢复原设置。")
	text(p,"声音",Rect2(55,135,540,40),27)
	for i in range(5):
		var value=i*.25
		button(p,"volume_%d"%i,"%d%%"%int(value*100),Rect2(59+i*139,198,123,54),func():g.settings_draft.volume=value;g.set_volume(value);g.render(),"volume","primary" if absf(g.settings_draft.volume-value)<.13 else "neutral")
	var options=[["large","大字模式","主要文字增大，长文自动换行。"],["background","后台继续","切换到其他窗口时，战斗和培养继续。"],["flash","命中闪白","关闭后保留伤害数字与声音。"]]
	for i in range(options.size()):
		var o=options[i]
		text(p,o[1],Rect2(60,300+i*87,270,39),24)
		text(p,o[2],Rect2(330,300+i*87,670,39),20,MUTED)
		button(p,"setting_"+o[0],"开启" if g.settings_draft[o[0]] else "关闭",Rect2(1110,296+i*87,183,53),func():g.settings_draft[o[0]]=not g.settings_draft[o[0]];g.render(),"check" if g.settings_draft[o[0]] else "close")
	button(p,"apply_settings","应用设置",Rect2(1000,582,300,61),g.save_settings,"check","primary")
	text(p,"窗口可自由缩放，最低支持 1280 × 720。",Rect2(60,578,810,63),20,MUTED)

func intro() -> void:
	var blocker=Control.new()
	blocker.size=Vector2(1600,900)
	blocker.mouse_filter=Control.MOUSE_FILTER_STOP
	g.overlay.add_child(blocker)
	var box=panel(g.overlay,Rect2(81,619,1438,236))
	box.mouse_filter=Control.MOUSE_FILTER_STOP
	var line=C.INTRO[mini(int(g.model.s.intro),C.INTRO.size()-1)]
	image(box,Art.ui("icon_volume" if line[0]=="广播" else "icon_chat"),Rect2(36,31,45,45))
	text(box,line[0],Rect2(100,25,1140,49),29,ACCENT)
	text(box,line[1],Rect2(45,91,1290,75),27)
	text(box,"连接已建立 · REC",Rect2(46,182,650,30),19,MUTED)
	button(box,"intro_next","继续广播  ·  空格",Rect2(1094,169,294,51),func():g.perform("intro"),"play","primary")

func missions() -> void:
	var m=g.model
	var d=C.mission(m.s.selected_mission)
	var p=modal("任务门","选择任务查看情报，确认小队后出发。")
	image(p,Art.background(d.bg),Rect2(40,131,759,335))
	image(p,Art.frame(d.enemy,8),Rect2(559,234,212,212),true)
	text(p,d.id+"  "+d.name,Rect2(840,132,478,56),35)
	text(p,d.desc,Rect2(841,208,466,88),22,MUTED)
	separator(p,840,305,468)
	text(p,"作战段数  %d 波\n参考战力  %d\n首领  %s"%[d.waves.size(),d.power,d.boss],Rect2(841,326,468,126),23)
	text(p,"完成奖励  %d 积分 / %d 合金\n首胜解锁  %s"%[d.credits,d.alloy,d.reward],Rect2(841,470,468,92),21,GOLD)
	for i in range(3):
		var def=C.MISSIONS[i]
		button(p,"mission_"+def.id,def.id+"\n"+def.name,Rect2(40+i*258,487,241,86),func():m.s.selected_mission=def.id;g.render(),"map" if m.unlocked(def.id) else "lock","primary" if d.id==def.id else "neutral")
	text(p,"已完成 %d 次  ·  %s  ·  队伍战力 %d"%[m.s.wins[d.id],m.quality(d.id),m.power()],Rect2(40,588,760,42),20,ACCENT)
	var why="小队已在出战" if m.active() else ("需先完成上一任务" if not m.unlocked(d.id) else ("训练尚未结束" if not m.s.training.is_empty() else ""))
	button(p,"prepare",why if why!="" else "准备出发",Rect2(999,587,305,61),func():g.open("ready"),"door","primary",why!="")

func ready() -> void:
	var m=g.model
	var d=C.mission(m.s.selected_mission)
	var p=modal("出发确认  /  "+d.name,"四名队员共同出发。任务过程中可召回，升级与制造需要回到基地。")
	for i in range(4):
		var c=panel(p,Rect2(42+i*322,130,310,320),"card")
		image(c,Art.frame(C.PEOPLE[i].id,0),Rect2(74,13,162,200),true)
		text(c,C.PEOPLE[i].name+"  /  "+C.PEOPLE[i].role,Rect2(13,226,283,36),23,INK,HORIZONTAL_ALIGNMENT_CENTER)
		button(c,"ready_person_%d"%i,"查看装备",Rect2(65,266,180, forty()),func():select_person(i,"profile"),C.PEOPLE[i].icon)
	text(p,"任务完成后",Rect2(45,475,230,40),23,MUTED)
	var entries=[["return","返回基地"],["repeat","重复本任务"],["next","进入下一关"]]
	for i in range(3):
		var e=entries[i]
		button(p,"auto_"+e[0],e[1],Rect2(287+i*290,472,271,56),func():g.perform("auto",e[0]),"check" if m.s.auto==e[0] else "play","primary" if m.s.auto==e[0] else "neutral")
	text(p,d.tip,Rect2(45,558,890,76),21,MUTED)
	button(p,"depart","开启任务门",Rect2(990,579,313,65),func():g.perform("depart",d.id),"door","primary")

func forty() -> float: return 40.0

func select_person(index: int, target: String) -> void:
	g.model.s.selected_person=index
	selected_gear=""
	g.open(target)

func person_tabs(p: Control) -> void:
	for i in range(4):
		button(p,"select_person_%d"%i,C.PEOPLE[i].name,Rect2(37+i*209,130,193,49),func():g.model.s.selected_person=i;selected_gear="";g.render(),C.PEOPLE[i].icon,"primary" if i==g.model.s.selected_person else "neutral")

func lock_notice(p: Control,y=574.0) -> bool:
	if g.model.active():
		text(p,"小队正在出战。召回后可进行成长与换装。",Rect2(437,y,581,52),20,GOLD)
		button(p,"recall_from_growth","召回小队",Rect2(1048,y,257,56),func():g.open("recall",{"return_page":g.page}),"back","danger")
		return true
	if not g.model.s.training.is_empty():
		text(p,"训练中，结束或取消后可继续整备。",Rect2(437,y,846,52),20,GOLD)
		return true
	return false

func profile() -> void:
	var m=g.model
	var i=int(m.s.selected_person)
	var d=C.PEOPLE[i]
	var st=m.stats(i)
	var p=modal("队员档案","成长的投入、变化与上限会在这里直接显示。")
	person_tabs(p)
	image(p,Art.frame(d.id,0),Rect2(54,200,291,411),true)
	text(p,d.name,Rect2(408,194,650,56),38)
	text(p,"%d 岁  /  %s  /  %s"%[d.age,d.job,d.role],Rect2(410,254,790,38),21,ACCENT)
	text(p,d.note,Rect2(410,304,866,63),22,MUTED)
	separator(p,410,379,879)
	text(p,"生命  %d     攻击  %d     护甲  %d"%[st.hp,st.atk,st.armor],Rect2(412,402,857,45),27)
	text(p,"体质 Lv.%d / %d    ·    战力 %d\n下一级：生命 +%d   攻击 +%.1f"%[m.s.people[i].body,m.cap(),st.power,roundi(d.hp*.08),d.atk*.03],Rect2(412,457,852,81),22,ACCENT)
	if not lock_notice(p,573):
		var capped=m.s.people[i].body>=m.cap()
		text(p,"升级上限由基地设施决定。" if not capped else "已达上限，需要基地 T%d。"%(m.s.tier+1),Rect2(410,578,573, fifty()),20,MUTED)
		button(p,"upgrade_body","体质 +1  /  %d 积分"%m.body_cost(i),Rect2(1009,573,297,60),func():g.perform("upgrade","body"),"upgrade","primary",capped)
	button(p,"equipment","装备",Rect2(883,129,139,50),func():g.open("equipment"),"rifle")
	button(p,"skills","能力",Rect2(1034,129,133,50),func():g.open("skills"),"skill")
	button(p,"talk","交谈",Rect2(1179,129,132,50),func():talk_index=0;g.open("dialogue"),"chat", "neutral",m.active())

func fifty() -> float: return 50.0

func equipment() -> void:
	var m=g.model
	var i=int(m.s.selected_person)
	var p=modal("装备  /  "+C.PEOPLE[i].name,"固定成品，没有随机词条。更换保留旧装备及其等级。")
	person_tabs(p)
	button(p,"gear_weapon","武器",Rect2(942,130,167,48),func():gear_kind="weapon";selected_gear="";g.render(),"rifle","primary" if gear_kind=="weapon" else "neutral")
	button(p,"gear_armor","防具",Rect2(1123,130,178,48),func():gear_kind="armor";selected_gear="";g.render(),"shield","primary" if gear_kind=="armor" else "neutral")
	var current=m.item(m.s.people[i][gear_kind])
	var inventory=[]
	for v in m.s.inventory:
		if v.role==i and v.slot==gear_kind: inventory.append(v)
	if selected_gear=="" or m.item(selected_gear).is_empty(): selected_gear=current.id
	var chosen=m.item(selected_gear)
	var scroll=ScrollContainer.new()
	scroll.position=Vector2(38,206)
	scroll.size=Vector2(565,329)
	p.add_child(scroll)
	for state in ["scroll","scroll_focus"]: scroll.get_v_scroll_bar().add_theme_stylebox_override(state,style("button_neutral_normal"))
	for state in ["grabber","grabber_highlight","grabber_pressed"]: scroll.get_v_scroll_bar().add_theme_stylebox_override(state,style("button_primary_normal"))
	var list=VBoxContainer.new()
	list.custom_minimum_size.x=532
	list.add_theme_constant_override("separation",12)
	scroll.add_child(list)
	for v in inventory:
		var n=(C.weapon_name(i,v.mk) if gear_kind=="weapon" else "复合防护衣")+"  Mk.%02d / Lv.%d"%[v.mk,v.level]
		var b=button(list,"gear_"+v.id,("◆ " if v.id==current.id else "")+n,Rect2(0,0,529,68),func():selected_gear=v.id;g.render(),C.PEOPLE[i].icon if gear_kind=="weapon" else "shield","primary" if selected_gear==v.id else "neutral")
		b.custom_minimum_size=Vector2(529,68)
	var detail=panel(p,Rect2(637,205,663,337),"card")
	image(detail,Art.frame("equipment",i+(4*(chosen.mk-1) if gear_kind=="weapon" else 8)),Rect2(23,17,117,119),true)
	text(detail,C.weapon_name(i,chosen.mk) if gear_kind=="weapon" else "复合防护衣",Rect2(162,25,461,47),30)
	text(detail,"Mk.%02d  ·  Lv.%d"%[chosen.mk,chosen.level],Rect2(163,83,431,40),24,ACCENT)
	var attack_diff=C.PEOPLE[i].atk*.1*(chosen.level-current.level)+10*(chosen.mk-current.mk)
	var armor_diff=6*(chosen.level-current.level)+10*(chosen.mk-current.mk)
	text(detail,"攻击变化  %+.1f"%attack_diff if gear_kind=="weapon" else "护甲变化  %+d"%armor_diff,Rect2(33,155,602,55),26,GOLD)
	text(detail,"正在使用此装备" if chosen.id==current.id else "更换后，当前装备会回到库存。",Rect2(33,219,602,46),20,MUTED)
	button(detail,"equip","装备",Rect2(33,275,277,48),func():g.perform("equip",chosen.id),"check","primary",chosen.id==current.id or m.active() or not m.s.training.is_empty())
	button(detail,"dismantle","分解",Rect2(329,275,300,48),func():g.open("dismantle",{"item":chosen.id}),"recycle","danger",chosen.id==current.id or m.active() or not m.s.training.is_empty())
	if not lock_notice(p,574):
		var n=int(current.level)
		var money=(50+30*n) if gear_kind=="weapon" else (40+25*n)
		var alloy=1+int(n/3) if gear_kind=="weapon" else 1+int(n/4)
		text(p,"强化当前穿戴  /  %d 积分 + %d 合金"%[money,alloy] if n<m.cap() else "已达当前成长上限，需要升级基地设施。",Rect2(40,581,827,55),22,MUTED)
		button(p,"upgrade_gear","强化当前装备",Rect2(966,577,335,60),func():g.perform("upgrade",gear_kind),"upgrade","primary",n>=m.cap())

func skills() -> void:
	var m=g.model
	var i=int(m.s.selected_person)
	var level=int(m.s.people[i].skill)
	var p=modal("特殊能力","能力在战斗中按冷却自动施放，不需要点击操作。")
	person_tabs(p)
	image(p,Art.frame(C.PEOPLE[i].id,8),Rect2(62,216,295,359),true)
	text(p,C.PEOPLE[i].skill+"  Lv.%d"%level,Rect2(414,211,859,60),37)
	text(p,C.skill_description(i,level),Rect2(417,299,854,78),25,INK)
	separator(p,419,397,869)
	text(p,"升级后",Rect2(419,429,852,40),22,MUTED)
	text(p,C.skill_description(i,mini(5,level+1)),Rect2(419,475,852,75),23,ACCENT)
	if not lock_notice(p,577):
		text(p,"消耗 %d 积分 / %d 合金"%[180*level,4*level],Rect2(417,590,573, forty()),22,GOLD)
		button(p,"upgrade_skill","升级能力" if level<5 else "已满级",Rect2(1013,580,290,59),func():g.perform("upgrade","skill"),"skill","primary",level>=5)

func training() -> void:
	var m=g.model
	var p=modal("训练舱  /  均衡培养","与单人升级同价，30 秒后一次性完成；中途取消全额退回积分。")
	var cost=0
	for i in range(4):
		var c=panel(p,Rect2(40+i*324,135,307,321),"card")
		image(c,Art.frame(C.PEOPLE[i].id,12),Rect2(81,16,146,189),true)
		text(c,C.PEOPLE[i].name,Rect2(20,218,267,42),25,INK,HORIZONTAL_ALIGNMENT_CENTER)
		var lvl=int(m.s.people[i].body)
		text(c,"体质 %d → %d"%[lvl,mini(m.cap(),lvl+1)],Rect2(20,271,267,38),22,ACCENT,HORIZONTAL_ALIGNMENT_CENTER)
		if lvl<m.cap(): cost+=m.body_cost(i)
	if not m.s.training.is_empty():
		live.training_progress=bar(p,Rect2(50,501,1260,18),0)
		live.training_time=text(p,"",Rect2(49,552,800,58),28,ACCENT)
		button(p,"cancel_training","取消并退回 %d 积分"%m.s.training.cost,Rect2(889,559,421, sixty()),func():g.perform("cancel_training"),"back","danger")
	elif not lock_notice(p,562):
		text(p,"总费用  %d 积分   ·   成长上限 Lv.%d"%[cost,m.cap()],Rect2(50,506,1200,49),25,GOLD)
		button(p,"start_training","开始全队培养",Rect2(1000,577,310,61),func():g.perform("train"),"training","primary",cost==0)

func printer() -> void:
	var m=g.model
	var p=modal("装备打印机","选择配方查看固定成品。制造不会自动替换当前装备。")
	for i in range(4):
		button(p,"recipe_person_%d"%i,C.PEOPLE[i].role,Rect2(42+i*225,132,208,52),func():recipe_role=i;g.render(),C.PEOPLE[i].icon,"primary" if i==recipe_role else "neutral")
	button(p,"recipe_type", "武器配方" if recipe_slot=="weapon" else "防具配方",Rect2(1000,132,309,52),func():recipe_slot="armor" if recipe_slot=="weapon" else "weapon";g.render(),"rifle" if recipe_slot=="weapon" else "shield")
	var plate=panel(p,Rect2(43,212,393,317),"card")
	image(plate,Art.frame("equipment",recipe_role+(4*(recipe_mk-1) if recipe_slot=="weapon" else 8)),Rect2(45,28,304,207),true)
	text(plate,"Mk.%02d"%recipe_mk,Rect2(25,246,343,45),32,ACCENT,HORIZONTAL_ALIGNMENT_CENTER)
	text(p,C.weapon_name(recipe_role,recipe_mk) if recipe_slot=="weapon" else "复合防护衣",Rect2(480,213,820,56),35)
	text(p,"适用队员  "+C.PEOPLE[recipe_role].name+"\n初始等级  Lv.1\n额外属性  "+("攻击" if recipe_slot=="weapon" else "护甲")+" +%d"%((recipe_mk-1)*10),Rect2(483,294,814,136),24,MUTED)
	for i in range(2):
		var mk=i+1
		button(p,"recipe_mk_%d"%mk,"Mk.%02d"%mk,Rect2(485+i*206,453,188,55),func():recipe_mk=mk;g.render(),"printer","primary" if recipe_mk==mk else "neutral")
	var why=""
	if m.s.wins.M01<1: why="完成 M01 后开放打印配方。"
	elif recipe_mk==2 and (m.s.wins.M02<1 if recipe_role==1 else m.s.wins.M03<1): why="完成 %s 后解锁此配方。"%("M02" if recipe_role==1 else "M03")
	if not lock_notice(p,574):
		text(p,why if why!="" else "固定制造费用  %d 积分 / %d 合金"%[100 if recipe_mk==1 else 180,4 if recipe_mk==1 else 6],Rect2(43,579,880, fifty()),22,GOLD)
		button(p,"manufacture","打印成品",Rect2(1000,576,310, sixty()),func():g.perform("manufacture",{"role":recipe_role,"slot":recipe_slot,"mk":recipe_mk}),"printer","primary",why!="")

func facility() -> void:
	var m=g.model
	var p=modal("基地设施","配电、打印与培养统一由基地等级统筹。")
	image(p,Art.background("base_t2" if m.s.tier>=2 else "base"),Rect2(40,135,745,419))
	image(p,Art.ui("emblem"),Rect2(985,137,132,132))
	text(p,"基地 T%d"%m.s.tier,Rect2(847,277,419, sixty()),38,INK,HORIZONTAL_ALIGNMENT_CENTER)
	text(p,"当前成长上限  Lv.%d\n下一阶段上限  Lv.10\n升级需求  M03 首次完成"%m.cap(),Rect2(842,368,461,141),22,MUTED)
	if not lock_notice(p,583):
		text(p,"T2 费用：500 积分 / 12 合金" if m.s.tier<2 else "当前章节的设施已全部建成。",Rect2(48,583,899, forty()),23,GOLD)
		button(p,"upgrade_facility","升级至 T2" if m.s.tier<2 else "T2 已建成",Rect2(1000,575,306,64),func():g.perform("facility"),"facility","primary",m.s.tier>=2)

func cards() -> void:
	var m=g.model
	var p=modal("异常档案","完成任务记录目标。8 次胜利成为金卡，25 次成为钻石卡。")
	for i in range(3):
		var d=C.MISSIONS[i]
		var quality=m.quality(d.id)
		var c=panel(p,Rect2(47+i*431,137,404,485),"card_gold" if quality=="金卡" else ("card_diamond" if quality=="钻石" else "card"))
		image(c,Art.background(d.bg),Rect2(13,13,378,202))
		var figure=image(c,Art.frame(d.enemy,8),Rect2(73,36,258,242),true)
		if m.s.wins[d.id]==0: figure.modulate=Color(.07,.10,.10,1)
		text(c,d.boss,Rect2(24,282,356,46),30,INK,HORIZONTAL_ALIGNMENT_CENTER)
		text(c,quality+"  ·  %d 次完成"%m.s.wins[d.id],Rect2(24,336,356,36),21,GOLD,HORIZONTAL_ALIGNMENT_CENTER)
		bar(c,Rect2(32,392,340,12),float(m.s.wins[d.id])/(25 if m.s.wins[d.id]>=8 else 8)*100,true)
		button(c,"card_"+d.id,"查看档案",Rect2(57,429,291, fifty()),func():g.open("card_detail",{"mission":d.id}),"file")

func card_detail() -> void:
	var m=g.model
	var d=C.mission(g.payload.mission)
	var p=modal(d.boss,"异常记录  /  "+d.id+"  "+d.name)
	image(p,Art.background(d.bg),Rect2(44,137,672,407))
	var figure=image(p,Art.frame(d.enemy,8),Rect2(195,169,363,335),true)
	if m.s.wins[d.id]==0: figure.modulate=Color(.08,.1,.1,1)
	text(p,m.quality(d.id),Rect2(765,151,541,53),37,GOLD)
	text(p,d.desc if m.s.wins[d.id]>0 else "完成这个任务后，记录目标的完整形态。",Rect2(765,234,540,120),25)
	text(p,"累计完成  %d 次\n距离金卡  %d 次\n距离钻石  %d 次"%[m.s.wins[d.id],maxi(0,8-m.s.wins[d.id]),maxi(0,25-m.s.wins[d.id])],Rect2(765,390,532,153),23,ACCENT)
	button(p,"card_mission","前往对应任务",Rect2(973,575,333,63),func():m.s.selected_mission=d.id;g.open("missions"),"door","primary")

func dialogue() -> void:
	var i=int(g.model.s.selected_person)
	var p=modal("广播交谈  /  "+C.PEOPLE[i].name,"对话会保存在人物记录中，不影响装备与任务解锁。")
	image(p,Art.frame(C.PEOPLE[i].id,13),Rect2(64,150,310,455),true)
	var entry=C.CONVERSATIONS[i][mini(talk_index,2)]
	text(p,entry[0],Rect2(437,176,846,61),35,ACCENT)
	text(p,entry[1],Rect2(437,285,843,168),30)
	if talk_index==1:
		button(p,"response_calm","我在这里。",Rect2(438,516,377,65),next_dialogue,"volume","primary")
		button(p,"response_direct","先完成这次任务。",Rect2(839,516,446,65),next_dialogue,"volume")
	else: button(p,"dialogue_next","结束交谈" if talk_index>=2 else "继续  ·  空格",Rect2(980,551,311,64),next_dialogue,"chat","primary")

func next_dialogue() -> void:
	if talk_index>=2:
		if not g.model.s.selected_person in g.model.s.dialogues: g.model.s.dialogues.append(g.model.s.selected_person)
		g.commit()
		g.back()
	else:
		talk_index+=1
		g.render()

func result() -> void:
	var r=g.model.s.result
	if r.is_empty(): return
	var d=C.mission(r.mission)
	var victory=r.outcome=="victory"
	var p=modal("任务完成" if victory else "小队重建完成","奖励已随战斗记录保存，返回或重启不会重复领取。")
	var art=panel(p,Rect2(44,135,393,428),"card_gold" if victory else "card")
	image(art,Art.background(d.bg),Rect2(13,13,367,197))
	image(art,Art.frame(d.enemy,8),Rect2(73,61,246,250),true)
	text(art,d.boss,Rect2(22,309,351,49),28,INK,HORIZONTAL_ALIGNMENT_CENTER)
	text(art,g.model.quality(d.id) if victory else "未增加卡片进度",Rect2(22,365,351,39),21,GOLD,HORIZONTAL_ALIGNMENT_CENTER)
	text(p,d.id+"  "+d.name,Rect2(482,144,812,64),36)
	text(p,"+%d 积分     +%d 合金"%[r.credits,r.alloy],Rect2(482,248,800,69),35,GOLD)
	text(p,"完成波次  %d / %d\n任务用时  %02d:%02d\n累计通关  %d 次"%[r.completed,d.waves.size(),int(r.time)/60,int(r.time)%60,r.wins],Rect2(485,347,810,139),24,MUTED)
	live.auto_countdown=text(p,"",Rect2(485,495,815, fifty()),21,ACCENT)
	button(p,"result_base","返回基地",Rect2(45,589,281,60),g.go_base,"home","primary")
	button(p,"result_stats","查看统计",Rect2(340,589,243,60),func():g.open("stats"),"stats")
	button(p,"result_repeat","再次出发",Rect2(726,589,271,60),func():g.perform("depart",d.id),"door")
	var idx=C.MISSIONS.find(d)+1
	if victory and idx<3: button(p,"result_next","下一任务",Rect2(1014,589,292,60),func():g.perform("depart",C.MISSIONS[idx].id),"play")
	elif victory: text(p,"第一章三个任务已完成",Rect2(1014,590,292,59),21,ACCENT,HORIZONTAL_ALIGNMENT_CENTER)

func stats() -> void:
	var p=modal("战斗统计","统计来自本次实际战斗事件，治疗只记录有效恢复量。")
	var values=g.model.s.battle.get("stats",[])
	text(p,"队员                         输出伤害             承受伤害             有效治疗",Rect2(67,150,1214, fifty()),24,MUTED)
	for i in range(values.size()):
		var v=values[i]
		var c=panel(p,Rect2(48,223+i*88,1253,75),"card")
		image(c,Art.ui("icon_"+C.PEOPLE[i].icon),Rect2(17,19,35,35))
		text(c,v.name,Rect2(70,12,295,49),25)
		text(c,"%d"%v.damage,Rect2(414,12,230,49),25,GOLD)
		text(c,"%d"%v.taken,Rect2(713,12,230,49),25)
		text(c,"%d"%v.heal,Rect2(1012,12,219,49),25,ACCENT)

func recall() -> void:
	var p=modal("召回小队","确认期间战斗暂停。只放弃当前尚未完成的波次。")
	var b=g.model.s.battle
	text(p,"保留已完成波次的奖励",Rect2(180,178,1000,72),37,INK,HORIZONTAL_ALIGNMENT_CENTER)
	text(p,"%d 积分   /   %d 合金"%[b.get("credits",0),b.get("alloy",0)],Rect2(180,273,1000,87),41,GOLD,HORIZONTAL_ALIGNMENT_CENTER)
	text(p,"本次卡片进度不会增加。四名队员会免费恢复，返回后可升级。",Rect2(224,408,912,86),24,MUTED,HORIZONTAL_ALIGNMENT_CENTER)
	button(p,"recall_cancel","继续战斗",Rect2(298,549,337,65),g.back,"play")
	button(p,"recall_confirm","确认召回",Rect2(724,549,337,65),func():g.perform("recall"),"back","danger")

func dismantle() -> void:
	var item=g.model.item(g.payload.item)
	var p=modal("分解装备","这件库存装备将被销毁，不返还积分与升级消耗。")
	image(p,Art.ui("icon_recycle"),Rect2(593,154,174,174))
	text(p,"返还 %d 合金"%(2 if item.mk==1 else 3),Rect2(330,362,700,72),38,GOLD,HORIZONTAL_ALIGNMENT_CENTER)
	button(p,"dismantle_confirm","确认分解",Rect2(504,509,352,65),func():g.perform("dismantle",item.id),"recycle","danger")

func pause() -> void:
	var p=modal("已暂停","战斗与训练计时均已停止。")
	image(p,Art.ui("emblem"),Rect2(158,178,273,273))
	text(p,g.model.s.base_name,Rect2(107,472,379,56),27,ACCENT,HORIZONTAL_ALIGNMENT_CENTER)
	button(p,"resume","继续游戏",Rect2(638,156,540,68),g.back,"play","primary")
	button(p,"pause_settings","设置",Rect2(638,249,540,68),func():g.open("settings"),"settings")
	button(p,"save_title","保存并返回标题",Rect2(638,342,540,68),func():
		if g.commit():
			g.view="title"
			g.page=""
			g.history.clear()
			g.render(),"save")
	button(p,"pause_quit","保存并退出",Rect2(638,435,540,68),g.quit_game,"exit")

func quit_dialog() -> void:
	var p=modal("退出游戏","退出前将保存当前进度，关闭期间不进行离线战斗。")
	image(p,Art.ui("emblem"),Rect2(590,152,180,180))
	button(p,"quit_cancel","继续停留",Rect2(313,442,331,65),g.back,"back")
	button(p,"quit_confirm","退出游戏",Rect2(716,442,331,65),g.quit_game,"exit","primary")

func recovery() -> void:
	var p=modal("记录需要处理","原有记录会保留，不会自动创建新档覆盖。")
	image(p,Art.ui("icon_save"),Rect2(602,150,156,156))
	text(p,g.fault,Rect2(198,336,964,110),27,GOLD,HORIZONTAL_ALIGNMENT_CENTER)
	if g.page=="recovery":
		var backup=g.slot_store(g.recovery_slot).load_backup()
		button(p,"recover_backup","恢复最近备份",Rect2(308,511,355,65),func():
			if backup.is_empty(): return
			var st=g.slot_store(g.recovery_slot)
			if st.save(backup): g.load_game(g.recovery_slot),"save","primary",backup.is_empty())
		button(p,"recovery_title","返回标题",Rect2(707,511,346,65),g.back,"back")
	else:
		button(p,"retry_save","重试保存",Rect2(505,511,350,65),func():
			if g.commit(): g.page="";g.render(),"save","primary")
