extends Control
const Model = preload("res://scripts/continuity/model.gd")
const Store = preload("res://scripts/save_store.gd")
const Hotspot = preload("res://scripts/continuity/hotspot.gd")
const HomeView = preload("res://scripts/continuity/home_view.gd")
const HOME = "res://assets/continuity/home.png"
const PAPER = Color("ece5d6")
const INK = Color("25292c")
var model = Model.new()
var store = Store.new("user://continuity_stage2/checkpoint.json")
var home_view: RefCounted
var music: AudioStreamPlayer
var last_committed: Dictionary = {}
var clock_accumulator = 0.0
var checkpoint_clock = 0.0
var notification_timer = 0.0
var notification_label: Label
var content: Control
var modal_layer: Control
var caption: Label
var hover_label: Label
var bubble_label: Label
var ambient: AudioStreamPlayer
var effect: AudioStreamPlayer
var spots: Array = []
var modal = ""
var fault = ""
var transient = false
var busy = false
var ambient_id = ""
var caption_timer = 0.0
var tooltip_timer = 0.0
var fade: ColorRect
var fade_tween: Tween

func _ready() -> void:
	transient = "--stage1-test" in OS.get_cmdline_user_args() or "--stage1-capture" in OS.get_cmdline_user_args() or "--stage2-test" in OS.get_cmdline_user_args() or "--stage2-capture" in OS.get_cmdline_user_args()
	if not transient:
		load_progress()
	last_committed = model.export_state()
	home_view = HomeView.new(self)
	var skin = Theme.new()
	var font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei","Noto Sans CJK SC","sans-serif"])
	skin.default_font = font
	skin.default_font_size = 26
	theme = skin
	content = Control.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(content)
	modal_layer = Control.new()
	modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(modal_layer)
	fade = ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0.02,0.025,0.03,0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)
	if DisplayServer.get_name() != "headless":
		ambient = AudioStreamPlayer.new()
		ambient.volume_db = -17
		add_child(ambient)
		effect = AudioStreamPlayer.new()
		effect.volume_db = -12
		add_child(effect)
		music = AudioStreamPlayer.new()
		add_child(music)
		var melody: AudioStreamWAV = load("res://assets/continuity/audio/quiet-room.wav")
		melody.loop_mode = AudioStreamWAV.LOOP_FORWARD
		melody.loop_end = int(melody.get_length() * melody.mix_rate)
		music.stream = melody
		music.play()
	get_tree().auto_accept_quit = false
	render()
	if fault != "":
		show_fault(true)
	if "--stage1-capture" in OS.get_cmdline_user_args():
		call_deferred("capture_route")
	if "--stage2-capture" in OS.get_cmdline_user_args():
		call_deferred("capture_stage2")

func load_progress() -> void:
	if not store.exists():
		var old_store = Store.new("user://continuity_stage1/checkpoint.json")
		if old_store.exists():
			if model.restore(old_store.load_primary()) or model.restore(old_store.load_backup()):
				if model.s.mode == "home":
					model.s.last_line = "上次带回的卡还在。屋里多了翻书的声音。"
			else:
				fault = "上次的记录暂时无法读取。原文件已保留。"
		return
	if model.restore(store.load_primary()):
		return
	if model.restore(store.load_backup()):
		model.s.last_line = "已从最近一次备份恢复。"
		return
	fault = "记录暂时无法读取。原文件已保留。"

func save_progress() -> bool:
	if transient:
		last_committed = model.export_state()
		return true
	if fault != "":
		return false
	if not store.save(model.export_state()):
		fault = "这次操作尚未保存。\n" + store.error
		return false
	last_committed = model.export_state()
	checkpoint_clock = 0
	return true

func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func rect(values: Array) -> Rect2:
	return Rect2(values[0],values[1],values[2],values[3])

func place(node: Control, parent: Node, area: Rect2) -> Control:
	parent.add_child(node)
	node.position = area.position
	node.size = area.size
	return node

func text(parent: Node, value: String, area: Rect2, pixels: int = 26, color: Color = PAPER) -> Label:
	var label = Label.new()
	place(label,parent,area)
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size",pixels)
	label.add_theme_color_override("font_color",color)
	return label

func box(color: Color, border: Color = Color.TRANSPARENT, radius: int = 4) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style

