extends Control
## Small toolbar symbols use geometry centered on their button's inner area.
var symbol=""
func _ready()->void:
	mouse_filter=MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func _draw()->void:
	var c=size*.5
	var color=Color("ffe5ac")
	if symbol in ["+","−"]:
		draw_line(c-Vector2(6,0),c+Vector2(6,0),color,2)
		if symbol=="+":draw_line(c-Vector2(0,6),c+Vector2(0,6),color,2)
	else:
		var direction=-1.0 if symbol=="‹" else 1.0
		draw_polyline(PackedVector2Array([c+Vector2(-direction*3,-6),c+Vector2(direction*3,0),c+Vector2(-direction*3,6)]),color,2)
