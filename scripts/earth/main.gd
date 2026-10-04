extends Control
const C = preload("res://scripts/earth/catalog.gd")
const Model = preload("res://scripts/earth/model.gd")
const Store = preload("res://scripts/reboot/save_store.gd")
const Art = preload("res://scripts/earth/assets.gd")
const Home = preload("res://scripts/earth/home.gd")
const HomeView = preload("res://scripts/earth/home_view.gd")
const BattleView = preload("res://scripts/earth/battle_view.gd")
const Loot=preload("res://scripts/earth/loot.gd")
const LootView=preload("res://scripts/earth/loot_view.gd")
const PortalView=preload("res://scripts/earth/portal_view.gd")
var loot_ui: RefCounted
var loot_page=0
var loot_selected=0
var equipment_return="squad"
var portal_opening=false
var home_ui: RefCounted
var dialogue_id="xuan"
var collection_page=0
var settings_page="root"
var slot_return="title"
var home_hotspots: Dictionary={}
var next_arrow: Label
var battlefield: Control
var paused = false
var battle_speed = 1.0
var selected_stage = 1
var mission_page=0
var tick_accumulator = 0.0
var refresh_clock = 0.0
var save_clock = 0.0
var battle_labels: Dictionary = {}
var model = Model.new()
var store: RefCounted
var slot = 0
var view = "title"
var buttons: Dictionary = {}
var ui: Control
var shots: Array = []
var history_lines: Array = []
var transient = false
var stage01_preview = false
var kaidan_preview = false
var message = ""
var selected = 0
var settings = {"volume":0.55,"large":false,"fullscreen":false}
var auto_read = false
var auto_clock = 0.0
var replay = false
var music: AudioStreamPlayer
var click_audio: AudioStreamPlayer
var effect_audio: AudioStreamPlayer
var settings_return = "title"
var committed: Dictionary = {}
var room_transition: Tween
var transition_cover: ColorRect
var hotspot_hint: Label
const INK = Color("f1eee0")
const MUTED = Color("adb7a7")
const GOLD = Color("ffb043")

func _ready() -> void:
	get_window().content_scale_size = Vector2i(1600,900)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	get_window().min_size = Vector2i(960,540)
	stage01_preview = "--earth-stage01-preview" in OS.get_cmdline_user_args()
	kaidan_preview = "--earth-kaidan-preview" in OS.get_cmdline_user_args()
	transient = "--earth-test" in OS.get_cmdline_user_args() or stage01_preview or kaidan_preview
	var font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei","sans-serif"])
	theme = Theme.new()
	theme.default_font = font
	theme.default_font_size = 22
	home_ui=HomeView.new(self)
	loot_ui=LootView.new(self)
	home_hotspots=JSON.parse_string(FileAccess.get_file_as_string("res://assets/earth/home/home_hotspots.json"))
	shots = JSON.parse_string(FileAccess.get_file_as_string("res://assets/earth/opening.json"))
	var saved = Store.new("user://earth/settings.json").load_primary()
	for key in settings:
		if saved.has(key) and typeof(saved[key])==typeof(settings[key]): settings[key]=saved[key]
	ui = Control.new()
	battlefield = BattleView.new()
	battlefield.game = self
	add_child(battlefield)
	ui.size = Vector2(1600,900)
	add_child(ui)
	music = AudioStreamPlayer.new()
	music.volume_db=-16
	music.finished.connect(func():music.play())
	add_child(music)
	click_audio = AudioStreamPlayer.new()
	click_audio.stream=load(Art.path("audio.click"))
	click_audio.volume_db=-12
	add_child(click_audio)
	effect_audio=AudioStreamPlayer.new()
	effect_audio.volume_db=-16
	add_child(effect_audio)
	apply_settings()
	get_tree().auto_accept_quit = false
	committed = model.s.duplicate(true)
	draw_view()
	if stage01_preview: call_deferred("start_stage01_preview")
	elif kaidan_preview:call_deferred("start_kaidan_preview",301)

func start_kaidan_preview(stage: int=301) -> void:
	model.reset();model.s.intro_done=true
	model.depart(stage);paused=false;battle_speed=1.0;tick_accumulator=0;refresh_clock=0
	navigate("battle")

func preview_anomaly_segment(index: int) -> void:
	if not kaidan_preview or not model.active():return
	var stage=int(model.s.battle.stage)
	start_kaidan_preview(stage)
	var b=model.s.battle
	var tile=C.Anomalies.info(stage).scenes[index]
	var offset=float(tile.world_x)
	for u in b.units:u.x+=offset
	b.encounter=index;model.spawn_encounter()
	b.camera=clampf(offset,0,C.Anomalies.info(stage).world_width-1600)
	battlefield.sync_anomaly_units();battlefield.queue_redraw();refresh_battle()

func start_stage01_preview() -> void:
	model.reset()
	model.s.intro_done=true
	model.depart(1)
	paused=false
	battle_speed=1.0
	tick_accumulator=0.0
	refresh_clock=0.0
	navigate("battle")

func preview_street_segment(index: int) -> void:
	if not stage01_preview or not model.active(): return
	var target_camera=maxf(0,(battlefield.street_width()-1600)*float(index)/4.0)
	var delta=target_camera-float(model.s.battle.camera)
	for u in model.s.battle.units: u.x+=delta
	model.s.battle.camera=target_camera
	battlefield.queue_redraw()

