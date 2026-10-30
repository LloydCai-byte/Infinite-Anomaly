extends RefCounted
# User-supplied reference is an immutable atlas. Only ornament is sampled;
# all changing content, item slots and hit targets are rendered by equipment_ui.
const PATH="res://art/equipment-reference-20261028/reference.png"
const NAVY=Rect2(1430,441,175,164)
const CREAM=Rect2(800,241,180,43)
const ORANGE=Rect2(345,168,49,29)
const BLUE=Rect2(591,162,46,39)
const GRID=Rect2(222,313,60,62)
var texture:Texture2D

func _init() -> void:
	texture=ImageTexture.create_from_image(Image.load_from_file(PATH))

func region(canvas:CanvasItem,dest:Rect2,source:Rect2) -> void:
	canvas.draw_texture_rect_region(texture,dest,source)

func tile(canvas:CanvasItem,dest:Rect2,source:Rect2,scale:float) -> void:
	var step=source.size*scale
	var y=dest.position.y
	while y<dest.end.y:
		var x=dest.position.x
		while x<dest.end.x:
			var size=Vector2(minf(step.x,dest.end.x-x),minf(step.y,dest.end.y-y))
			region(canvas,Rect2(Vector2(x,y),size),Rect2(source.position,size/scale))
			x+=step.x
		y+=step.y

func box(canvas:CanvasItem,dest:Rect2,source:Rect2,fill:Rect2,scale:float,edge:float=7) -> void:
	region(canvas,dest,fill)
	# Eight perimeter regions keep the original bevels, scratches and corners.
	var sx=[source.position.x,source.position.x+edge,source.end.x-edge]
	var sy=[source.position.y,source.position.y+edge,source.end.y-edge]
	var sw=[edge,source.size.x-2*edge,edge]
	var sh=[edge,source.size.y-2*edge,edge]
	var e=edge*scale
	var dx=[dest.position.x,dest.position.x+e,dest.end.x-e]
	var dy=[dest.position.y,dest.position.y+e,dest.end.y-e]
	var dw=[e,dest.size.x-2*e,e]
	var dh=[e,dest.size.y-2*e,e]
	for row in range(3):
		for col in range(3):
			if row==1 and col==1:continue
			region(canvas,Rect2(dx[col],dy[row],dw[col],dh[row]),Rect2(sx[col],sy[row],sw[col],sh[row]))
