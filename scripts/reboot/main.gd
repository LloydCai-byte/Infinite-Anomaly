extends Control
const Model=preload("res://scripts/reboot/model.gd")
const C=preload("res://scripts/reboot/catalog.gd")
const Art=preload("res://scripts/reboot/art.gd")
const Store=preload("res://scripts/reboot/save_store.gd")
const World=preload("res://scripts/reboot/world.gd")
const Interface=preload("res://scripts/reboot/interface.gd")
var model=Model.new()
var store: RefCounted
var slot=0
var view="title"
var page=""
var history: Array=[]
var payload: Dictionary={}
var ui: RefCounted
var world: Control
var ui_root: Control
var overlay: Control
var toast_label: Label
var toast_clock=0.0
var clock=0.0
var checkpoint=0.0
var refresh_clock=0.0
var auto_timer=-1.0
var committed: Dictionary={}
var busy=false
var transient=false
var fault=""
var recovery_slot=0
var settings_draft: Dictionary={}
var music: AudioStreamPlayer
var sound_players: Array=[]
var music_id=""
var last_sound=0.0
var animation_clock=0.0

func _ready() -> void:
	get_window().content_scale_size=Vector2i(1600,900)
	get_window().content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_aspect=Window.CONTENT_SCALE_ASPECT_KEEP
	get_window().min_size=Vector2i(1280,720)
	transient="--reboot-test" in OS.get_cmdline_user_args() or "--reboot-capture" in OS.get_cmdline_user_args()
	var font=SystemFont.new()
	font.font_names=PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei","Noto Sans CJK SC","sans-serif"])
	var skin=Theme.new()
	skin.default_font=font
	skin.default_font_size=21
	theme=skin
	var settings=Store.new("user://reboot/settings.json").load_primary()
	if not settings.is_empty(): model.s.settings.merge(settings,true)
	Art.initialize()
	world=World.new()
	world.game=self
	world.size=Vector2(1600,900)
	add_child(world)
	ui_root=Control.new()
	ui_root.size=Vector2(1600,900)
	ui_root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(ui_root)
	overlay=Control.new()
	overlay.size=Vector2(1600,900)
	overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	ui=Interface.new(self)
	toast_label=Label.new()
	toast_label.position=Vector2(310,719)
	toast_label.size=Vector2(980,48)
	toast_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size",23)
	toast_label.add_theme_color_override("font_color",Color("f5dfae"))
	toast_label.add_theme_color_override("font_shadow_color",Color("132126"))
	toast_label.add_theme_constant_override("shadow_outline_size",6)
	toast_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(toast_label)
	if DisplayServer.get_name()!="headless":
		music=AudioStreamPlayer.new()
		add_child(music)
		for i in range(8):
			var a=AudioStreamPlayer.new()
			add_child(a)
			sound_players.append(a)
	get_tree().auto_accept_quit=false
	committed=model.s.duplicate(true)
	render()

func slot_store(n: int) -> RefCounted:
	return Store.new("user://reboot/slot%d.json"%n)

func render() -> void:
	ui.draw()
	set_music("battle" if view=="battle" else "base")
	world.queue_redraw()

func open(name: String, args: Dictionary={}) -> void:
	if name=="settings": settings_draft=model.s.settings.duplicate(true)
	history.append({"page":page,"payload":payload.duplicate(true)})
	page=name
	payload=args
	auto_timer=-1
	render()

func back() -> void:
	if page=="intro":
		open("pause")
		return
	if page=="result":
		go_base()
		return
	if page=="recovery":
		view="title"
		history.clear()
		page=""
		fault=""
	elif page=="settings":
		set_volume(float(model.s.settings.volume))
		restore_page()
	elif not history.is_empty(): restore_page()
	elif page!="": page=""
	elif view=="battle": open("pause")
	elif view=="base": open("pause")
	else: open("quit")
	auto_timer=-1
	render()

func restore_page() -> void:
	if history.is_empty(): page=""
	else:
		var r=history.pop_back()
		page=r.page
		payload=r.payload

func go_base() -> void:
	view="base"
	page=""
	history.clear()
	model.s.result={}
	if not model.active(): model.s.battle={}
	commit()
	render()

func new_game(n: int, base_name: String) -> bool:
	if slot_store(n).exists():
		toast("这个存档位已有记录，请选择空存档位。")
		return false
	var previous=model.s.duplicate(true)
	var settings=model.s.settings.duplicate(true)
	model.reset(base_name.strip_edges().left(16) if base_name.strip_edges()!="" else "第 07 号基地")
	model.s.settings=settings
	slot=n
	store=slot_store(slot)
	committed=previous
	if not commit(): return false
	view="base"
	page="intro"
	history.clear()
	render()
	return true

func load_game(n: int) -> bool:
	var candidate=slot_store(n)
	var data=candidate.load_primary()
	if data.is_empty() or not model.import_state(data):
		recovery_slot=n
		fault=model.error if not data.is_empty() else "这个存档无法通过完整性校验。可以尝试恢复最近备份，原文件不会被自动覆盖。"
		page="recovery"
		render()
		return false
	slot=n
	store=candidate
	committed=model.s.duplicate(true)
	view="battle" if model.active() or not model.s.result.is_empty() else "base"
	page="result" if not model.s.result.is_empty() else ("" if model.s.intro_done else "intro")
	history.clear()
	auto_timer=-1
	render()
	return true