func picture(tex: Texture2D, r: Rect2, contain=false) -> TextureRect:
	var node = TextureRect.new()
	node.texture = tex
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED if contain else TextureRect.STRETCH_SCALE
	node.position = r.position
	node.size = r.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(node)
	return node

func text(words: String, r: Rect2, fs=22, color=INK) -> Label:
	var node = Label.new()
	node.text = words
	node.position = r.position
	node.size = r.size
	node.add_theme_font_size_override("font_size",fs+(2 if settings.large else 0))
	node.add_theme_color_override("font_color",color)
	if fs>=30:
		var heading=SystemFont.new()
		heading.font_names=PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei","sans-serif"])
		heading.font_weight=700
		node.add_theme_font_override("font",heading)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(node)
	return node

func panel(r: Rect2, name="panel") -> void:
	var node = NinePatchRect.new()
	node.texture = Art.ui(name)
	node.position = r.position
	node.size = r.size
	node.patch_margin_left=20
	node.patch_margin_right=20
	node.patch_margin_top=20
	node.patch_margin_bottom=20
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(node)

func button(id: String, words: String, r: Rect2, action: Callable, disabled=false, kind="neutral") -> Button:
	var node = Button.new()
	node.name = id
	node.text = words
	node.position = r.position
	node.size = r.size
	node.disabled = disabled
	node.add_theme_font_size_override("font_size",21+(2 if settings.large else 0))
	node.add_theme_color_override("font_color",INK)
	node.add_theme_color_override("font_disabled_color",Color("73857d"))
	for state in ["normal","hover","pressed","focus","disabled"]:
		var style = StyleBoxTexture.new()
		style.texture = Art.ui("button_"+kind+"_"+state)
		for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]: style.set_texture_margin(side,14)
		node.add_theme_stylebox_override(state,style)
	node.pressed.connect(func(): click_audio.play(); action.call())
	ui.add_child(node)
	buttons[id]=node
	return node

func clear_ui() -> void:
	battle_labels.clear()
	if is_instance_valid(hotspot_hint):hotspot_hint.text=""
	for child in ui.get_children():
		ui.remove_child(child)
		child.queue_free()
	buttons.clear()

func navigate(next: String) -> void:
	if portal_opening:return
	if next in ["map","collection"]:next="missions" if next=="collection" else "base"
	view = next
	message = ""
	draw_view()
	if next=="result" and not model.s.result.is_empty():play_effect("victory" if model.s.result.reason=="victory" else "defeat")

func play_effect(id: String) -> void:
	var path=Art.path("audio."+id)
	if path=="" or transient:return
	effect_audio.stream=load(path)
	effect_audio.play()

func draw_view() -> void:
	clear_ui()
	var music_path=Art.path("audio.battle" if view=="battle" else "audio.base")
	if music.stream==null or music.stream.resource_path!=music_path:
		music.stream=load(music_path)
		if not transient: music.play()
	battlefield.visible=view in ["battle","result"]
	if not battlefield.visible:
		var context=settings_return if view=="settings" else view
		if context in ["base","map","squad","dialogue","printer","collection","missions","growth","suits","room","support","equipment"]:home_ui.room_backdrop()
		else:picture(Art.texture("menu"),Rect2(0,0,1600,900))
	if view not in ["title","battle","base","map","dialogue"]: picture(Art.ui("dim"),Rect2(0,0,1600,900))
	match view:
		"title": title_screen()
		"slots": slots_screen()
		"intro": intro_screen()
		"base", "map", "squad", "dialogue", "printer", "collection": home_ui.draw(view)
		"settings": settings_screen()
		"history": history_screen()
		"recovery": recovery_screen()
		"missions": missions_screen()
		"battle": battle_screen()
		"result": result_screen()
		"suits": suits_screen()
		"growth": growth_screen()
		"room": room_screen()
		"support": support_screen()
		"equipment": loot_ui.draw()
	if message!="": text(message,Rect2(350,8,1190,40),21,GOLD)
	if not buttons.is_empty(): buttons.values()[0].grab_focus()

func title_screen() -> void:
	text("无限异常",Rect2(42,200,400,110),64)
	text("地 球 篇",Rect2(49,316,340,38),23,GOLD)
	text("门外的世界，正在等你。",Rect2(49,370,330,52),19,MUTED)
	button("start","开始游戏",Rect2(48,459,326,58),start_new,false,"primary")
	button("continue","继续游戏",Rect2(48,529,326,58),func(): slot_return="title"; navigate("slots"))
	button("settings","设置",Rect2(48,599,326,58),open_settings)
	button("legacy","旧版与长街试玩",Rect2(48,669,326,50),func(): get_tree().change_scene_to_file("res://scenes/reboot/main.tscn"))
	button("exit","退出",Rect2(48,731,326,50),func(): get_tree().quit())
	text("0.11 · 怪谈异境 / 装备与召唤",Rect2(48,839,490,28),17,MUTED)

func slot_store(n: int) -> RefCounted: return Store.new("user://earth/slot%d.json"%n)

func start_new() -> void:
	for n in range(1,4):
		if transient or not slot_store(n).exists():
			new_game(n)
			return
	navigate("slots")
	message = "三个存档位已有记录，请继续已有进度。原记录不会被覆盖。"
	draw_view()

func new_game(n: int) -> bool:
	if not transient and slot_store(n).exists(): return false
	model.reset()
	slot=n
	store=slot_store(n)
	replay=false
	committed=model.s.duplicate(true)
	if not save(): return false
	navigate("intro")
	return true

