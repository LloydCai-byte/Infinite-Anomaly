extends Control
## A left-hinged door opens into the selected world's actual battle background.
var destination: Texture2D
var opening=0.14:
	set(value):opening=value;queue_redraw()
var locked=false

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var amber=Color("ffad3d")
	for row in range(9):
		for col in range(9):
			var p=Vector2(col*75+(37 if row%2 else 0),row*83)
			var points=PackedVector2Array()
			for i in range(7):points.append(p+Vector2.from_angle(i*TAU/6)*44)
			draw_polyline(points,Color(0.28,.45,.32,.20),1,true)
	var frame=Rect2(129,27,405,552)
	draw_rect(frame.grow(12),Color("070908"))
	draw_rect(frame.grow(8),amber,false,3)
	draw_rect(frame,Color("222b23"),false,8)
	var inner=Rect2(136,34,391,538)
	if destination!=null:
		var sz=destination.get_size()
		var ratio=inner.size.x/inner.size.y
		var region=Rect2((sz.x-sz.y*ratio)*.5,0,sz.y*ratio,sz.y)
		draw_texture_rect_region(destination,inner,region,Color(.30,.35,.30) if locked else Color.WHITE)
	# The door leaf stays attached to the SAME left hinge as it opens inward.
	var width=inner.size.x*(1-opening)
	var skew=opening*63
	var leaf=PackedVector2Array([inner.position,Vector2(inner.position.x+width,inner.position.y+skew),Vector2(inner.position.x+width,inner.end.y-skew),Vector2(inner.position.x,inner.end.y)])
	draw_colored_polygon(leaf,Color("161b19"))
	var outline=leaf.duplicate();outline.append(leaf[0]);draw_polyline(outline,Color("7e887c"),3,true)
	if opening<.92:
		var handle=Vector2(inner.position.x+width-24,inner.position.y+330)
		draw_line(handle,handle+Vector2(-24*(1-opening),0),amber,5,true)
	for y in [105,280,484]:draw_rect(Rect2(127,y,10,29),Color("a0a393"))
	for i in range(9):
		var x=130+i*46
		draw_colored_polygon(PackedVector2Array([Vector2(x,596),Vector2(x+20,596),Vector2(x+34,581),Vector2(x+14,581)]),amber)