func panel(parent: Node, area: Rect2, color: Color, border: Color = Color.TRANSPARENT, radius: int = 4) -> Panel:
	var node = Panel.new()
	place(node,parent,area)
	node.add_theme_stylebox_override("panel",box(color,border,radius))
	return node

func button(parent: Node, id: String, title: String, area: Rect2, callback: Callable, light: bool = false) -> Button:
	var node = Button.new()
	place(node,parent,area)
	node.name = id
	node.text = title
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.add_theme_font_size_override("font_size",24)
	for state in ["normal","hover","pressed","focus"]:
		var bg = Color("ece5d6") if light else Color("202529")
		if state in ["hover","focus"]:
			bg = Color("fff8e7") if light else Color("384347")
		node.add_theme_stylebox_override(state,box(bg,Color("b6b0a2") if light else Color("677473")))
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
		node.add_theme_color_override(state,INK if light else PAPER)
	node.pressed.connect(callback)
	return node

func image(parent: Node, path: String, area: Rect2) -> TextureRect:
	var node = TextureRect.new()
	place(node,parent,area)
	node.texture = load(path)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func render() -> void:
	close_modal()
	clear(content)
	spots.clear()
	bubble_label = null
	notification_label = null
	var at_home = model.s.mode in ["home","reward"]
	if at_home:
		home_view.draw()
	else:
		image(content,model.node().image,Rect2(0,0,1920,1080)).name = "FullScene"
	var gradient = Gradient.new()
	gradient.colors = PackedColorArray([Color(0,0,0,0),Color(0.03,0.04,0.045,0.72)])
	var ramp = GradientTexture2D.new()
	ramp.gradient = gradient
	ramp.fill_from = Vector2(0,0)
	ramp.fill_to = Vector2(0,1)
	var shade = TextureRect.new()
	place(shade,content,Rect2(0,840,1920,240))
	shade.texture = ramp
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.visible = not (at_home and model.s.room == "peephole")
	if not at_home:
		for data in model.actions():
			var area = rect(data.rect)
			add_spot(data.id,data.title,area,func(): activate(data.id,area))
		if model.s.mode == "story" and model.node().has("speech"):
			draw_bubble(model.node().speech)
		if model.s.node == "note" and model.s.flags.has("rule"):
			text(content,"灯灭的门，\n才通向家。",Rect2(1035,445,165,145),27,INK).name = "PaperText"
	caption = text(content,model.s.last_line,Rect2(72,918,1210,100),27)
	caption.name = "Narration"
	caption.visible = not (at_home and model.s.room == "peephole")
	caption.add_theme_color_override("font_shadow_color",Color(0,0,0,0.9))
	caption.add_theme_constant_override("shadow_offset_x",1)
	caption.add_theme_constant_override("shadow_offset_y",2)
	if model.s.node == "threshold" and not at_home:
		caption.position = Vector2(1080,932)
		caption.size = Vector2(710,96)
	caption_timer = 0
	hover_label = text(content,"",Rect2(1390,1002,450,42),24)
	hover_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	text(content,"Tab · 交互位置     Esc · 暂停     F11 · 全屏" if model.s.room != "peephole" or not at_home else "Esc · 离开猫眼     F11 · 全屏",Rect2(72,1030,930,30),18,Color("aaa99f") if model.s.room != "peephole" or not at_home else Color("626a62"))
	button(content,"Pause","Ⅱ",Rect2(1814,38,64,52),show_pause)
	notification_label = text(content,"",Rect2(1120,125,695,65),23)
	notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if transient:
		text(content,"预览",Rect2(1715,47,80,40),18,Color("b5b9b6"))
	update_audio()
	if model.s.mode == "dead":
		show_death()
	elif model.s.mode == "reward":
		show_collection(true)

func add_spot(id: String, title: String, area: Rect2, callback: Callable) -> void:
	var spot = Hotspot.new()
	place(spot,content,area)
	spot.name = id
	spot.reveal = model.s.show_hints
	spot.pressed.connect(func():
		if not busy and modal == "":
			callback.call())
	spot.pointed.connect(func(over: bool):
		if is_instance_valid(hover_label) and modal == "":
			hover_label.text = title if over else "")
	spots.append(spot)

