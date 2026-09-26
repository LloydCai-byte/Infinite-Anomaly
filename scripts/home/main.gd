extends Control
const UI = preload("res://scripts/home/ui.gd")
const Room = preload("res://scripts/home/room.gd")
const Phone = preload("res://scripts/home/phone.gd")
const Door = preload("res://scripts/home/door.gd")
var room
var overlay: Control
var overlay_kind: String = ""
var hint: Label
var subtitle: Label
var location_label: Label
var flash: ColorRect
var pocket: Button
var pocket_notice: Label
var toast_label: Label
var toast_panel: Panel
var toast_time: float = 0.0
var transition: Tween
var sfx: AudioStreamPlayer
var ambience: AudioStreamPlayer
var hints_left: float = 15.0
var audio_cache: Dictionary = {}

func _ready() -> void:
	theme = UI.theme()
	get_window().min_size = Vector2i(1152,648)
	room = Room.new()
	UI.place(room,self,Rect2(0,0,1920,1080))
	room.activated.connect(activate)
	room.hovered.connect(func(value):hint.text=value;hint.visible=value!="")
	room.set_room(Home.model.s.room)
	var top_shade = UI.line(self,Rect2(0,0,1920,92),Color(0.015,0.02,0.018,0.08))
	top_shade.visible = false
	top_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	location_label = UI.text(self,Room.ROOMS[room.room_id].title,Rect2(55,38,500,37),24,Color(1,0.97,0.89,0.86))
	hint = UI.text(self,"",Rect2(0,0,280,43),20)
	hint.add_theme_color_override("font_shadow_color",Color.BLACK)
	hint.add_theme_constant_override("shadow_offset_x",1)
	hint.add_theme_constant_override("shadow_offset_y",1)
	hint.visible = false
	subtitle = UI.text(self,"鼠标探索房间  ·  P 手机  ·  Tab 查看可交互物件",Rect2(400,1028,1090,31),18,Color(1,0.97,0.91,0.72))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pocket = UI.button(self,"",Rect2(1770,906,89,158),open_phone)
	pocket.name = "PocketPhone"
	pocket.rotation_degrees = -5
	pocket.pivot_offset = Vector2(45,130)
	pocket.add_theme_stylebox_override("normal",UI.box(Color("#111819"),Color("#889086"),17,2))
	pocket.add_theme_stylebox_override("hover",UI.box(Color("#26362e"),UI.GOLD,17,2))
	UI.panel(pocket,Rect2(30,8,28,4),Color("#606761"),3).mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.text(pocket,"23\n59",Rect2(17,32,60,79),29,UI.INK,true)
	UI.line(pocket,Rect2(26,141,37,3),Color("#6c7871"))
	pocket_notice = UI.text(pocket,"·",Rect2(64,4,22,28),28,UI.GOLD)
	pocket.tooltip_text = "手机 · P"
	toast_panel = UI.panel(self,Rect2(440,941,1040,72),Color(0.055,0.075,0.064,0.94),8,Color("#758376"))
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_label = UI.text(toast_panel,"",Rect2(22,11,996,52),22,UI.INK,true)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_panel.visible = false
	flash = UI.line(self,Rect2(0,0,1920,1080),Color(1,0.99,0.94,0))
	sfx = AudioStreamPlayer.new()
	add_child(sfx)
	ambience = AudioStreamPlayer.new()
	add_child(ambience)
	ambience.stream = make_tone("ambient")
	ambience.volume_db = -45
	ambience.play()
	Home.event.connect(on_event)
	Home.changed.connect(room.sync_memory)
	if Home.fault != "":
		show_fault()
	elif not Home.model.s.intro:
		show_intro()
	elif Home.model.s.mode == "GAMEOVER":
		show_gameover()
	elif Home.model.s.mode == "ENDING" and not Home.model.s.ending_seen:
		show_ending()
	if "--home-smoke" in OS.get_cmdline_user_args():
		call_deferred("smoke")
	if "--home-capture" in OS.get_cmdline_user_args():
		call_deferred("capture_all")

