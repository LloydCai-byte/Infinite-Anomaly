extends Control
const Model = preload("res://scripts/containment/model.gd")
const Store = preload("res://scripts/save_store.gd")
const Hotspot = preload("res://scripts/continuity/hotspot.gd")
const HomeView = preload("res://scripts/containment/home_view.gd")
const Panels = preload("res://scripts/containment/panels.gd")
const PAPER = Color("ece5d6")
const INK = Color("25292c")
var model = Model.new()
var store = Store.new("user://containment/slot1.json")
var slot = 1
var home_view: RefCounted
var ui: RefCounted
var content: Control
var modal_layer: Control
var caption: Label
var hover_label: Label
var bubble_label: Label
var notification_label: Label
var music: AudioStreamPlayer
var ambient: AudioStreamPlayer
var effect: AudioStreamPlayer
var spots: Array = []
var modal = ""
var fault = ""
var load_fault = false
var transient = false
var busy = false
var last_committed: Dictionary = {}
var accumulator = 0.0
var checkpoint_clock = 0.0
var ambient_id = ""
var last_home_pose = ""

func _ready() -> void:
	transient = "--full-test" in OS.get_cmdline_user_args() or "--full-capture" in OS.get_cmdline_user_args()
	var skin = Theme.new()
	var font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei","Noto Sans CJK SC","sans-serif"])
	skin.default_font = font
	skin.default_font_size = 25
	theme = skin
	content = Control.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(content)
	modal_layer = Control.new()
	modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(modal_layer)
	home_view = HomeView.new(self)
	ui = Panels.new(self)
	last_committed = model.export_state()
	if DisplayServer.get_name() != "headless":
		music = AudioStreamPlayer.new()
		ambient = AudioStreamPlayer.new()
		effect = AudioStreamPlayer.new()
		for player in [music,ambient,effect]:
			add_child(player)
		var melody: AudioStreamWAV = load("res://assets/continuity/audio/quiet-room.wav")
		melody.loop_mode = AudioStreamWAV.LOOP_FORWARD
		melody.loop_end = int(melody.get_length()*melody.mix_rate)
		music.stream = melody
		music.play()
	get_tree().auto_accept_quit = false
	render()
	if not transient:
		ui.title_screen()

func slot_store(number: int):
	return Store.new("user://containment/slot%d.json" % number)

func load_slot(number: int, fresh: bool = false) -> void:
	slot = number
	store = slot_store(number)
	var candidate = Model.new()
	if not fresh and store.exists():
		if not candidate.restore(store.load_primary()) and not candidate.restore(store.load_backup()):
			load_fault = true
			fault = "记录无法读取。主存档与备份都没有通过校验，原文件保留。"
			ui.show_fault()
			return
		var result = candidate.catch_up(Time.get_unix_time_from_system())
		if result.rounds > 0:
			candidate.s.last_line = "离开期间完成了 %d 次收容，物品已送进箱子。" % result.rounds
		candidate.s.paused = false
	if fresh and store.exists():
		var stamp = "%d-%d" % [Time.get_unix_time_from_system(),Time.get_ticks_usec()]
		for suffix in ["",".bak"]:
			if FileAccess.file_exists(store.path+suffix):
				var archive_path = store.path.get_base_dir().path_join("archive-slot%d-%s.json%s"%[number,stamp,suffix])
				if DirAccess.copy_absolute(store.path+suffix,archive_path) != OK:
					load_fault = true
					fault = "旧记录备份失败，未覆盖。"
					ui.show_fault()
					return
	model = candidate
	fault = ""
	load_fault = false
	if save_progress():
		render()
	else:
		ui.show_fault()

func save_progress() -> bool:
	model.s.saved_at = Time.get_unix_time_from_system()
	if not transient and not store.save(model.export_state()):
		fault = store.error
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


func render() -> void:
	close_modal(false)
	clear(content)
	spots.clear()
	bubble_label = null
	var at_home = model.s.mode in ["home","reward","ending"]
	if at_home:
		home_view.draw()
	else:
		image(content,model.node().image,Rect2(0,0,1920,1080)).name = "FullScene"
		for action in model.actions():
			var area = rect(action.rect)
			add_spot(action.id,action.title,area,func(): activate(action.id,area))
		if model.node().has("speech"):
			draw_bubble(model.node().speech)
	var shade = panel(content,Rect2(0,916,1920,164),Color(0.04,0.055,0.06,0.82))
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption = text(content,model.s.last_line,Rect2(58,935,1340,83),27)
	caption.name = "Narration"
	hover_label = text(content,"",Rect2(1420,934,440,74),23)
	hover_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	text(content,"Tab 交互位置  ·  Esc 暂停  ·  F11 全屏",Rect2(58,1030,850,30),18,Color("adb3ab"))
	button(content,"Pause","Ⅱ",Rect2(1820,30,60,56),ui.pause_screen)
	if at_home:
		button(content,"FloorPlan","户型图",Rect2(1630,30,170,56),ui.floor_plan)
	else:
		button(content,"Notebook","线索",Rect2(1480,30,145,56),ui.notebook)
		button(content,"Timeline","时间线",Rect2(1640,30,160,56),ui.timeline)
		panel(content,Rect2(30,25,1050,70),Color(0.07,0.08,0.08,0.85))
		text(content,"调查 %02d  /  %s" % [model.current_case().index,model.node().name],Rect2(45,36,1120,56),27)
	notification_label = text(content,"",Rect2(1080,105,760,76),23)
	notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	last_home_pose = pose_key()
	update_audio()
	if model.s.mode == "dead": ui.death_screen()
	elif model.s.mode == "reward": ui.collection(true)
	elif model.s.mode == "ending": ui.ending()

