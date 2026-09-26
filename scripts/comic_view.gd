extends Control
const UI = preload("res://scripts/ui_style.gd")
const Art = preload("res://scripts/wire_art.gd")
var comic: Dictionary = {}
var revealed: int = 4
var compact: bool = false
var signature: String = ""

func display(value: Dictionary, count: int, small: bool = false) -> void:
	var next_signature: String = str(value.get("title", "")) + str(count) + str(small) + str(size)
	if signature == next_signature:
		return
	signature = next_signature
	comic = value
	revealed = count
	compact = small
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if comic.is_empty():
		return
	var panel_count: int = 1 if compact else 4
	for i in range(panel_count):
		var actual: int = maxi(0, revealed - 1) if compact else i
		var width: float = size.x if compact else (size.x-20)/2.0
		var height: float = size.y if compact else (size.y-18)/2.0
		var panel = Panel.new()
		panel.position = Vector2.ZERO if compact else Vector2((i%2)*(width+20),floori(i/2.0)*(height+18))
		panel.size = Vector2(width,height)
		panel.add_theme_stylebox_override("panel",UI.box(Color("101b1e"),UI.LINE))
		add_child(panel)
		var art = Art.new()
		art.position = Vector2(12,12)
		art.size = Vector2(width-24,height-99)
		art.kind = comic.panels[actual].scene
		art.shot = actual
		art.storyboard = true
		art.solo = str(comic.title).begins_with("开场")
		art.concealed = actual >= revealed
		panel.add_child(art)
		var caption = Label.new()
		caption.position = Vector2(18,height-81)
		caption.size = Vector2(width-36,74)
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption.add_theme_font_size_override("font_size",18 if compact else 21)
		caption.text = comic.panels[actual].text if actual < revealed else "等待前线记录…"
		caption.modulate = UI.INK if actual < revealed else UI.MUTED
		panel.add_child(caption)
		var number = Label.new()
		number.position = Vector2(14,8)
		number.text = "%02d" % (actual+1)
		number.add_theme_font_size_override("font_size",15)
		number.modulate = UI.MUTED
		panel.add_child(number)