func _process(delta: float) -> void:
	var p: Vector2 = get_local_mouse_position()
	hint.position = Vector2(clampf(p.x+19,20,1620),clampf(p.y+24,20,991))
	toast_time = maxf(0,toast_time-delta)
	toast_panel.visible = toast_time > 0
	toast_panel.position.x = 100 if overlay_kind == "phone" else 440
	hints_left = maxf(0,hints_left-delta)
	subtitle.visible = hints_left > 0 and not is_instance_valid(overlay)
	pocket_notice.visible = Home.model.s.food < 25 or Home.model.s.xp >= 3 or Home.model.s.mode == "MEMORY"
	ambience.volume_db = -80 if Home.model.s.muted else linear_to_db(maxf(0.001,Home.model.s.volume*0.014))
	location_label.modulate.a = 1.0 if hints_left > 0 else 0.52

func activate(action: String, arg: String) -> void:
	if Home.fault != "" or Home.model.s.mode == "GAMEOVER":
		return
	match action:
		"room": change_room(arg)
		"phone": open_phone()
		"door":
			if Home.model.s.mode == "ENDING": show_ending()
			else: open_door()
		"look": toast(arg);play_sound("tap")

func change_room(id: String, animate: bool = true) -> void:
	if not Room.ROOMS.has(id):
		return
	if is_instance_valid(transition):
		transition.kill()
	if animate and not Home.model.s.reduced_motion:
		room.modulate = Color(0.83,0.82,0.8,1)
		transition = create_tween()
		transition.tween_property(room,"modulate",Color.WHITE,0.22)
	room.set_room(id)
	Home.model.s.room = id
	location_label.text = Room.ROOMS[id].title
	hint.visible = false
	hints_left = maxf(hints_left,3)
	if animate:
		play_sound("step")

func clear_overlay() -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null
	overlay_kind = ""
	room.locked = false
	Home.paused = false
	pocket.visible = Home.model.s.mode != "GAMEOVER"
	hint.visible = false

func modal(kind: String) -> Control:
	clear_overlay()
	overlay_kind = kind
	overlay = Control.new()
	UI.place(overlay,self,Rect2(0,0,1920,1080))
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	room.locked = true
	pocket.visible = false
	hint.visible = false
	move_child(flash,-1)
	return overlay

func open_phone() -> void:
	if Home.fault != "" or Home.model.s.mode == "GAMEOVER":
		return
	clear_overlay()
	overlay_kind = "phone"
	overlay = Phone.new()
	add_child(overlay)
	overlay.closed.connect(clear_overlay)
	overlay.feedback.connect(func(message):play_sound("tap"))
	overlay.memory_requested.connect(open_door)
	room.locked = true
	pocket.visible = false
	hint.visible = false
	move_child(flash,-1)
	play_sound("tap")

func open_door(index: int = -1) -> void:
	if Home.fault != "" or Home.model.s.mode == "GAMEOVER":
		return
	clear_overlay()
	overlay_kind = "door"
	overlay = Door.new()
	overlay.selected_index = index
	add_child(overlay)
	overlay.closed.connect(clear_overlay)
	overlay.phone_requested.connect(open_phone)
	room.locked = true
	pocket.visible = false
	move_child(flash,-1)
	play_sound("tap")

func toast(value: String, duration: float = 5.5) -> void:
	toast_label.text = value
	toast_time = duration
	move_child(toast_panel,-1)
	move_child(flash,-1)

func flash_return() -> void:
	var tween = create_tween()
	flash.color.a = 0.18 if Home.model.s.reduced_motion else 0.66
	tween.tween_property(flash,"color:a",0.0,0.65)
	play_sound("return")

func on_event(kind: String) -> void:
	match kind:
		"departed":
			if overlay_kind == "door":
				clear_overlay()
			change_room("entry",false)
			flash_return()
			toast("你回来了。第 %03d 个你，正在接收上一段记忆。" % Home.model.s.generation)
		"settled":
			room.sync_memory()
			play_sound("memory")
			if Home.model.s.mode == "ENDING":
				show_ending()
			else:
				var r: Dictionary = Home.model.s.result
				toast(("记忆已推进" if r.success else "记忆已留下")+"  ·  "+Home.model.db.stages[r.stage].memory+"  ·  经验 +%d"%r.xp)
		"low": toast("生活储备不足 25。手机里可以补充食物。",8)
		"critical": toast("生活储备即将耗尽。请打开手机补给。",10)
		"gameover": show_gameover()
		"fault": show_fault()
		"saved": pass
		"restored":
			clear_overlay()
			change_room(Home.model.s.room,false)
			if not Home.model.s.intro:
				show_intro()
			else:
				toast("已回到最近一次存档。")