func activate(id: String, area: Rect2) -> void:
	var action = model.find_action(id)
	if action.has("choices"):
		ui.choices(action)
	elif action.has("stat"):
		var option = action.duplicate(true)
		option.label = action.title
		ui.choices({"title":action.title,"choices":[option]})
	elif action.get("containment",false):
		ui.containment()
	else:
		perform(id)

func pose_key() -> String:
	return model.companion_room()+str(int(model.s.companion_time/15))

func perform(id: String) -> void:
	if busy or fault != "": return
	var previous = model.export_state()
	var panel_before = modal
	var result = model.act(id)
	if not result.get("changed",false): return
	if not save_progress():
		model.restore(previous)
		ui.show_fault()
		return
	cue(result.get("cue","click"))
	render()
	if not result.get("scene",false):
		ui.reopen(panel_before)
	if id == "talk":
		draw_bubble({"text":model.s.last_line,"rect":[930,205,650,210],"tail":[875,450]})
	update_audio()

func open_modal(id: String, tint: Color = Color(0.025,0.035,0.045,0.78)) -> void:
	clear(modal_layer)
	modal = id
	modal_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var veil = ColorRect.new()
	place(veil,modal_layer,Rect2(0,0,1920,1080))
	veil.color = tint
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	if is_instance_valid(hover_label): hover_label.text = ""

func close_modal(resume: bool = true) -> void:
	var was_paused = modal in ["pause","settings"]
	clear(modal_layer)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal = ""
	if resume and was_paused:
		model.s.paused = false
		if not save_progress(): ui.show_fault()

func update_audio() -> void:
	if not is_instance_valid(ambient): return
	apply_mute()
	var id = "home" if model.s.mode in ["home","reward","ending"] else "outside"
	if id == ambient_id: return
	ambient_id = id
	var stream: AudioStreamWAV = load("res://assets/continuity/audio/"+id+".wav")
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = int(stream.get_length()*stream.mix_rate)
	ambient.stream = stream
	ambient.play()

func apply_mute() -> void:
	if is_instance_valid(ambient):
		ambient.volume_db = -80 if model.s.muted or not model.s.ambience_on else linear_to_db(maxf(0.001,model.s.sound_volume))-12
		effect.volume_db = -80 if model.s.muted else linear_to_db(maxf(0.001,model.s.sound_volume))-6
		music.volume_db = -80 if model.s.muted or not model.s.music_on or model.s.mode not in ["home","reward","ending"] else linear_to_db(maxf(0.001,model.s.music_volume))-15

func cue(id: String) -> void:
	if is_instance_valid(effect) and ResourceLoader.exists("res://assets/continuity/audio/"+id+".wav"):
		effect.stream = load("res://assets/continuity/audio/"+id+".wav")
		effect.play()

func _process(delta: float) -> void:
	if modal in ["title","slots","pause","settings","fault","death"] or fault != "": return
	accumulator += delta
	if accumulator >= 0.25:
		var elapsed = accumulator
		accumulator = 0
		tick_simulation(elapsed)

func tick_simulation(seconds: float) -> void:
	if modal in ["title","slots","pause","settings","fault","death"] or fault != "": return
	var previous = model.export_state()
	var result = model.advance(seconds)
	checkpoint_clock += seconds
	if result.rounds > 0 or result.bell or checkpoint_clock >= 5:
		if not save_progress():
			model.restore(last_committed)
			ui.show_fault()
			return
	if result.returned:
		render()
	elif result.rounds > 0:
		ui.reopen(modal)
	elif last_home_pose != pose_key() and model.s.mode == "home" and modal == "":
		render()
	home_view.refresh()
	ui.refresh()
	if result.bell:
		cue("bell")
		notify_player("专注完成，休息五分钟。" if model.s.pomo.phase == "break" else "休息结束，新一段专注开始。")
	if result.rounds > 0:
		notify_player("%d 次收容记录已送达。" % result.rounds)

func notify_player(line: String) -> void:
	if is_instance_valid(notification_label): notification_label.text = line

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_F11:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
		KEY_TAB:
			if modal == "":
				model.s.show_hints = not model.s.show_hints
				for spot in spots:
					spot.reveal = model.s.show_hints
					spot.queue_redraw()
		KEY_ESCAPE:
			if modal == "" and model.s.room == "peephole": perform("room_entry")
			elif modal == "": ui.pause_screen()
			elif modal not in ["title","slots","death","reward","ending","fault"]: close_modal()
		_: return
	get_viewport().set_input_as_handled()

func quit_safely() -> void:
	if modal in ["title","slots"] or load_fault:
		get_tree().quit()
		return
	if accumulator > 0:
		tick_simulation(accumulator)
		accumulator = 0
	if save_progress(): get_tree().quit()
	else: ui.show_fault()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_node_ready(): quit_safely()

func _exit_tree() -> void:
	for player in [ambient,music,effect]:
		if is_instance_valid(player):
			player.stop()
			player.stream = null

func capture(id: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var folder = ProjectSettings.globalize_path("res://.local/full-captures")
	DirAccess.make_dir_recursive_absolute(folder)
	get_viewport().get_texture().get_image().save_png(folder.path_join(id+".png"))
