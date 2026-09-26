extends Button
var caption = ""
var reveal = false
var visited = false
var hovering = false
signal pointed(value: String)

func _ready() -> void:
	flat = true
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","focus"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
	mouse_entered.connect(func(): hovering = true; pointed.emit(caption); queue_redraw())
	mouse_exited.connect(func(): hovering = false; pointed.emit(""); queue_redraw())
	focus_entered.connect(func(): hovering = true; pointed.emit(caption); queue_redraw())
	focus_exited.connect(func(): hovering = false; pointed.emit(""); queue_redraw())

func _draw() -> void:
	if not hovering and not reveal: return
	var center = size * 0.5
	var c = Color("b7e1d0") if visited else Color("f3eed9")
	draw_circle(center,4,c)
	draw_arc(center,18 if hovering else 13,0,TAU,40,c,1.6,true)
	if hovering:
		draw_line(center+Vector2(-29,0),center+Vector2(-22,0),c,1)
		draw_line(center+Vector2(22,0),center+Vector2(29,0),c,1)