func show_intro() -> void:
	var root = modal("intro")
	UI.line(root,Rect2(0,0,1920,1080),Color(0.03,0.035,0.028,0.68))
	var card = UI.panel(root,Rect2(190,178,808,714),Color("#161e1b"),4,Color("#7d8e76"))
	UI.text(card,"无限异常",Rect2(45,34,713,76),50)
	UI.text(card,"你住在七楼。",Rect2(45,142,713,51),30,UI.GOLD)
	UI.text(card,"可今天，门外不是走廊。\n\n窗户打不开。手机失去了普通的功能，\n却连上了一个没有名字的地方。\n\n家里的食物还够生活一阵。\n在它耗尽以前，你需要开一次门。",Rect2(45,218,719,309),25,UI.INK,true)
	UI.text(card,"点物件探索房间 · P 打开手机 · Esc 暂停",Rect2(45,550,719,40),20,UI.MUTED)
	var b = UI.button(card,"起身",Rect2(45,616,719,57),func():Home.action("intro");clear_overlay();toast("房门就在眼前。手机可以随时拿出来。",7),true)
	b.name = "Begin"
	b.grab_focus()

func show_pause() -> void:
	if Home.model.s.mode == "GAMEOVER":
		return
	var root = modal("pause")
	Home.paused = true
	UI.line(root,Rect2(0,0,1920,1080),Color(0.025,0.035,0.029,0.64))
	var p = UI.panel(root,Rect2(645,206,630,671),UI.SCREEN,20,Color("#576a5a"))
	UI.text(p,"片刻停留",Rect2(40,31,550,61),36)
	UI.text(p,"此时生活消耗和记忆接收都已暂停。",Rect2(40,110,550,42),21,UI.MUTED)
	UI.button(p,"回到房间",Rect2(40,177,550,57),clear_overlay,true).name="Resume"
	UI.button(p,"音效  "+("关" if Home.model.s.muted else "开"),Rect2(40,252,265,52),func():Home.model.s.muted=not Home.model.s.muted;show_pause()).name="Sound"
	UI.button(p,"减少动效  "+("开" if Home.model.s.reduced_motion else "关"),Rect2(322,252,268,52),func():Home.model.s.reduced_motion=not Home.model.s.reduced_motion;show_pause()).name="Motion"
	UI.text(p,"音量",Rect2(40,332,100,37),22)
	var volume = HSlider.new()
	UI.place(volume,p,Rect2(147,337,440,31))
	volume.min_value=0
	volume.max_value=1
	volume.step=0.05
	volume.value=Home.model.s.volume
	volume.value_changed.connect(func(value):Home.model.s.volume=value)
	UI.text(p,"每 20 分钟自动存档，保留 3 份轮换备份。\n保存退出会另存当前进度。\n最近保存："+Home.last_save,Rect2(40,402,550,104),20,UI.MUTED,true)
	UI.button(p,"保存并退出",Rect2(40,549,550,57),Home.quit_safely).name="SaveQuit"

func show_gameover() -> void:
	var root = modal("gameover")
	UI.line(root,Rect2(0,0,1920,1080),Color(0.023,0.031,0.025,0.90))
	UI.text(root,"GAME OVER",Rect2(490,270,940,75),58,UI.MUTED).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	UI.text(root,"这一次，没有新的你醒来。",Rect2(400,396,1120,58),35).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	UI.text(root,"生活储备已经耗尽。\n这一刻不会覆盖存档。",Rect2(570,496,780,92),25,UI.MUTED,true).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var b=UI.button(root,"从最近存档继续",Rect2(663,666,594,65),func():Home.reload_checkpoint(),true)
	b.name="LoadCheckpoint"
	UI.button(root,"退出",Rect2(663,752,594,55),func():get_tree().quit())
	b.grab_focus()

func show_ending() -> void:
	var root=modal("ending")
	Home.model.s.ending_seen=true
	UI.image(root,"res://assets/memory/ending.png",Rect2(0,0,1920,1080))
	var shade=UI.line(root,Rect2(0,0,1060,1080),Color(0.055,0.061,0.05,0.80))
	UI.text(root,"终章 / 归家",Rect2(110,124,795,43),23,UI.GOLD)
	UI.text(root,Home.model.db.ending.title,Rect2(110,210,860,155),47,UI.INK,true)
	UI.text(root,"\n\n".join(Home.model.db.ending.lines),Rect2(110,391,805,423),25,UI.INK,true)
	UI.text(root,"那些没有回来的你，都没有白走。",Rect2(110,855,805,47),27,UI.GOLD)
	UI.button(root,"留在这一刻",Rect2(110,945,340,61),func():clear_overlay();room.background.texture=load("res://assets/memory/ending.png");room.portal.visible=false;room.marker.visible=false)
	if not Home.transient:
		Home.persist()

