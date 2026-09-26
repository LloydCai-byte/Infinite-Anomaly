extends Control
signal facility_pressed(id: String)
const UI = preload("res://scripts/ui_style.gd")
var upgrades: Dictionary = {"action": 0, "display": 0, "living": 0}
var card_count: int = 0
var hovered: String = ""
var phase: float = 0.0
var text_font = UI.font()
var spots: Dictionary = {
	"missions": Rect2(54, 262, 285, 235),
	"cards": Rect2(407, 186, 258, 244),
	"upgrades": Rect2(738, 260, 280, 256)
}

func _ready() -> void:
	clip_contents = true
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_exited.connect(func(): hovered = ""; queue_redraw())

func update_state(value: Dictionary, count: int) -> void:
	upgrades = value.duplicate()
	card_count = count
	queue_redraw()

func _process(delta: float) -> void:
	phase += delta
	if is_visible_in_tree():
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	var local: Vector2 = get_local_mouse_position() * Vector2(1100, 680) / size
	var current: String = ""
	for id in spots:
		if spots[id].has_point(local):
			current = id
	hovered = current
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and current != "":
		facility_pressed.emit(current)
	queue_redraw()

func l(a: Vector2, b: Vector2, color: Color = UI.LINE, width: float = 1.4) -> void:
	draw_line(a, b, color, width, true)

func r(x: float, y: float, w: float, h: float, color: Color = UI.LINE, width: float = 1.4, filled: bool = false) -> void:
	if filled:
		draw_rect(Rect2(x,y,w,h),color,true)
	else:
		draw_rect(Rect2(x,y,w,h),color,false,width)