func save() -> bool:
	if transient or slot==0:
		committed=model.s.duplicate(true)
		return true
	model.s.saved_at=Time.get_unix_time_from_system()
	if store.save(model.s):
		committed=model.s.duplicate(true)
		return true
	model.s=committed.duplicate(true)
	message="保存失败，修改已撤回；"+store.error
	return false

func load_game(n: int, backup=false) -> bool:
	var candidate=slot_store(n)
	var data=candidate.load_backup() if backup else candidate.load_primary()
	if data.is_empty() or not model.import_state(data):
		slot=n
		view="recovery"
		message="记录无法读取，原文件已保留。" if data.is_empty() else model.error
		draw_view()
		return false
	slot=n
	store=candidate
	committed=model.s.duplicate(true)
	replay=false
	navigate("battle" if model.active() else ("result" if not model.s.result.is_empty() else "base" if model.s.intro_done else "intro"))
	return true

func slots_screen() -> void:
	panel(Rect2(195,144,1210,620))
	text("地球篇记录",Rect2(250,180,850,60),34)
	for n in range(1,4):
		var data=slot_store(n).load_primary()
		var exists=slot_store(n).exists()
		var label="新记录" if not exists else ("需恢复" if data.is_empty() else "第 %d 关 · 空间 T%d"%[data.get("max_stage",1),data.get("room",1)])
		button("slot%d"%n,"记录 %d  /  %s"%[n,label],Rect2(270,280+(n-1)*100,1060,76),func():
			if exists: load_game(n)
			else: new_game(n))
	button("back","返回",Rect2(1120,667,220,56),func(): navigate(slot_return))

func intro_screen() -> void:
	var index=clampi(model.s.intro,0,shots.size()-1)
	var shot=shots[index]
	if shot.get("presentation","")=="time_card":
		var black=ColorRect.new()
		black.color=Color.BLACK;black.size=Vector2(1600,900);black.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.add_child(black)
		var caption=text("五分钟后",Rect2(400,350,800,130),44)
		caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	else:
		var tex=Art.texture(shot.get("fallback_asset","opening."+shot.id))
		if shot.has("camera_region"):
			var camera=AtlasTexture.new();camera.atlas=tex
			var region=shot.camera_region;camera.region=Rect2(region[0],region[1],region[2],region[3]);camera.filter_clip=true;tex=camera
		picture(tex,Rect2(0,0,1600,900),true)
	hotspot("next","点击或空格继续",Rect2(0,0,1600,900),func():advance_intro(1))
	if shot.get("presentation","")=="time_card":
		next_arrow=text("▼",Rect2(787,840,45,30),20,GOLD)
		button("settings","⚙ 设置",Rect2(1393,24,169,55),open_settings)
		return
	panel(Rect2(38,685,1524,192))
	var id=""
	for key in Home.NAMES:
		if Home.NAMES[key]==shot.speaker:id=key
	if shot.speaker in ["挑衅者","陌生男人"]:id="antagonist"
	speaker_portrait(id,Rect2(59,707,138,138))
	text(shot.speaker,Rect2(225,696,1150,37),26,GOLD)
	text(shot.line,Rect2(225,742,1245,86),26)
	next_arrow=text("▼",Rect2(787,840,45,30),20,GOLD)
	button("settings","⚙ 设置",Rect2(1393,24,169,55),open_settings)

func hotspot(id: String,tip: String,r: Rect2,action: Callable) -> Button:
	var node=Button.new()
	node.name=id;node.position=r.position;node.size=r.size
	node.tooltip_text=tip
	node.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","focus"]:node.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	node.pressed.connect(action)
	if id!="next":
		node.mouse_entered.connect(func():show_hotspot_hint(tip))
		node.mouse_exited.connect(func():show_hotspot_hint(""))
		node.focus_entered.connect(func():show_hotspot_hint(tip))
		node.focus_exited.connect(func():show_hotspot_hint(""))
	ui.add_child(node);buttons[id]=node
	return node

func show_hotspot_hint(words: String) -> void:
	if not is_instance_valid(hotspot_hint):
		hotspot_hint=Label.new();hotspot_hint.mouse_filter=Control.MOUSE_FILTER_IGNORE
		hotspot_hint.position=Vector2(360,92);hotspot_hint.size=Vector2(880,52)
		hotspot_hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		hotspot_hint.add_theme_font_size_override("font_size",25)
		hotspot_hint.add_theme_color_override("font_color",Color.WHITE)
		hotspot_hint.add_theme_color_override("font_outline_color",Color("152430"))
		hotspot_hint.add_theme_constant_override("outline_size",10)
		hotspot_hint.z_index=20;add_child(hotspot_hint)
	hotspot_hint.text=words