func draw_bubble(data: Dictionary) -> void:
	var old = content.get_node_or_null("SpeechBubble")
	if old:
		content.remove_child(old)
		old.queue_free()
	var holder = Control.new()
	holder.name = "SpeechBubble"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(holder)
	var area = rect(data.rect)
	var points = PackedVector2Array([Vector2(area.position.x+32,area.end.y-6),Vector2(data.tail[0],data.tail[1]),Vector2(area.position.x+85,area.end.y-6)])
	var tail = Polygon2D.new()
	tail.polygon = points
	tail.color = PAPER
	holder.add_child(tail)
	var bubble = panel(holder,area,PAPER,INK,32)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble_label = text(bubble,data.text,Rect2(26,20,area.size.x-52,area.size.y-35),28,INK)
	bubble_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func activate(id: String, area: Rect2) -> void:
	var action = model.find_action(id)
	if action.has("choices"):
		show_choices(action,area)
	else:
		perform(id)

func perform(id: String) -> void:
	if busy or fault != "":
		return
	var previous = model.export_state()
	var result = model.act(id)
	if not result.get("changed",false):
		return
	if not save_progress():
		model.restore(previous)
		show_fault()
		return
	close_modal()
	cue(result.get("cue","click"))
	if result.get("scene",false):
		render()
		transition()
	else:
		caption.text = model.s.last_line
		caption.modulate.a = 1
		caption_timer = 0
		if result.has("speech") and is_instance_valid(bubble_label):
			bubble_label.text = result.speech
		if id == "read_note":
			# The clue is typeset onto the blank paper, rather than baked into art.
			var clue = content.get_node_or_null("PaperText")
			if clue == null:
				clue = text(content,"灯灭的门，\n才通向家。",Rect2(1035,445,165,145),27,INK)
				clue.name = "PaperText"
	if id in ["music","ambience"]:
		apply_mute()
	if id == "talk" and model.s.room == "bedroom":
		draw_bubble({"text":model.s.last_line,"rect":[950,235,455,150],"tail":[810,417]})
	home_view.refresh()

func transition() -> void:
	if fade_tween:
		fade_tween.kill()
	if transient:
		fade.color.a = 0
		busy = false
		return
	busy = true
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	fade.color.a = 0.9
	fade_tween = create_tween()
	fade_tween.tween_property(fade,"color:a",0.0,0.34)
	fade_tween.tween_callback(func():
		busy = false
		fade.mouse_filter = Control.MOUSE_FILTER_IGNORE)

func open_modal(id: String, tint: Color = Color(0.025,0.035,0.045,0.55)) -> void:
	clear(modal_layer)
	modal = id
	modal_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var veil = ColorRect.new()
	place(veil,modal_layer,Rect2(0,0,1920,1080))
	veil.color = tint
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	if is_instance_valid(hover_label):
		hover_label.text = ""

func close_modal() -> void:
	if is_instance_valid(modal_layer):
		clear(modal_layer)
		modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal = ""

func show_choices(data: Dictionary, area: Rect2) -> void:
	open_modal("choices",Color(0,0,0,0.17))
	var x = clampf(area.get_center().x-225,40,1430)
	var body = panel(modal_layer,Rect2(x,640,450,265),Color("21282b"),Color("64716c"),6)
	text(body,data.title,Rect2(24,18,345,40),23,Color("b8c8bb"))
	button(body,"CloseChoices","×",Rect2(387,12,43,40),close_modal)
	var y = 76.0
	for choice in data.choices:
		var title: String = choice.label
		if choice.has("stat"):
			title += "  · 神经 %d / %d" % [model.s.skills.nerve,choice.threshold]
		button(body,choice.id,title,Rect2(22,y,406,67),func(): perform(choice.id))
		y += 79

func show_death() -> void:
	open_modal("death",Color(0.025,0.032,0.039,0.94))
	text(modal_layer,model.s.last_line,Rect2(430,330,1060,190),35).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text(modal_layer,"然后，一切安静下来。",Rect2(600,550,720,70),23,Color("a7a9a2")).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button(modal_layer,"Wake","睁开眼",Rect2(795,705,330,68),func(): perform("wake"))
	button(modal_layer,"ExitDeath","保存并退出",Rect2(810,802,300,55),quit_safely)