func t(text: String, x: float, y: float, font_size: int = 18, color: Color = UI.MUTED) -> void:
	draw_string(text_font, Vector2(x,y),text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func _draw() -> void:
	draw_set_transform(Vector2.ZERO,0,size/Vector2(1100,680))
	# Fixed perspective, no player movement or navigation.
	var improved: bool = upgrades.living > 0
	r(0,0,1100,680,Color("111d20"),1,true)
	for x in range(20,1100,40):
		for y in range(20,680,40):
			draw_circle(Vector2(x,y),0.75,Color("26393c"))
	var wall: Color = Color("58706c") if improved else UI.LINE
	r(155,85,755,370,wall)
	l(Vector2(155,85),Vector2(30,35),wall)
	l(Vector2(910,85),Vector2(1080,25),wall)
	l(Vector2(155,455),Vector2(10,630),wall)
	l(Vector2(910,455),Vector2(1090,630),wall)
	l(Vector2(30,35),Vector2(30,605),wall)
	l(Vector2(1080,25),Vector2(1080,617),wall)
	for i in range(1,8):
		l(Vector2(155+i*94,455),Vector2(-70+i*170,680),Color("2b4143"))
	for y in [490,535,590,650]:
		l(Vector2(145-(y-455)*0.7,y),Vector2(920+(y-455)*0.8,y),Color("2b4143"))
	# Ceiling light and power conduits.
	r(396,101,275,14,UI.INK)
	r(424,117,221,4,UI.MINT,1,true)
	l(Vector2(534,85),Vector2(534,55),UI.LINE)
	l(Vector2(179,185),Vector2(380,185),wall)
	l(Vector2(179,185),Vector2(179,325),wall)
	if upgrades.action > 0:
		l(Vector2(190,185),Vector2(190,320),UI.MINT)
		l(Vector2(190,185),Vector2(382,185),UI.MINT)
	# Action terminal with stable click target.
	var terminal_ink: Color = UI.MINT if hovered == "missions" else UI.INK
	r(81,408,251,19,terminal_ink)
	l(Vector2(96,427),Vector2(92,502),terminal_ink)
	l(Vector2(316,427),Vector2(324,502),terminal_ink)
	r(113,306,169,88,terminal_ink,2)
	r(123,316,149,66,UI.LINE)
	for i in range(5):
		l(Vector2(137,332+i*8),Vector2(189+i%3*24,332+i*8),UI.MINT if i==0 else UI.LINE)
	draw_circle(Vector2(252,330),3,UI.MINT * (0.7+0.2*sin(phase*2)))
	l(Vector2(198,394),Vector2(198,408),terminal_ink)
	r(150,399,100,5,UI.LINE)
	if upgrades.action > 0:
		r(78,264,83,34,UI.MINT)
		r(170,264,110,34,UI.MUTED)
		t("P 02",185,287,17,UI.MINT)
		r(340,365,32,89,UI.MUTED)
		for i in range(5):
			l(Vector2(347,380+i*12),Vector2(364,380+i*12),UI.MINT)
	t("01 / 探索终端",108,544,21,terminal_ink)
	t("任务 · 行动 · 前线记录",108,573,15)
	# Containment cabinet.
	var cabinet: Color = UI.MINT if hovered == "cards" else UI.INK
	r(420,183,243,259,cabinet,1.8)
	r(434,196,215,232,UI.LINE)
	l(Vector2(542,196),Vector2(542,428),UI.LINE)
	for y in [272,350]:
		l(Vector2(434,y),Vector2(649,y),cabinet)
	if upgrades.display > 0:
		for x in [442,550]:
			for y in [204,281,358]:
				r(x,y,91,60,UI.MINT)
				l(Vector2(x+7,y+5),Vector2(x+26,y+24),UI.LINE)
				r(x+5,y+64,46,7,UI.MUTED)
	for i in range(mini(card_count,6)):
		var x: float = 477+(i%2)*108
		var y: float = 236+floori(i/2.0)*77
		if i % 3 == 0:
			r(x-18,y-15,36,28,UI.INK)
			l(Vector2(x-10,y),Vector2(x+10,y),UI.LINE)
		elif i % 3 == 1:
			draw_arc(Vector2(x,y),17,0,TAU,32,UI.INK,1.5,true)
			l(Vector2(x,y),Vector2(x-7,y-9),UI.MINT)
		else:
			r(x-12,y-22,24,40,UI.INK)
			l(Vector2(x-6,y-9),Vector2(x+6,y-9),UI.MUTED)
	t("02 / 收容陈列",454,490,21,cabinet)
	t("永久登记  %02d 件" % card_count,465,519,15)
	# Bed and domestic fixtures.
	var domestic: Color = UI.MINT if hovered == "upgrades" else UI.INK
	var bed_points = PackedVector2Array([Vector2(745,382),Vector2(922,382),Vector2(1010,440),Vector2(821,440),Vector2(745,382)])
	draw_polyline(bed_points,domestic,1.8,true)
	l(Vector2(821,440),Vector2(821,468),domestic)
	l(Vector2(1010,440),Vector2(1010,468),domestic)
	l(Vector2(821,468),Vector2(1010,468),domestic)
	l(Vector2(745,382),Vector2(745,411),domestic)
	l(Vector2(745,411),Vector2(821,468),domestic)
	r(751,357,152,24,domestic)
	l(Vector2(787,391),Vector2(914,391),UI.LINE)
	l(Vector2(787,391),Vector2(811,407),UI.LINE)
	if improved:
		l(Vector2(853,388),Vector2(930,440),UI.MINT)
		l(Vector2(864,388),Vector2(941,440),UI.MINT)
		r(944,315,62,69,UI.MUTED)
		l(Vector2(975,315),Vector2(975,269),UI.MINT)
		draw_polyline(PackedVector2Array([Vector2(947,269),Vector2(1004,269),Vector2(991,242),Vector2(960,242),Vector2(947,269)]),UI.MINT,1.5,true)
		r(726,203,145,86,UI.MUTED)
		r(735,212,127,68,UI.LINE)
		l(Vector2(796,212),Vector2(796,280),UI.MUTED)
		l(Vector2(735,246),Vector2(862,246),UI.MUTED)
		r(760,510,260,44,UI.LINE)
		for i in range(6):
			l(Vector2(770+i*40,516),Vector2(787+i*40,548),UI.LINE)
	else:
		l(Vector2(780,216),Vector2(767,240),UI.LINE)
		l(Vector2(767,240),Vector2(780,255),UI.LINE)
		l(Vector2(780,255),Vector2(764,279),UI.LINE)
	t("03 / 生活与设施",762,585,21,domestic)
	t("" if improved else "临时床铺 · 等待修复",781,614,15)
	# Quiet frame annotations.
	t("空间结构 / 固定视角",24,658,14)
	t("SHELTER 01",901,658,14)
	if hovered != "":
		var spot: Rect2 = spots[hovered]
		for corner in [spot.position,spot.position+Vector2(spot.size.x,0),spot.end,spot.position+Vector2(0,spot.size.y)]:
			var toward: Vector2 = (spot.get_center()-corner).sign()
			l(corner,corner+Vector2(toward.x*17,0),UI.MINT,2)
			l(corner,corner+Vector2(0,toward.y*17),UI.MINT,2)
	draw_set_transform(Vector2.ZERO)