func fade_room() -> void:
	if transient:return
	if room_transition and room_transition.is_running():room_transition.kill()
	if not is_instance_valid(transition_cover):
		transition_cover=ColorRect.new();transition_cover.size=Vector2(1600,900)
		transition_cover.color=Color("111d29");transition_cover.mouse_filter=Control.MOUSE_FILTER_IGNORE
		transition_cover.z_index=25;add_child(transition_cover)
	transition_cover.modulate.a=.72
	room_transition=create_tween()
	room_transition.tween_property(transition_cover,"modulate:a",0.0,.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func speaker_portrait(id: String,r: Rect2) -> void:
	panel(r,"card")
	if Art.final_available("portrait."+id):picture(Art.texture("portrait."+id),r,true);return
	for i in range(C.PEOPLE.size()):
		if C.PEOPLE[i].id==id:picture(C.portrait(i),r,true);return
	if id=="xuan":
		var a=AtlasTexture.new()
		a.atlas=load("res://assets/earth/cast/轩轩-房间主人.png")
		a.region=Rect2(660,40,343,478)
		picture(a,r,true)
	else:text("旁白" if id=="" else "挑衅者",r,24,MUTED)

func change_room(id: String,via_map=false) -> void:
	var prior=model.s.home.room
	if transact(func():return model.enter_home_room(id,via_map)):
		navigate("base")
		if prior!=id:click_audio.play();fade_room()

func advance_intro(direction: int) -> void:
	if model.s.intro+direction>=shots.size():
		finish_intro()
		return
	model.s.intro=clampi(model.s.intro+direction,0,shots.size()-1)
	auto_clock=0
	save()
	draw_view()

func finish_intro() -> void:
	auto_read=false
	if not model.s.intro_done: Home.reroll(model.s.home)
	model.s.intro_done=true
	model.s.intro=shots.size()-1
	if save(): navigate("base")
	else: draw_view()

func history_screen() -> void:
	panel(Rect2(150,70,1300,760))
	text("剧情回看",Rect2(200,94,700,50),31)
	var scroll=ScrollContainer.new()
	scroll.position=Vector2(200,160)
	scroll.size=Vector2(1190,560)
	ui.add_child(scroll)
	var box=VBoxContainer.new()
	box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	for i in range(model.s.intro+1):
		var label=Label.new()
		label.text="%02d  %s：%s"%[i+1,shots[i].speaker,shots[i].line]
		label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size=Vector2(1150,60)
		box.add_child(label)
	button("back","返回画面",Rect2(1130,750,250,55),func(): navigate("intro"))

func base_screen() -> void:
	home_ui.draw("base")

func return_title() -> void:
	if save(): navigate("title")
	else: draw_view()

func open_settings() -> void:
	settings_return=view
	settings_page="root"
	navigate("settings")

func settings_screen() -> void:
	panel(Rect2(335,132,930,665))
	text({"root":"设置","audio":"音乐与音量","display":"画面","saves":"存档"}[settings_page],Rect2(390,169,790,60),36)
	if settings_page=="root":
		for i in range(3):
			var key=["audio","display","saves"][i]
			button(key,["音乐与音量","画面","存档"][i],Rect2(420,270+i*91,760,65),func():settings_page=key;draw_view())
		if settings_return=="intro":button("skip","跳过开场",Rect2(420,558,360,59),finish_intro)
		elif slot>0:button("replay","重看开场",Rect2(420,558,360,59),func():model.s.intro=0;replay=true;navigate("intro"),model.active() or not model.s.result.is_empty())
		button("title","返回标题",Rect2(816,558,360,59),return_title)
	elif settings_page=="audio":
		text("总音量",Rect2(420,303,230,55),26)
		var slider=HSlider.new()
		slider.position=Vector2(420,405);slider.size=Vector2(760,40)
		slider.min_value=0;slider.max_value=1;slider.step=.05;slider.value=settings.volume
		slider.value_changed.connect(func(value):settings.volume=value;apply_settings())
		ui.add_child(slider)
	elif settings_page=="display":
		button("large","大号文字："+("开" if settings.large else "关"),Rect2(420,300,760,65),func():settings.large=not settings.large;apply_settings();draw_view())
		button("fullscreen","全屏："+("开" if settings.fullscreen else "关"),Rect2(420,412,760,65),func():settings.fullscreen=not settings.fullscreen;apply_settings();draw_view())
	elif settings_page=="saves":
		text("当前记录 %d · 自动保存进度，旧版记录独立保留。"%slot,Rect2(420,280,755,85),25)
		button("save_now","保存当前记录",Rect2(420,418,760,65),func():if save():message="已保存当前记录。";draw_view(),slot==0)
		button("load_slots","查看三个记录位",Rect2(420,522,760,65),func():
			if save():slot_return="settings";navigate("slots"))
	button("back","返回" if settings_page!="root" else "保存并返回",Rect2(905,682,277,61),func():
		if settings_page!="root":settings_page="root";draw_view()
		elif transient or Store.new("user://earth/settings.json").save(settings):navigate(settings_return)
		else:message="设置保存失败，请重试。";draw_view())

func apply_settings() -> void:
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(.0001,settings.volume)))
	if DisplayServer.get_name()!="headless" and not transient:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func recovery_screen() -> void:
	panel(Rect2(300,220,1000,400))
	text("恢复记录",Rect2(350,260,900,50),34)
	text("主记录损坏时可读取上一次成功保存的备份。旧版记录不受影响。",Rect2(350,330,900,100),24)
	button("backup","读取备份",Rect2(370,495,400,64),func(): load_game(slot,true))
	button("back","返回标题",Rect2(800,495,400,64),func(): navigate("title"))

