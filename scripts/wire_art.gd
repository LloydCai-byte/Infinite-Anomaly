extends Control
## Original vector placeholders: no external art, video or baked-in dialogue.
const UI = preload("res://scripts/ui_style.gd")
var kind: String = "hall":
	set(value):
		kind = value
		queue_redraw()
var ink: Color = UI.INK
var accent: Color = UI.MINT
var concealed: bool = false
var shot: int = 0
var storyboard: bool = false
var solo: bool = false
var label_font = UI.font()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func line(a: Vector2, b: Vector2, color: Color = ink, width: float = 1.5) -> void:
	draw_line(a, b, color, width, true)

func rect(x: float, y: float, w: float, h: float, color: Color = ink, width: float = 1.5) -> void:
	draw_rect(Rect2(x, y, w, h), color, false, width)

func circle(x: float, y: float, radius: float, color: Color = ink, width: float = 1.5) -> void:
	draw_arc(Vector2(x, y), radius, 0, TAU, 64, color, width, true)

func text_at(text: String, point: Vector2, font_size: int = 18, color: Color = ink) -> void:
	draw_string(label_font, point, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func figure(x: float, y: float, scale_value: float = 1.0, second: bool = false) -> void:
	var c: Color = accent if second else ink
	var k: float = scale_value
	if second:
		rect(x - 7*k, y - 48*k, 14*k, 15*k, c)
	else:
		circle(x, y - 41*k, 8*k, c)
	line(Vector2(x-8*k, y-30*k), Vector2(x+8*k, y-30*k), c)
	line(Vector2(x-8*k, y-30*k), Vector2(x-7*k, y-10*k), c)
	line(Vector2(x+8*k, y-30*k), Vector2(x+7*k, y-10*k), c)
	line(Vector2(x-7*k, y-10*k), Vector2(x+7*k, y-10*k), c)
	line(Vector2(x-5*k, y-10*k), Vector2(x-8*k, y+9*k), c)
	line(Vector2(x+5*k, y-10*k), Vector2(x+8*k, y+9*k), c)
	line(Vector2(x-8*k, y-27*k), Vector2(x-16*k, y-12*k), c)
	line(Vector2(x+8*k, y-27*k), Vector2(x+17*k, y-17*k), c)
	line(Vector2(x-4*k, y-24*k), Vector2(x+4*k, y-24*k), UI.MUTED)

func _draw() -> void:
	var scale_value: float = minf(size.x / 320.0, size.y / 190.0)
	var offset: Vector2 = (size - Vector2(320, 190) * scale_value) * 0.5
	draw_set_transform(offset, 0, Vector2.ONE * scale_value)
	if concealed:
		rect(111, 36, 98, 120, UI.LINE)
		for i in range(5):
			line(Vector2(125, 61+i*17), Vector2(195, 61+i*17), UI.LINE)
		text_at("?", Vector2(148, 117), 38, UI.MUTED)
		draw_set_transform(Vector2.ZERO)
		return
	match kind:
		"hall":
			rect(125, 42, 70, 95, UI.MUTED)
			for point in [Vector2(5, 0), Vector2(315, 0), Vector2(5, 185), Vector2(315, 185)]:
				line(point, Vector2(125 if point.x < 160 else 195, 42 if point.y < 90 else 137), UI.LINE)
			for i in range(3):
				var x: float = 24 + i * 33
				line(Vector2(x, 25 + i*7), Vector2(x, 165-i*9), UI.MUTED)
				line(Vector2(320-x, 25+i*7), Vector2(320-x, 165-i*9), UI.MUTED)
			line(Vector2(143, 137), Vector2(107, 188), UI.LINE)
			line(Vector2(178, 137), Vector2(217, 188), UI.LINE)
			figure(142-shot*4, 143+shot*5, 0.8+shot*0.08)
			figure(182+shot*5, 143+shot*4, 0.8+shot*0.08, true)
		"elevator":
			rect(61, 20, 198, 164)
			rect(73, 34, 171, 150, UI.MUTED)
			line(Vector2(158, 34), Vector2(158, 184), UI.MUTED)
			rect(134, 2, 49, 18, accent)
			text_at("13" if shot % 2 == 0 else "↓ 10", Vector2(141, 16), 13, accent)
			for i in range(3):
				circle(276, 88+i*15, 3, UI.MUTED)
			figure(160 if solo else 120, 166, 1.1)
			if not solo:
				figure(201, 166, 1.1, true)
		"key":
			rect(71, 39, 178, 112, accent, 2)
			rect(85, 58, 31, 25)
			for i in range(3):
				line(Vector2(135, 64+i*10), Vector2(223-i*9, 64+i*10), UI.MUTED)
			line(Vector2(85, 113), Vector2(234, 113), UI.LINE)
			text_at("NO. 013", Vector2(86, 137), 18)
			for i in range(12):
				line(Vector2(184+i*4, 123), Vector2(184+i*4, 137), UI.MUTED, 1)
		"floors":
			rect(65, 34, 190, 123)
			rect(78, 47, 164, 97, UI.LINE)
			text_at("13", Vector2(107, 115), 64, accent)
			line(Vector2(212, 72), Vector2(212, 113), accent, 2)
			line(Vector2(203, 102), Vector2(212, 113), accent, 2)
			line(Vector2(221, 102), Vector2(212, 113), accent, 2)
			for p in [Vector2(72,41), Vector2(248,41), Vector2(72,150), Vector2(248,150)]:
				circle(p.x, p.y, 2, UI.MUTED)
		"phone":
			rect(88, 98, 148, 60)
			rect(117, 107, 60, 40, UI.LINE)
			for i in range(3):
				for j in range(3):
					rect(125+i*15, 114+j*10, 5, 4, UI.MUTED, 1)
			var points = PackedVector2Array([Vector2(93,86),Vector2(91,52),Vector2(112,39),Vector2(210,39),Vector2(231,52),Vector2(229,86),Vector2(209,86),Vector2(206,60),Vector2(115,60),Vector2(113,86),Vector2(93,86)])
			draw_polyline(points, accent, 2, true)
			for i in range(5):
				circle(249, 105+i*8, 4, UI.MUTED, 1)
			line(Vector2(249,145),Vector2(270,162),UI.MUTED)
			line(Vector2(277,166),Vector2(289,174),UI.MUTED)
			if storyboard and shot == 1:
				for i in range(3):
					draw_arc(Vector2(90,60),16+i*10,PI-0.7,PI+0.7,18,accent,1.5,true)
				figure(35,170,0.8,true)
			if storyboard and shot >= 2:
				rect(76,24,166,148,accent,2)
				line(Vector2(76,24),Vector2(64,11),UI.MUTED)
				line(Vector2(242,24),Vector2(257,11),UI.MUTED)
				line(Vector2(64,11),Vector2(257,11),UI.MUTED)
				if shot == 2:
					line(Vector2(24,80),Vector2(70,67),ink,2)
					line(Vector2(24,94),Vector2(70,82),ink,2)
					line(Vector2(298,80),Vector2(247,67),accent,2)
					line(Vector2(298,94),Vector2(247,82),accent,2)
				else:
					rect(128,160,60,21,accent,1)
		"exit":
			rect(50, 45, 220, 88, accent, 2)
			rect(57, 52, 206, 74, UI.LINE)
			text_at("EXIT", Vector2(74, 107), 42, accent)
			line(Vector2(196,88),Vector2(246,88),accent,3)
			line(Vector2(231,73),Vector2(246,88),accent,3)
			line(Vector2(231,103),Vector2(246,88),accent,3)
			for i in range(4):
				line(Vector2(42+i*65,150),Vector2(75+i*65,180),UI.LINE)
		"watch":
			rect(144, 3, 33, 40, UI.MUTED)
			rect(144, 143, 33, 42, UI.MUTED)
			circle(160, 94, 51, accent, 2)
			circle(160, 94, 44, UI.MUTED)
			for i in range(12):
				var angle: float = i*TAU/12.0
				line(Vector2(160,94)+Vector2.from_angle(angle)*36, Vector2(160,94)+Vector2.from_angle(angle)*41, UI.MUTED)
			line(Vector2(160,94),Vector2(140,73),accent,2)
			line(Vector2(160,94),Vector2(180,99),accent,2)
			rect(211,85,9,15,UI.MUTED)
		"book":
			var outline = PackedVector2Array([Vector2(77,42),Vector2(148,36),Vector2(160,45),Vector2(174,36),Vector2(245,42),Vector2(245,150),Vector2(174,144),Vector2(160,153),Vector2(148,144),Vector2(77,150),Vector2(77,42)])
			draw_polyline(outline, ink, 2, true)
			line(Vector2(160,45),Vector2(160,153),UI.MUTED)
			for i in range(5):
				line(Vector2(89,62+i*15),Vector2(142,58+i*15),UI.LINE)
				line(Vector2(178,58+i*15),Vector2(232,62+i*15),accent if i==2 else UI.LINE)
		"badge":
			line(Vector2(132,5),Vector2(155,54),UI.MUTED)
			line(Vector2(185,5),Vector2(166,54),UI.MUTED)
			rect(105,53,111,116,accent,2)
			rect(144,60,30,9,UI.MUTED)
			rect(120,82,80,45,UI.LINE)
			line(Vector2(130,144),Vector2(190,144),ink)
			text_at("013",Vector2(143,114),22,UI.MUTED)
		"warden":
			circle(159,45,20,ink,2)
			line(Vector2(137,33),Vector2(181,33),accent,3)
			var coat = PackedVector2Array([Vector2(136,69),Vector2(124,150),Vector2(193,150),Vector2(181,69),Vector2(136,69)])
			draw_polyline(coat, ink, 2, true)
			line(Vector2(159,72),Vector2(159,145),UI.MUTED)
			line(Vector2(135,150),Vector2(132,185),ink,2)
			line(Vector2(182,150),Vector2(185,185),ink,2)
			rect(188,104,45,61,accent)
			line(Vector2(181,76),Vector2(207,105),ink,2)
			line(Vector2(136,76),Vector2(108,127),ink,2)
			rect(166,82,11,6,UI.LINE)
		"speaker":
			rect(110,32,100,103,ink,2)
			circle(160,84,36,accent,2)
			circle(160,84,23,UI.MUTED)
			circle(160,84,9,ink)
			for i in range(3):
				draw_arc(Vector2(160,84), 55+i*17,-0.6,0.6,24,UI.LINE,1.5,true)
				draw_arc(Vector2(160,84), 55+i*17,PI-0.6,PI+0.6,24,UI.LINE,1.5,true)
			text_at("姓名确认中",Vector2(112,165),18,accent)
		"portal":
			for i in range(5):
				rect(70+i*12,15+i*7,180-i*24,169-i*14,accent if i==4 else UI.LINE)
			figure(160 if solo else 146,142,1.1)
			if not solo:
				figure(180,142,1.1,true)
		"base":
			rect(80,22,165,115,UI.LINE)
			line(Vector2(80,137),Vector2(17,187),UI.MUTED)
			line(Vector2(245,137),Vector2(305,187),UI.MUTED)
			rect(99,72,58,40,accent)
			line(Vector2(128,112),Vector2(128,128),UI.MUTED)
			line(Vector2(75,133),Vector2(176,133),ink)
			line(Vector2(84,133),Vector2(84,165),ink)
			line(Vector2(169,133),Vector2(169,165),ink)
			rect(193,45,38,88,UI.MUTED)
			for i in range(3):
				line(Vector2(193,68+i*21),Vector2(231,68+i*21),UI.LINE)
	if storyboard and shot == 3 and kind in ["key","floors","exit","warden","book"]:
		rect(35,8,250,174,UI.LINE)
		line(Vector2(35,166),Vector2(100,166),accent,2)
		text_at("记录 / 封存",Vector2(206,174),13,accent)
	draw_set_transform(Vector2.ZERO)