func commit() -> bool:
	if slot==0 or transient:
		committed=model.s.duplicate(true)
		model.dirty=false
		return true
	model.s.saved_at=Time.get_unix_time_from_system()
	if store!=null and store.save(model.s):
		committed=model.s.duplicate(true)
		model.dirty=false
		return true
	fault="保存失败，本次修改已撤回。"+(store.error if store!=null else "未找到存档服务。")
	model.s=committed.duplicate(true)
	model.events.clear()
	model.dirty=false
	page="save_error"
	render()
	return false

func perform(action: String, value: Variant=null) -> bool:
	if busy: return false
	busy=true
	var before=model.s.duplicate(true)
	model.error=""
	model.notice=""
	var ok=true
	match action:
		"upgrade": ok=model.upgrade(int(model.s.selected_person),str(value))
		"manufacture": ok=model.manufacture(int(value.role),str(value.slot),int(value.mk))
		"equip": ok=model.equip(int(model.s.selected_person),str(value))
		"dismantle": ok=model.dismantle(str(value))
		"train": ok=model.train()
		"cancel_training": ok=model.cancel_training()
		"facility": ok=model.facility()
		"depart": ok=model.depart(str(value))
		"recall": ok=model.recall()
		"intro":
			model.s.intro+=1
			if model.s.intro>=C.INTRO.size(): model.s.intro_done=true
		"speed": model.s.speed=2 if model.s.speed==1 else 1
		"auto": model.s.auto=str(value)
		_: ok=false
	if ok:
		if not commit():
			busy=false
			return false
		if action=="depart":
			view="battle"
			page=""
			history.clear()
			world.particles.clear()
		elif action=="recall":
			var return_page=str(payload.get("return_page",""))
			view="base"
			page=return_page
			history.clear()
			toast("已召回小队。保留 %d 积分 / %d 合金，四名队员已恢复。"%[model.s.result.credits,model.s.result.alloy])
			model.s.result={}
			model.s.battle={}
			commit()
		elif action=="intro" and model.s.intro_done:
			page=""
			toast("检查队员，然后从任务门出发。")
		elif action=="dismantle": restore_page()
		if model.notice!="": toast(model.notice)
		play_sound("upgrade" if action in ["upgrade","manufacture","facility"] else "click")
		model.events.clear()
	else:
		model.s=before
		toast(model.error)
	busy=false
	render()
	return ok

func is_paused() -> bool:
	return view=="title" or page in ["intro","pause","quit","settings","recall","dismantle","save_error","recovery","newsave","delete"] or (not model.s.settings.background and not get_window().has_focus() and not transient)

func _process(delta: float) -> void:
	animation_clock+=delta
	toast_clock=maxf(0,toast_clock-delta)
	toast_label.visible=toast_clock>0
	if not is_paused():
		clock+=minf(delta,.2)*model.s.speed
		while clock>=.05:
			clock-=.05
			model.tick(.05)
			process_events()
			if page=="save_error": break
		checkpoint+=delta
		if model.dirty or checkpoint>=5:
			checkpoint=0
			commit()
	if auto_timer>0:
		auto_timer-=delta
		if auto_timer<=0 and page=="result":
			var id=str(model.s.result.get("mission","M01"))
			if model.s.auto=="next":
				var n=C.MISSIONS.find(C.mission(id))+1
				if n<C.MISSIONS.size(): id=C.MISSIONS[n].id
				else:
					auto_timer=-1
					return
			perform("depart",id)
	refresh_clock+=delta
	if refresh_clock>.15:
		refresh_clock=0
		ui.refresh()

func process_events() -> void:
	for e in model.events:
		world.add_event(e)
		if e.type=="attack" and e.side==0 and animation_clock-last_sound>.075:
			play_sound(["blade","shot","heavy","shot"][e.role])
			last_sound=animation_clock
		if e.type=="heal": play_sound("heal")
		if e.type=="result":
			if not commit(): return
			page="result"
			history.clear()
			view="battle"
			auto_timer=5.0 if e.outcome=="victory" and model.s.auto!="return" else -1.0
			play_sound("victory" if e.outcome=="victory" else "defeat")
			render()
		if e.type=="training":
			toast(model.notice)
			play_sound("upgrade")
			render()
	model.events.clear()

func toast(text: String) -> void:
	toast_label.text=text
	toast_clock=4

func set_music(id: String) -> void:
	if music==null: return
	if music_id!=id:
		music_id=id
		var stream: AudioStreamWAV=load("res://assets/reboot/audio/"+id+".wav")
		stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
		stream.loop_end=int(stream.get_length()*stream.mix_rate)
		music.stream=stream
		music.play()
	set_volume(float(settings_draft.get("volume",model.s.settings.volume)) if page=="settings" else float(model.s.settings.volume))

func set_volume(value: float) -> void:
	if music!=null: music.volume_db=linear_to_db(maxf(.0001,value))
	for player in sound_players: player.volume_db=linear_to_db(maxf(.0001,value*.72))

func play_sound(id: String) -> void:
	for player in sound_players:
		if not player.playing:
			player.stream=load("res://assets/reboot/audio/"+id+".wav")
			player.play()
			return

func save_settings() -> void:
	var previous=model.s.settings.duplicate(true)
	model.s.settings=settings_draft.duplicate(true)
	if not transient and not Store.new("user://reboot/settings.json").save(model.s.settings):
		model.s.settings=previous
		toast("设置保存失败，请检查磁盘空间。")
		return
	commit()
	back()
	toast("设置已应用。")

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		back()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_SPACE:
		if page=="intro": perform("intro")
		elif page=="dialogue": ui.next_dialogue()

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		if commit(): get_tree().quit()

func quit_game() -> void:
	if commit(): get_tree().quit()

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var path="res://art/reboot-production/captures/"+name+".png"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	get_viewport().get_texture().get_image().save_png(path)
