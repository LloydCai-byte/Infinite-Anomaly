extends RefCounted
## One bundled family for every live game surface; independent of OS fonts.
const ROOT="res://assets/fonts/source-han-sans/"
static var regular_font:FontFile
static var bold_font:FontFile
static func read_font(path:String)->FontFile:
	var font=FontFile.new()
	font.data=FileAccess.get_file_as_bytes(path)
	font.allow_system_fallback=false
	return font
static func regular()->FontFile:
	if regular_font==null:regular_font=read_font(ROOT+"SourceHanSansSC-Regular.otf")
	return regular_font
static func bold()->FontFile:
	if bold_font==null:bold_font=read_font(ROOT+"SourceHanSansSC-Bold.otf")
	return bold_font
static func install(window:Window)->void:
	var theme=Theme.new();theme.default_font=regular();theme.default_font_size=20
	for type in ["Label","Button","LineEdit","SpinBox","PopupMenu","TooltipLabel"]:theme.set_font("font",type,regular())
	for key in ["normal_font","italics_font","mono_font"]:theme.set_font(key,"RichTextLabel",regular())
	for key in ["bold_font","bold_italics_font"]:theme.set_font(key,"RichTextLabel",bold())
	window.theme=theme
