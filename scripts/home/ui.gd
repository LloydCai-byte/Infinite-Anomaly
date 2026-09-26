extends RefCounted
const INK = Color("#e2e2d9")
const MUTED = Color("#989f99")
const ACCENT = Color("#a7c3b2")
const PANEL = Color("#192021")
const SCREEN = Color("#101718")
const GOLD = Color("#d6bf8f")
const WARNING = Color("#d9a088")

static func box(color: Color, border: Color = Color.TRANSPARENT, radius: int = 12, width: int = 1) -> StyleBoxFlat:
	var b = StyleBoxFlat.new()
	b.bg_color = color
	b.border_color = border
	b.set_border_width_all(width)
	b.set_corner_radius_all(radius)
	b.content_margin_left = 14
	b.content_margin_right = 14
	b.content_margin_top = 6
	b.content_margin_bottom = 6
	return b

static func theme() -> Theme:
	var t = Theme.new()
	var f = SystemFont.new()
	f.font_names = PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei","Noto Sans CJK SC","sans-serif"])
	t.default_font = f
	t.default_font_size = 22
	for type in ["Label","Button","CheckButton","CheckBox"]:
		t.set_color("font_color",type,INK)
	t.set_color("font_hover_color","Button",Color.WHITE)
	t.set_color("font_disabled_color","Button",Color("#68716c"))
	t.set_stylebox("normal","Button",box(PANEL,Color("#38453f")))
	t.set_stylebox("hover","Button",box(Color("#283832"),ACCENT))
	t.set_stylebox("pressed","Button",box(Color("#364b40"),ACCENT))
	t.set_stylebox("disabled","Button",box(Color("#151c1d"),Color("#2a3230")))
	t.set_stylebox("focus","Button",box(Color.TRANSPARENT,GOLD,12,2))
	return t

static func place(node: Control, parent: Node, rect: Rect2) -> Control:
	parent.add_child(node)
	node.position = rect.position
	node.size = rect.size
	return node

static func panel(parent: Node, rect: Rect2, color: Color = PANEL, radius: int = 14, border: Color = Color.TRANSPARENT) -> Panel:
	var p = Panel.new()
	place(p,parent,rect)
	p.add_theme_stylebox_override("panel",box(color,border,radius))
	return p

static func text(parent: Node, value: String, rect: Rect2, pixels: int = 22, color: Color = INK, wrap: bool = false) -> Label:
	var l = Label.new()
	place(l,parent,rect)
	l.text = value
	l.add_theme_font_size_override("font_size",pixels)
	l.add_theme_color_override("font_color",color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		l.clip_text = true
	return l

static func button(parent: Node, value: String, rect: Rect2, callback: Callable, prominent: bool = false) -> Button:
	var b = Button.new()
	place(b,parent,rect)
	b.text = value
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(callback)
	if prominent:
		b.add_theme_stylebox_override("normal",box(Color("#344a40"),ACCENT))
	return b

static func image(parent: Node, path: String, rect: Rect2) -> TextureRect:
	var t = TextureRect.new()
	place(t,parent,rect)
	t.texture = load(path)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.clip_contents = true
	return t

static func line(parent: Node, rect: Rect2, color: Color) -> ColorRect:
	var n = ColorRect.new()
	place(n,parent,rect)
	n.color = color
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return n

