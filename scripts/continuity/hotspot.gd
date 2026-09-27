extends Button
var reveal: bool = false
var hovering: bool = false
var active_color = Color("eee7d7")
signal pointed(value: bool)

func _ready() -> void:
	flat = true
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","focus"]:
		add_theme_stylebox_override(state,StyleBoxEmpty.new())
	mouse_entered.connect(set_hover.bind(true))
	mouse_exited.connect(set_hover.bind(false))
	focus_entered.connect(set_hover.bind(true))
	focus_exited.connect(set_hover.bind(false))

func set_hover(value: bool) -> void:
	hovering = value
	pointed.emit(value)
	queue_redraw()

func _draw() -> void:
	if not hovering and not reveal:
		return
	var center = size * 0.5
	draw_circle(center,3,active_color)
	draw_arc(center,16 if hovering else 11,0,TAU,40,active_color,1.5,true)
	if hovering:
		draw_arc(center,23,0.2,1.35,16,active_color,1,true)
		draw_arc(center,23,PI+0.2,PI+1.35,16,active_color,1,true)