func show_collection(reward: bool = false) -> void:
	open_modal("reward" if reward else "collection",Color(0.05,0.07,0.075,0.78))
	var owned = model.s.cards.has("stair")
	var sheet = panel(modal_layer,Rect2(666,140,588,752),PAPER,Color("aaa799"),12)
	if owned:
		image(sheet,model.story.card.image,Rect2(26,28,536,346))
		text(sheet,"01",Rect2(33,397,100,46),22,Color("777d76"))
		text(sheet,model.story.card.name,Rect2(33,453,515,70),40,INK)
		text(sheet,model.story.card.description,Rect2(33,549,515,140),25,Color("4f5855"))
		text(sheet,"已收容",Rect2(410,402,120,42),22,Color("496758"))
	else:
		text(sheet,"还没有带回任何东西。",Rect2(54,305,490,80),28,INK).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if reward:
		text(modal_layer,model.s.last_line,Rect2(560,45,800,60),25).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button(modal_layer,"PutAway" if reward else "CloseCollection","收起卡片" if reward else "合上柜子",Rect2(775,940,370,70),func():
		if reward:
			perform("put_away")
		else:
			close_modal())

func show_pause() -> void:
	if modal in ["death","reward","fault"] or busy:
		return
	open_modal("pause",Color(0.04,0.055,0.06,0.86))
	text(modal_layer,"无限异常",Rect2(645,204,630,75),46).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text(modal_layer,"门外探索与番茄钟已暂停",Rect2(600,292,720,50),22,Color("adb6ae")).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button(modal_layer,"Resume","继续",Rect2(730,409,460,68),close_modal)
	button(modal_layer,"Hints","交互提示：" + ("开" if model.s.show_hints else "关"),Rect2(730,496,460,68),func():
		toggle_hints()
		show_pause())
	button(modal_layer,"Mute","声音：" + ("关" if model.s.muted else "开"),Rect2(730,583,460,68),func():
		model.s.muted = not model.s.muted
		apply_mute()
		show_pause())
	button(modal_layer,"Quit","保存并退出",Rect2(730,697,460,68),quit_safely)
	text(modal_layer,"窗口失焦仍运行；退出后保留进度，下次接着这一趟。",Rect2(500,817,920,70),21,Color("adb6ae")).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	persist_pause()

func persist_pause() -> void:
	if not save_progress():
		model.restore(last_committed)
		show_fault()

func show_fault(on_load: bool = false) -> void:
	open_modal("fault",Color(0.04,0.05,0.06,0.96))
	text(modal_layer,fault,Rect2(445,330,1030,220),28).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button(modal_layer,"RetrySave","重新读取" if on_load else "重试保存",Rect2(745,614,430,68),func():
		fault = ""
		if on_load:
			load_progress()
		elif not save_progress():
			pass
		if fault == "":
			render()
		else:
			show_fault(on_load))
	button(modal_layer,"Temporary","临时体验（本次不存档）",Rect2(745,708,430,68),func():
		transient = true
		fault = ""
		render())

func toggle_hints() -> void:
	model.s.show_hints = not model.s.show_hints
	for spot in spots:
		spot.reveal = model.s.show_hints
		spot.queue_redraw()

func update_audio() -> void:
	if not is_instance_valid(ambient):
		return
	apply_mute()
	var id = "home" if model.s.mode in ["home","reward"] else "outside"
	if id == ambient_id:
		return
	ambient_id = id
	var stream: AudioStreamWAV = load("res://assets/continuity/audio/" + id + ".wav")
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	ambient.stream = stream
	ambient.play()

func apply_mute() -> void:
	if is_instance_valid(ambient):
		ambient.volume_db = -80 if model.s.muted or not model.s.ambience_on else -17
	if is_instance_valid(effect):
		effect.volume_db = -80 if model.s.muted else -12
	if is_instance_valid(music):
		music.volume_db = -80 if model.s.muted or not model.s.music_on or model.s.mode not in ["home","reward"] else -21

func cue(id: String) -> void:
	if is_instance_valid(effect) and ResourceLoader.exists("res://assets/continuity/audio/"+id+".wav"):
		effect.stream = load("res://assets/continuity/audio/"+id+".wav")
		effect.play()

func _process(delta: float) -> void:
	if modal not in ["pause","fault","death"] and not busy and fault == "":
		clock_accumulator += delta
		if clock_accumulator >= 0.25:
			var elapsed = clock_accumulator
			clock_accumulator = 0
			tick_simulation(elapsed)
	if notification_timer > 0:
		notification_timer -= delta
		if notification_timer <= 0 and is_instance_valid(notification_label):
			notification_label.text = ""
	if modal != "" or not is_instance_valid(caption):
		return
	caption_timer += delta
	# Keep clues readable, then leave the full illustration unobstructed.
	caption.modulate.a = 1.0 - clampf((caption_timer-14)/1.5,0,1)