func _process(delta: float) -> void:
	if view=="intro" and is_instance_valid(next_arrow):
		next_arrow.position.y=839+sin(Time.get_ticks_msec()/220.0)*4
	if view=="battle" and not paused and model.active():
		tick_accumulator+=minf(delta,.25)*battle_speed
		while tick_accumulator>=1.0/60 and model.active():
			model.tick(1.0/60)
			tick_accumulator-=1.0/60
		if not model.events.is_empty():
			if not effect_audio.playing:
				for event in model.events:
					if event.type=="sound":play_effect(event.id);break
			model.events.clear()
		battlefield.queue_redraw()
		refresh_clock+=delta
		if refresh_clock>.15: refresh_clock=0; refresh_battle()
		save_clock+=delta
		if save_clock>=10:
			save_clock=0
			if not save(): paused=true;draw_view();return
		if not model.active():
			if save(): navigate("result")
			else: paused=true; draw_view()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if portal_opening:return
	if event.keycode==KEY_ESCAPE:
		if view=="battle": paused=not paused; refresh_battle()
		elif view=="intro": open_settings()
		elif view=="settings": navigate(settings_return)
		elif view=="base": open_settings()
		elif view=="equipment":navigate(equipment_return)
		elif view in ["map","squad","dialogue","printer","collection","growth","suits","room","support","missions"]: navigate("base")
		else: return_title()
	elif view=="intro":
		if event.keycode in [KEY_SPACE,KEY_RIGHT]: advance_intro(1)
		elif event.keycode==KEY_LEFT: advance_intro(-1)
	elif view=="battle":
		if event.keycode==KEY_SPACE: paused=not paused; refresh_battle()
		elif event.keycode==KEY_F1: model.invincible=not model.invincible; refresh_battle()

func transact(action: Callable) -> bool:
	var before=model.s.duplicate(true)
	if not action.call(): message=model.error; draw_view(); return false
	if not save(): model.s=before; draw_view(); return false
	message="已完成。"
	if view in ["growth","room","suits","support"]:play_effect("upgrade")
	draw_view()
	return true

func grow_member(kind: String) -> void:
	var before=model.stats(selected)
	if transact(func():return model.upgrade(selected,kind)):
		var after=model.stats(selected)
		message=C.PEOPLE[selected].name+" · "+("技能倍率 %.2f → %.2f"%[before.skill_factor,after.skill_factor] if kind=="talent" else "生命 %.0f → %.0f，攻击 %.1f → %.1f"%[before.hp,after.hp,before.atk,after.atk])
		draw_view()

func return_from_result(next: String="base") -> void:
	if transact(func():model.close_result();return true):
		navigate(next)
		fade_room()

func open_equipment(origin: String) -> void:
	equipment_return=origin
	if not model.s.inventory.is_empty():loot_selected=model.s.inventory[-1].id
	loot_page=0
	navigate("equipment")

func continue_after_result(stage: int) -> void:
	if transact(func():return model.continue_battle(stage)):
		paused=false;tick_accumulator=0;save_clock=0;refresh_clock=0
		navigate("battle")

func missions_screen() -> void:
	panel(Rect2(28,22,1544,856))
	text("异境之门",Rect2(60,42,560,69),43,GOLD)
	text("BOUNDARY / %03d"%selected_stage,Rect2(66,114,580,32),18,MUTED)
	text("异常记录 %d / 302 · 主线开放 %d"%[model.s.wins.size(),model.s.max_stage],Rect2(897,59,620,43),23,GOLD)
	var m=C.mission(selected_stage)
	var portal=PortalView.new()
	portal.position=Vector2(42,153);portal.size=Vector2(690,630)
	portal.destination=C.Anomalies.background(selected_stage) if m.has("anomaly") else Art.texture("battle.street.1" if m.bg=="street" else "battle."+m.bg)
	portal.opening=.48;portal.locked=not C.stage_unlocked(selected_stage,model.s.max_stage)
	ui.add_child(portal)
	text("%03d / %s"%[selected_stage,m.name],Rect2(700,169,800,58),32)
	text("首领：%s · 特征：%s"%[m.boss,m.mechanic],Rect2(700,236,800,43),22,GOLD)
	text(C.mechanic_tip(m.mechanic),Rect2(700,284,800,60),20,MUTED)
	button("kaidan_missions","常规异境" if mission_page==30 else "怪谈异境 · 新",Rect2(1258,117,246,40),func():mission_page=0 if mission_page==30 else 30;selected_stage=mission_page*10+1;draw_view())
	for i in range(2 if mission_page==30 else 10):
		var stage=mission_page*10+i+1
		var count=int(model.s.wins.get(str(stage),0))
		var label="锁定" if not C.stage_unlocked(stage,model.s.max_stage) else "已肃清 ×%d"%count if count>0 else "未探索"
		button("mission%d"%stage,"%03d  %s / %s"%[stage,C.mission(stage).name,label],Rect2(697+(i%2)*421,358+int(i/2)*68,402,57),func():selected_stage=stage;draw_view(),false,"primary" if stage==selected_stage else "neutral").add_theme_font_size_override("font_size",18)
	text("胜利：%d 积分 / %d 合金 / %d 核心 + 1 件装备"%[m.credits,m.alloy,m.cores],Rect2(698,709,800,43),21,GOLD)
	button("previous_page","上一组",Rect2(701,772,165,49),func():mission_page-=1;selected_stage=mission_page*10+1;draw_view(),mission_page in [0,30])
	button("next_page","下一组",Rect2(885,772,165,49),func():mission_page+=1;selected_stage=mission_page*10+1;draw_view(),mission_page>=29)
	text("怪谈异境 / 2 套" if mission_page==30 else "第 %d / 30 组"%(mission_page+1),Rect2(1074,778,208,35),18,MUTED)
	var unlocked=C.stage_unlocked(selected_stage,model.s.max_stage)
	text("已对准目标世界" if unlocked else "需先肃清第 %d 关"%(selected_stage-1),Rect2(72,773,545,37),22,GOLD)
	button("open_portal","开启异境" if unlocked else "尚未连接",Rect2(155,695,409,68),func():open_portal(portal),not unlocked,"primary")
	button("support","支援装置",Rect2(61,823,264,40),func():navigate("support"))
	button("back","关闭异境之门",Rect2(1298,814,225,49),func():navigate("base"))

