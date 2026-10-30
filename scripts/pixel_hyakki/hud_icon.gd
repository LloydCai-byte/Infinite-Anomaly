extends Control
var image:Texture2D
func _ready()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
func _process(_dt:float)->void:queue_redraw()
func _draw()->void:
	if image==null:return
	var fitted=image.get_size()*minf(30.0/image.get_width(),30.0/image.get_height())
	var rect=Rect2((size-fitted)*.5,fitted)
	draw_texture_rect(image,Rect2(rect.position+Vector2(3,4),rect.size),false,Color(0,0,0,.7))
	for offset in [Vector2(-2,0),Vector2(2,0),Vector2(0,-2),Vector2(0,2),Vector2(-1,-1),Vector2(1,1)]:draw_texture_rect(image,Rect2(rect.position+offset,rect.size),false,Color("060b12"))
	draw_texture_rect(image,rect,false,Color(1.2,1.15,1.04) if get_parent().is_hovered() else Color.WHITE)
