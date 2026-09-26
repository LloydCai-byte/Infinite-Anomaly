extends RefCounted
const BG = Color("10191c")
const PANEL = Color("142125")
const RAISED = Color("1a2b2e")
const LINE = Color("3d575b")
const INK = Color("cddfd9")
const MUTED = Color("829b98")
const MINT = Color("b4e0c8")
const GOLD = Color("d8be7c")
const WARN = Color("dda77f")

static func box(background: Color = PANEL, border: Color = LINE, width: int = 1, radius: int = 3) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style

static func font() -> SystemFont:
	var result = SystemFont.new()
	result.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	return result

static func theme() -> Theme:
	var result = Theme.new()
	result.default_font = font()
	result.default_font_size = 20
	result.set_color("font_color", "Label", INK)
	result.set_color("font_color", "Button", INK)
	result.set_color("font_hover_color", "Button", Color.WHITE)
	result.set_color("font_pressed_color", "Button", MINT)
	result.set_color("font_disabled_color", "Button", Color("637876"))
	result.set_stylebox("normal", "Button", box(PANEL, LINE))
	result.set_stylebox("hover", "Button", box(RAISED, MINT))
	result.set_stylebox("pressed", "Button", box(Color("234038"), MINT))
	result.set_stylebox("disabled", "Button", box(Color("142023"), Color("293e42")))
	result.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), GOLD, 2))
	result.set_stylebox("panel", "Panel", box())
	result.set_stylebox("panel", "PanelContainer", box())
	result.set_stylebox("background", "ProgressBar", box(Color("0d1517"), LINE))
	result.set_stylebox("fill", "ProgressBar", box(MINT, MINT))
	result.set_color("font_color", "CheckBox", INK)
	result.set_stylebox("panel", "TooltipPanel", box(BG, MINT))
	result.set_color("font_color", "TooltipLabel", INK)
	return result