func open_portal(portal: Control) -> void:
	if portal_opening or not C.stage_unlocked(selected_stage,model.s.max_stage):return
	portal_opening=true
	for b in buttons.values():b.disabled=true
	var stage=selected_stage
	var tween=create_tween()
	tween.tween_property(portal,"opening",1.0,.65).set_trans(Tween.TRANS_CUBIC)
	tween.tween_interval(.25)
	tween.tween_callback(func():
		portal_opening=false
		deploy(stage))

func deploy(stage: int) -> void:
	if transact(func():return model.depart(stage)):
		paused=false; tick_accumulator=0; save_clock=0
		navigate("battle")

func battle_screen() -> void:
	picture(Art.ui("topbar"),Rect2(0,0,1600,100))
	var m=C.mission(model.s.battle.stage)
	text("%02d / %s"%[m.stage,m.name],Rect2(30,8,550,54),30)
	battle_labels.scene=text("向右推进 · 肃清异常",Rect2(33,114,650,35),20,GOLD)
	if kaidan_preview:
		button("preview_hasshaku","八尺大人",Rect2(35,158,160,40),func():start_kaidan_preview(301))
		button("preview_kuchisake","裂口女",Rect2(205,158,160,40),func():start_kaidan_preview(302))
		for i in range(5):button("preview_segment_%d"%i,"第 %d 段"%(i+1),Rect2(710+i*135,112,123,40),func():preview_anomaly_segment(i))
	if stage01_preview:
		for i in range(5):
			button("preview_segment_%d"%i,"街景 %d"%(i+1),Rect2(710+i*135,112,123,40),func():preview_street_segment(i))
	var support_y=168
	for d in C.SUPPORTS:
		var installed=model.s.support.get(d.id,{})
		if installed.get("level",0)>0 and installed.get("enabled",false):
			battle_labels["support_"+d.id]=text("",Rect2(34,support_y,600,32),20,GOLD)
			support_y+=38
	if not model.gear_spirits().is_empty():
		battle_labels.gear=text("",Rect2(34,support_y,890,40),20,Color("a6de69"))
	battle_labels.progress=text("",Rect2(600,15,510,50),22)
	battle_labels.state=text("",Rect2(30,57,1050,31),18,GOLD)
	button("pause","暂停",Rect2(1130,20,145,58),func():paused=not paused;refresh_battle())
	button("speed","1×",Rect2(1290,20,105,58),func():battle_speed=2.0 if battle_speed==1 else 1.0;refresh_battle())
	button("recall","召回",Rect2(1410,20,155,58),func():
		if transact(func():return model.recall()): navigate("result"),false,"danger")
	picture(Art.ui("bottom_bar"),Rect2(0,792,1600,108))
	for i in range(5):
		var x=20+i*316
		picture(C.portrait(i),Rect2(x,808,57,78),true)
		text(C.PEOPLE[i].name+" · T%d"%model.s.people[i].suit,Rect2(x+68,799,216,30),21)
		text(model.stats(i).weapon,Rect2(x+68,829,235,26),17,GOLD)
		battle_labels["hp%d"%i]=text("",Rect2(x+68,857,235,28),18,MUTED)
	refresh_battle()

func refresh_battle() -> void:
	if view!="battle" or model.s.battle.is_empty() or battle_labels.is_empty():return
	var b=model.s.battle
	if C.Anomalies.has_stage(b.stage):battle_labels.scene.text=C.Anomalies.info(b.stage).scenes[clampi(b.encounter-1,0,4)].name
	battle_labels.progress.text="遭遇 %d / %d  ·  %02d:%02d"%[b.encounter,C.mission(b.stage).encounters,int(b.time)/60,int(b.time)%60]
	battle_labels.state.text=("已暂停  " if paused else "")+("F1 无敌已开启  " if model.invincible else "")+"空格暂停 · F1 测试无敌 · 召回保留掉落"
	buttons.pause.text="继续" if paused else "暂停"
	buttons.speed.text="%d×"%int(battle_speed)
	if battle_labels.has("gear"):
		var totals={}
		for spirit in model.gear_spirits():
			if b.units[spirit.owner].hp>0:totals[spirit.kind]=int(totals.get(spirit.kind,0))+1
		var words=PackedStringArray()
		for kind in totals:words.append(Loot.SPECIAL_NAMES[kind]+" ×"+str(totals[kind]))
		battle_labels.gear.text="装备召唤 / "+("佩戴者已倒下" if words.is_empty() else " · ".join(words))
	for d in C.SUPPORTS:
		var key="support_"+d.id
		if battle_labels.has(key):
			var remain=maxf(0.0,d.interval-float(b.support_clock.get(d.id,0.0)))
			var state="等待遭遇" if model.alive(1).is_empty() else ("暂停" if paused else "%.1f 秒后触发"%remain)
			battle_labels[key].text=d.name+" Lv.%d · "%model.s.support[d.id].level+state
	for i in range(5):
		var u=b.units[i]
		battle_labels["hp%d"%i].text="%d / %d"%[ceili(u.hp),ceili(u.max_hp)] if u.hp>0 else "已倒下"

