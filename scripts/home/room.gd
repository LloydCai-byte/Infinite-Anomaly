extends Control
signal activated(action: String, argument: String)
signal hovered(label: String)
const ROOMS = {
	"entry":{"title":"玄关","back":"hall","spots":[
		["门","door","",0.557,0.123,0.180,0.623],
		["厨房","room","kitchen",0.0,0.03,0.085,0.69],
		["鞋柜","look","出门时穿过的鞋，仍整齐地放在这里。",0.228,0.595,0.297,0.191]
	]},
	"hall":{"title":"过厅","back":"entry","spots":[
		["卧室","room","bedroom",0.038,0.073,0.208,0.825],
		["厨房","room","kitchen",0.722,0.059,0.254,0.857],
		["椅子","look","你坐了一会儿。屋子里只有冰箱的声音。",0.419,0.53,0.184,0.454]
	]},
	"kitchen":{"title":"厨房","back":"hall","spots":[
		["卫生间","room","bathroom",0.278,0.059,0.044,0.91],
		["冰箱","look","食物会自动维持你的生活。需要补给时，打开手机。",0.685,0.214,0.074,0.771],
		["窗户","look","窗外没有风。把手纹丝不动。",0.449,0.114,0.149,0.358]
	]},
	"bathroom":{"title":"卫生间","back":"kitchen","spots":[
		["窗户","look","玻璃是凉的。窗框像被焊在墙里。",0.45,0.11,0.25,0.34],
		["洗衣机","look","衣物总能洗净。它们比你更熟悉这间屋子。",0.18,0.47,0.31,0.48]
	]},
	"bedroom":{"title":"卧室","back":"hall","spots":[
		["书桌方向","room","desk",0.0,0.02,0.15,0.85],
		["床","look","床铺还是温的。你已经记不清是谁最后一次醒来。",0.401,0.431,0.329,0.554],
		["房门","room","hall",0.75,0.03,0.25,0.94]
	]},
	"desk":{"title":"书桌","back":"bedroom","spots":[
		["手机","phone","home",0.23,0.703,0.085,0.059],
		["电脑","phone","home",0.0,0.327,0.142,0.408],
		["阳台","room","balcony",0.476,0.015,0.252,0.96]
	]},
	"balcony":{"title":"封闭阳台","back":"desk","spots":[
		["窗户","look","你看得到对面的灯，却打不开这扇窗。",0.0,0.03,0.65,0.67]
	]}
}
var room_id: String = "entry"
var background: TextureRect
var portal: TextureRect
var marker: Label
var current: int = -1
var show_targets: bool = false
var locked: bool = false
var phase: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	background = TextureRect.new()
	background.show_behind_parent = true
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portal = TextureRect.new()
	add_child(portal)
	portal.position = Vector2(1148,206)
	portal.size = Vector2(191,315)
	portal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portal.modulate.a = 0.92
	marker = Label.new()
	add_child(marker)
	marker.position = Vector2(1127,799)
	marker.size = Vector2(255,40)
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.add_theme_font_size_override("font_size",16)
	marker.add_theme_color_override("font_color",Color("#d4c3a6"))
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_exited.connect(func(): current=-1;hovered.emit("");queue_redraw())
	set_room(room_id)

func set_room(id: String) -> void:
	if not ROOMS.has(id):
		return
	room_id = id
	current = -1
	if is_instance_valid(background):
		background.texture = load("res://assets/home/"+id+".png")
		if id == "entry" and Home.model.s.mode == "ENDING":
			background.texture = load("res://assets/memory/ending.png")
	sync_memory()
	queue_redraw()

func sync_memory() -> void:
	if not is_instance_valid(portal):
		return
	var s: Dictionary = Home.model.s
	portal.visible = room_id == "entry" and s.mode != "ENDING" and (s.mode == "MEMORY" or not s.result.is_empty())
	marker.visible = portal.visible
	if portal.visible:
		var chapter: Dictionary = Home.model.current_stage() if s.mode == "MEMORY" else Home.model.db.stages[int(s.result.stage)]
		portal.texture = load("res://assets/memory/"+chapter.image+".png")
		marker.text = "第 %03d 次记忆  ·  %s" % [s.attempts, "接收中" if s.mode == "MEMORY" else "已归档"]

func _process(delta: float) -> void:
	phase += delta
	if show_targets or current >= 0:
		queue_redraw()

func spots() -> Array:
	var list: Array = ROOMS[room_id].spots.duplicate(true)
	list.append(["转身" if room_id in ["entry","hall"] else "返回","room",ROOMS[room_id].back,0.038,0.87,0.072,0.09])
	return list

func _gui_input(event: InputEvent) -> void:
	if locked:
		return
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		var p: Vector2 = get_local_mouse_position() / size
		var items: Array = spots()
		var hit: int = -1
		for i in range(items.size()):
			var item: Array = items[i]
			if Rect2(item[3],item[4],item[5],item[6]).has_point(p):
				hit = i
		if hit != current:
			current = hit
			hovered.emit("" if hit < 0 else str(items[hit][0]))
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hit >= 0 else Control.CURSOR_ARROW
			queue_redraw()
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and current >= 0:
			var item: Array = items[current]
			activated.emit(item[1],item[2])
			accept_event()

func _draw() -> void:
	var items: Array = spots()
	for i in range(items.size()):
		var item: Array = items[i]
		var rect = Rect2(Vector2(item[3],item[4])*size,Vector2(item[5],item[6])*size)
		var center: Vector2 = rect.get_center()
		if i == items.size()-1:
			var c: Color = Color(1,0.97,0.87,0.9 if current == i else 0.5)
			draw_circle(center,25,Color(0.05,0.05,0.04,0.28))
			draw_polyline(PackedVector2Array([center+Vector2(8,-10),center+Vector2(-5,0),center+Vector2(8,10)]),c,2,true)
		elif i == current or show_targets:
			var c = Color(0.97,0.94,0.79,0.85 if i == current else 0.40)
			draw_circle(center,5,c)
			draw_arc(center,14+sin(phase*2)*1.5,0,TAU,40,c,1.2,true)
