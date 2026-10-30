extends Node2D
## Draw after the interface so the middle frame is actually black.
var host
func _process(_delta:float) -> void:queue_redraw()
func _draw() -> void:
	if host!=null and host.screen=="battle" and host.travel.active:
		draw_rect(Rect2(0,0,1600,900),Color(0,0,0,host.travel.cover_alpha()))