func result_screen() -> void:
	var r=model.s.result
	if r.is_empty():navigate("base");return
	if stage01_preview:button("preview_restart","重置第一关测试",Rect2(1140,27,365,55),start_stage01_preview)
	elif kaidan_preview:button("preview_restart","重置怪谈测试",Rect2(1140,27,365,55),func():start_kaidan_preview(r.stage))
	panel(Rect2(245,103,1110,728))
	var title={"victory":"异常肃清","recall":"小队已召回","defeat":"小队失去战斗能力"}[r.reason]
	text(title,Rect2(290,132,1020,72),43,GOLD)
	text("%03d / %s"%[r.stage,C.mission(r.stage).name],Rect2(294,210,1010,49),29)
	text("%d 积分   /   %d 合金   /   %d 核心"%[r.credits,r.alloy,r.cores],Rect2(294,274,1010,49),28)
	text("用时 %.1f 秒 · 击败 %d · 伤害 %.0f · 治疗 %.0f"%[r.time,r.killed,r.damage,r.healing],Rect2(294,330,1010,39),21,MUTED)
	var drops=r.get("loot",[])
	if not drops.is_empty():
		var item=drops[0]
		picture(Art.texture("equipment."+str(item.base)),Rect2(292,382,55,55),true)
		text("战利品 / %s · %s"%[Loot.QUALITY[item.quality-1],Loot.name_of(item)],Rect2(360,384,940,47),28,Loot.COLORS[item.quality-1])
		text(Loot.affix_text(item).replace("\n","   /   "),Rect2(294,436,1010,44),22)
		text(Loot.special_text(item),Rect2(294,485,1010,67),23,GOLD)
	else:text("本次带回已击败目标的资源。肃清首领可获得装备。",Rect2(294,405,1010,90),25,MUTED)
	var unlocks="解锁："+" / ".join(r.get("unlocks",[])) if not r.get("unlocks",[]).is_empty() else "继续挑战会恢复队伍状态；战利品已保存。"
	text(unlocks,Rect2(294,566,1010,48),21,GOLD)
	var next=C.next_stage(r.stage)
	var can_next=r.reason=="victory" and next>0
	button("continue_next","继续下一异常" if can_next else "已到本阶段终点" if next==0 else "胜利后开放下一关",Rect2(292,636,487,63),func():continue_after_result(next),not can_next,"primary")
	button("repeat","再次挑战本关",Rect2(805,636,487,63),func():continue_after_result(r.stage))
	button("loot","整理战利品",Rect2(292,732,313,58),func():open_equipment("result"))
	button("return_grow","返家培养",Rect2(635,732,313,58),func():return_from_result("growth"))
	button("return","返回房间",Rect2(979,732,313,58),func():return_from_result())

func sixty() -> float: return 60.0

func member_tabs() -> void:
	for i in range(5):
		button("person%d"%i,C.PEOPLE[i].name,Rect2(50+i*306,125,284,57),func():selected=i;draw_view(),false,"primary" if selected==i else "neutral")

func suits_screen() -> void:
	text("战斗套装",Rect2(50,35,720,65),38)
	text("衣服武器整套穿戴 · 制造请到工作间",Rect2(925,47,600,42),23,GOLD)
	member_tabs()
	var person=model.s.people[selected]
	for i in range(C.SUITS.size()):
		var suit=C.SUITS[i]
		var x=50+i*508
		panel(Rect2(x,220,480,570))
		text(suit.name,Rect2(x+25,247,430,50),30,GOLD)
		text(suit.weapons[selected],Rect2(x+25,305,430,44),28)
		if Art.final_available("suit.%s.t%d"%[C.PEOPLE[selected].id,suit.tier]):
			picture(Art.texture("suit.%s.t%d"%[C.PEOPLE[selected].id,suit.tier]),Rect2(x+25,365,428,190),true)
		else:text(suit.look,Rect2(x+25,379,428,110),23,MUTED)
		var current=model.stats(selected)
		var preview=model.preview_suit(selected,suit.tier)
		text("生命 %.0f → %.0f · 攻击 %.1f → %.1f\n"%[current.hp,preview.hp,current.atk,preview.atk]+("初始配发" if suit.unlock==0 else "空间 T%d · 第 %d 关配方"%[suit.room,suit.unlock]),Rect2(x+25,508,430,88),21)
		var owns=suit.tier in person.owned_suits
		if owns:
			button("equip%d"%suit.tier,"已穿戴" if person.suit==suit.tier else "整套穿戴",Rect2(x+25,679,430,65),func():transact(func():return model.equip_suit(selected,suit.tier)),person.suit==suit.tier,"primary")
		else:
			text("%d 积分 · %d 合金 · %d 核心"%[suit.credits,suit.alloy,suit.cores],Rect2(x+25,614,430,38),20,GOLD)
			button("make%d"%suit.tier,"制造整套" if model.s.home.room=="workroom" else "请到工作间制造",Rect2(x+25,679,430,65),func():transact(func():return model.make_suit(selected,suit.tier)),model.s.home.room!="workroom")
	if model.s.home.room!="workroom":button("goto_printer","前往工作间",Rect2(900,827,325,54),func():change_room("workroom",true);navigate("printer"))
	button("back","返回房间",Rect2(1270,827,270,54),func(): navigate("base"))