func show_fault() -> void:
	var root=modal("fault")
	Home.paused=true
	UI.line(root,Rect2(0,0,1920,1080),Color(0.03,0.04,0.033,0.88))
	UI.text(root,"存档需要处理",Rect2(510,290,900,62),40)
	UI.text(root,Home.fault,Rect2(510,386,900,135),26,UI.WARNING,true)
	UI.button(root,"尝试恢复最近可用备份",Rect2(510,579,900,65),func():Home.reload_checkpoint(),true)
	UI.button(root,"重试保存当前进度",Rect2(510,663,900,60),func():Home.fault="";if Home.persist():clear_overlay())
	UI.button(root,"保留存档文件并退出",Rect2(510,744,900,60),func():get_tree().quit())

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_F11:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
		KEY_P:
			if overlay_kind=="phone": clear_overlay()
			elif overlay_kind not in ["intro","gameover","fault","ending","pause"]:open_phone()
		KEY_TAB:
			room.show_targets=not room.show_targets
			room.queue_redraw()
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			if overlay_kind in ["phone","door","pause"]:clear_overlay()
			elif overlay_kind=="":show_pause()
		KEY_BACKSPACE:
			if overlay_kind in ["phone","door"]:clear_overlay()
			elif overlay_kind=="":change_room(Room.ROOMS[room.room_id].back)

func make_tone(kind: String) -> AudioStreamWAV:
	if audio_cache.has(kind):
		return audio_cache[kind]
	var stream=AudioStreamWAV.new()
	stream.format=AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate=22050
	var seconds: float=2.0 if kind=="ambient" else (0.45 if kind=="return" else 0.17)
	var count: int=int(seconds*22050)
	var samples=PackedByteArray()
	samples.resize(count*2)
	for i in range(count):
		var t: float=float(i)/22050.0
		var value: float
		if kind=="ambient":
			value=0.45*sin(TAU*50*t)+0.18*sin(TAU*100*t)
		else:
			var freq: float=90.0 if kind=="step" else (310.0 if kind=="memory" else (180.0 if kind=="return" else 530.0))
			value=sin(TAU*freq*t)*exp(-t*(9.0 if kind=="return" else 35.0))*0.28
		samples.encode_s16(i*2,int(clampf(value,-1,1)*32767))
	stream.data=samples
	if kind=="ambient":
		stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin=0
		stream.loop_end=count
	audio_cache[kind]=stream
	return stream

func play_sound(kind: String) -> void:
	if Home.model.s.muted:
		return
	sfx.stream=make_tone(kind)
	sfx.volume_db=linear_to_db(maxf(0.001,Home.model.s.volume*0.30))
	sfx.play()

func _exit_tree() -> void:
	for player in [sfx, ambience]:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	audio_cache.clear()

func smoke() -> void:
	Home.paused=true
	clear_overlay()
	Home.model.s.intro=true
	for id in Room.ROOMS:
		change_room(id,false)
		await get_tree().process_frame
	open_phone()
	for p in ["home","skills","memories","supply"]:
		overlay.page=p
		overlay.render()
		await get_tree().process_frame
	open_door()
	await get_tree().process_frame
	print("HOME SMOKE: rooms, phone pages and door instantiated")
	clear_overlay()
	_exit_tree()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()

func save_capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.local/home-captures/"+filename+".png")

func capture_all() -> void:
	Home.paused=true
	Home.model.s.intro=true
	clear_overlay()
	Home.paused=true
	await get_tree().process_frame
	for id in Room.ROOMS:
		change_room(id,false)
		await save_capture(id)
	change_room("entry",false)
	Home.model.s.xp=18
	Home.model.s.food=63
	Home.model.s.cards={"R01":3,"R02":1,"R03":2}
	open_phone()
	for p in ["home","skills","memories","supply"]:
		overlay.page=p
		overlay.render()
		await save_capture("phone_"+p)
	clear_overlay()
	Home.paused=false
	Home.model.depart()
	Home.model.s.remaining=11
	open_door()
	await save_capture("door_memory")
	clear_overlay()
	show_gameover()
	await save_capture("gameover")
	show_ending()
	await save_capture("ending")
	print("HOME CAPTURE: completed")
	get_tree().quit()