func tick_simulation(seconds: float) -> void:
	if modal in ["pause","fault","death"] or fault != "":
		return
	var changes = model.advance(seconds)
	checkpoint_clock += seconds
	if changes.rounds > 0 or changes.bell or checkpoint_clock >= 5:
		if not save_progress():
			model.restore(last_committed)
			show_fault()
			return
	if changes.returned:
		render()
		notify_player("他回来了。送回的物品在门边箱子里。")
	elif changes.rounds > 0:
		notify_player("箱子轻轻响了一声。新的一趟已经开始。")
	if changes.bell:
		cue("bell")
		notify_player("这段专注完成了，休息一会儿。" if model.s.pomo.phase == "break" else "休息结束了。慢慢开始下一段吧。")
	home_view.refresh()

func notify_player(line: String) -> void:
	if is_instance_valid(notification_label):
		notification_label.text = line
		notification_timer = 7

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode not in [KEY_F11,KEY_ESCAPE,KEY_TAB,KEY_SPACE]:
		return
	match event.keycode:
		KEY_F11:
			var full = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
		KEY_ESCAPE:
			if modal in ["pause","choices","collection","dispatch","delivery","radio","timer"]:
				close_modal()
			elif modal == "" and model.s.mode == "home" and model.s.room == "peephole":
				perform("room_entry")
			elif modal == "":
				show_pause()
		KEY_TAB:
			if modal == "":
				toggle_hints()
		KEY_SPACE:
			if modal == "":
				caption_timer = 0
	get_viewport().set_input_as_handled()

func quit_safely() -> void:
	if clock_accumulator > 0 and modal not in ["pause","death","fault"]:
		tick_simulation(clock_accumulator)
		clock_accumulator = 0
	if save_progress():
		get_tree().quit()
	else:
		show_fault()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_node_ready():
		quit_safely()

func _exit_tree() -> void:
	if is_instance_valid(ambient):
		ambient.stop()
		ambient.stream = null
	if is_instance_valid(effect):
		effect.stop()
		effect.stream = null
	if is_instance_valid(music):
		music.stop()
		music.stream = null

func capture(id: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var directory = ProjectSettings.globalize_path("res://.local/stage2-captures" if "--stage2-capture" in OS.get_cmdline_user_args() else "res://.local/stage1-captures")
	DirAccess.make_dir_recursive_absolute(directory)
	get_viewport().get_texture().get_image().save_png(directory.path_join(id+".png"))

func capture_route() -> void:
	await capture("00-home")
	perform("depart")
	await capture("01-landing")
	perform("down")
	await capture("02-stranger")
	perform("stranger")
	perform("paper")
	perform("read_note")
	await capture("03-note")
	perform("continue")
	await capture("04-doors")
	activate("lit_door",rect(model.find_action("lit_door").rect))
	await capture("05-choice")
	perform("open_lit")
	await capture("06-death")
	perform("wake")
	perform("depart")
	perform("down")
	perform("paper")
	perform("continue")
	perform("quiet")
	await capture("07-threshold")
	perform("take_card")
	await capture("08-card")
	perform("put_away")
	show_pause()
	await capture("09-pause")
	print("STAGE1_CAPTURE complete")
	get_tree().quit()

func capture_stage2() -> void:
	set_process(false)
	for id in ["depart","down","paper","continue","quiet","take_card","put_away"]:
		perform(id)
	await capture("00-home-unlocked")
	home_view.show_dispatch()
	await capture("01-dispatch")
	perform("start_auto")
	perform("room_bedroom")
	await capture("02-reading")
	tick_simulation(28)
	await capture("03-tea")
	home_view.show_timer()
	await capture("04-timer")
	close_modal()
	perform("room_entry")
	perform("peek")
	await capture("05-peephole")
	perform("room_entry")
	tick_simulation(152)
	home_view.show_delivery()
	await capture("06-delivery")
	perform("claim")
	home_view.show_delivery()
	await capture("07-claimed")
	close_modal()
	perform("room_bedroom")
	home_view.show_radio()
	await capture("08-radio")
	close_modal()
	show_pause()
	await capture("09-pause")
	print("STAGE2_CAPTURE complete")
	get_tree().quit()