func growth_screen() -> void:
	button("equipment","装备与词条",Rect2(50,827,345,54),func():open_equipment("growth"),false,"primary")
	button("wear","已拥有的套装",Rect2(895,827,330,54),func():navigate("suits"))
	text("战士培养",Rect2(50,35,720,65),38)
	text("积分 %d · 合金 %d"%[model.s.credits,model.s.alloy],Rect2(925,47,600,42),23,GOLD)
	member_tabs()
	var p=model.s.people[selected]
	var d=model.stats(selected)
	picture(C.portrait(selected),Rect2(70,235,315,392),true)
	text("生命 %d   攻击 %d\n防御 %d   %s"%[d.hp,d.atk,d.armor,d.weapon],Rect2(65,665,365,110),22)
	var labels={"level":"个人成长","equipment":"模组强化","talent":"个人天赋"}
	var notes={"level":"提升基础生命和攻击，体型不变。","equipment":"强化内置模块，提供生命、攻击和防御；不改变外形。","talent":"%s · 技能倍率 ×%.2f；不提高普通攻击属性。"%[C.PEOPLE[selected].skill,d.skill_factor]}
	for i in range(3):
		var key=["level","equipment","talent"][i]
		var y=225+i*184
		panel(Rect2(435,y,1110,167))
		text("%s  Lv.%d"%[labels[key],p[key]],Rect2(462,y+14,600,45),29,GOLD)
		var preview=model.preview_growth(selected,key)
		text(notes[key],Rect2(462,y+65,685,43),18,MUTED)
		var comparison="当前空间已达上限"
		if not preview.is_empty():comparison="技能倍率 %.2f → %.2f"%[d.skill_factor,preview.skill_factor] if key=="talent" else "生命 %.0f → %.0f · 攻击 %.1f → %.1f · 防御 %.1f → %.1f"%[d.hp,preview.hp,d.atk,preview.atk,d.armor,preview.armor]
		text(comparison,Rect2(462,y+108,685,38),20,GOLD)
		var cost=model.upgrade_cost(selected,key)
		button("upgrade_"+key,"升级\n%d 积分 / %d 合金"%[cost.credits,cost.alloy],Rect2(1170,y+43,346,85),func():grow_member(key),preview.is_empty())
	button("back","返回房间",Rect2(1270,827,270,54),func(): navigate("base"))

func room_screen() -> void:
	panel(Rect2(150,100,1300,696))
	text("主神空间 T%d"%model.s.room,Rect2(200,139,1000,70),40)
	text("空间等级控制制造权限、培养上限与支援升级上限。",Rect2(200,230,1160,75),27,MUTED)
	text("个人成长上限 Lv.%d\n模组强化上限 Lv.%d\n个人天赋上限 Lv.%d"%[model.s.room*15,model.s.room*10,mini(10,model.s.room*3)],Rect2(200,325,1080,160),29)
	var cost=model.room_cost()
	text("空间已达本阶段最高等级 T10。" if model.s.room>=10 else "下一级：完成第 %d 关\n%d 积分 / %d 合金 / %d 核心 · 核心可重复挑战每三关的任务获得"%[cost.gate,cost.credits,cost.alloy,cost.cores],Rect2(200,536,1160,100),24,GOLD)
	button("room_upgrade","升级空间",Rect2(840,687,535,64),func():transact(model.upgrade_room),model.s.room>=10,"primary")
	button("back","返回房间",Rect2(200,687,260,64),func():navigate("base"))

func support_screen() -> void:
	button("equipment","查看装备召唤",Rect2(50,827,330,54),func():open_equipment("squad"))
	text("带回来的力量",Rect2(50,40,1050,70),38)
	text("空间装置与穿戴装备的召唤支援可同时生效。",Rect2(50,121,1400,55),26,MUTED)
	for i in range(C.SUPPORTS.size()):
		var d=C.SUPPORTS[i]
		var p=model.s.support.get(d.id,{"level":0,"enabled":false})
		var x=50+i*508
		panel(Rect2(x,230,480,554))
		text(d.name,Rect2(x+25,254,430,60),31,GOLD)
		if Art.final_available("support."+d.id):picture(Art.texture("support."+d.id),Rect2(x+25,323,425,125),true)
		else:text(d.description,Rect2(x+25,333,425,116),23)
		var unlocked=model.s.support.has(d.id)
		text("Lv.%d  /  %s"%[p.level,"运行中" if p.enabled else "未启用"] if unlocked else "完成第 %d 关解锁"%d.unlock,Rect2(x+25,488,425,50),24,MUTED)
		var cost=model.support_cost(d.id)
		text("已达当前空间上限" if p.level>=mini(10,model.s.room*2) else "下级："+model.support_preview(d.id,true),Rect2(x+25,438,425,55),18,GOLD)
		button("buy_"+d.id,("购置" if p.level==0 else "升级")+" · %d 积分\n%d 合金 / %d 核心"%[cost.credits,cost.alloy,cost.cores],Rect2(x+25,565,430,82),func():transact(func():return model.upgrade_support(d.id)),not unlocked or p.level>=mini(10,model.s.room*2))
		button("toggle_"+d.id,"停用" if p.enabled else "启用",Rect2(x+25,675,430,62),func():transact(func():return model.toggle_support(d.id)),p.level==0)
	button("back","返回房间",Rect2(1270,827,270,54),func(): navigate("base"))

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		if save(): get_tree().quit()
		else: draw_view()
