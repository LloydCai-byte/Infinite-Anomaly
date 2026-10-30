extends RefCounted
static func theme(_heading:Dictionary) -> Dictionary:return {"marker":"diamond"}
static func draw(view,heading:Dictionary) -> void:
	var count=maxi(1,int(heading.count));var current=int(heading.index)
	var first=Vector2(44,39);var step=43.0
	view.draw_line(first+Vector2(2,3),first+Vector2((count-1)*step+2,3),Color(0,0,0,.8),6)
	view.draw_line(first,first+Vector2((count-1)*step,0),Color("536a75"),2)
	for i in range(count):
		var done=i<current or (i==current and heading.get("cleared",false))
		var pos=first+Vector2(i*step,0)
		var color=Color("e6bb69") if done else Color("a9e4eb") if i==current else Color("526373")
		var diamond=PackedVector2Array([pos+Vector2(0,-7),pos+Vector2(7,0),pos+Vector2(0,7),pos+Vector2(-7,0)])
		view.draw_colored_polygon(diamond,color)
		var edge=diamond.duplicate();edge.append(diamond[0]);view.draw_polyline(edge,Color("080e18"),3)
		if i==current:view.draw_rect(Rect2(pos-Vector2(2,2),Vector2(4,4)),Color.WHITE)
	var kind="战" if heading.get("finale",false) else "波" if heading.get("room",false) else "景"
	view.text("%d / %d%s"%[current+1,count,kind],Vector2(33,81),19)
	view.text("难度 %d"%int(heading.get("difficulty",1)),Vector2(163,81),18,Color("e3cc9d"))
	view.text("剩余 %d"%int(heading.get("enemies",5)),Vector2(286,81),18,Color("c2d2db"))
