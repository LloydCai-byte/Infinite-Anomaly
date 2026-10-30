extends RefCounted
## Calibrated ground footprints. Original sprite art, scale and movement stay untouched.
const PATH="res://assets/pixel_campaign/ground_shadows.json"
const GRID=2.0
var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(PATH))
var enabled=true
func palette(path:String)->Dictionary:
	return data.scenes.get(path,{"color":"#1b2027","outer_alpha":.22})
func pose(view,u:Dictionary)->Dictionary:
	var id=str(u.get("visual_id",u.id));var clip=str(u.anim)
	if u.hit_time>0 and (view.model.action.is_empty() or view.model.action.actor!=u.uid) and u.hp>0:clip="hurt"
	var profile=data.actors.get(id,data.actors.get(str(u.id),{}))
	if profile.is_empty():return {}
	var frame=0;var feet:Array
	if clip=="die":
		feet=profile.standing
	else:
		if not profile.clips.has(clip):clip="idle"
		var frames=profile.clips[clip];var spec=view.roster[id].clips[clip]
		frame=0 if clip=="idle" else floori(u.anim_time*float(spec.fps))
		frame=posmod(frame,frames.size()) if clip=="walk" else mini(frame,frames.size()-1)
		feet=frames[frame]
	return {"id":id,"clip":clip,"frame":frame,"feet":feet}
func geometry(view,u:Dictionary,opacity:float=1.0)->Dictionary:
	if not enabled or opacity<=0 or (u.hp<=0 and u.dead_time>1.1):return {}
	var current=pose(view,u)
	if current.is_empty():return {}
	var scale=view.battle_actor_scale(u);var foot=u.pos.round()
	var alpha=(clampf(1-u.dead_time/1.2,0,1) if u.hp<=0 else 1.0)*opacity
	var left=INF;var right=-INF;var y_sum=0.0;var lift=INF;var contacts=[]
	for sole in current.feet:
		var x=float(sole.x);var y=float(sole.get("ground_y",sole.y));var width=float(sole.width)
		left=minf(left,x-width*.5);right=maxf(right,x+width*.5);y_sum+=y
		var raised=float(sole.get("lift",0));lift=minf(lift,raised)
		var strength=clampf(1-raised/3.5,0,1) if u.hp>0 else 0.0
		contacts.append({"point":foot+(Vector2(x,y)-Vector2(80,128))*scale,"radii":Vector2(width*.5+1,1.5)*scale,"strength":strength})
	var center=foot+(Vector2((left+right)*.5,y_sum/current.feet.size())-Vector2(80,128))*scale
	var span=right-left
	var radii=Vector2(span*.5+4,maxf(3.3,span*.085))*scale
	var airborne=clampf(lift/10.0,0,1)
	radii*=1.0+airborne*.18
	if u.hp<=0:radii.x*=1.12
	return {"center":center+Vector2(0,2),"radii":radii,"contacts":contacts,"opacity":alpha,"airborne":airborne,"pose":current}
func ellipse(canvas:CanvasItem,center:Vector2,radii:Vector2,color:Color)->void:
	# Integer-grid filled strips preserve pixel edges, without a blurred texture.
	if color.a<=.001:return
	var cy=snappedf(center.y,GRID);var cx=snappedf(center.x,GRID)
	var rows=maxi(1,ceili(radii.y/GRID))
	for row in range(-rows,rows):
		var yy=(row+.5)*GRID;var t=yy/maxf(GRID,radii.y)
		if absf(t)>=1:continue
		var half=snappedf(radii.x*sqrt(1-t*t),GRID)
		if half>0:canvas.draw_rect(Rect2(cx-half,cy+row*GRID,half*2,GRID),color)
func draw(view,u:Dictionary,opacity:float,path:String)->void:
	var g=geometry(view,u,opacity)
	if g.is_empty():return
	var p=palette(path);var ink=Color(p.color);var outer=float(p.outer_alpha)*(1-g.airborne*.45)*g.opacity
	# Desired cumulative broad alpha is 0.07 / 0.16 / 0.24, not three opaque stacked blobs.
	var previous=0.0
	for band in [[1.0,.30],[.86,.67],[.66,1.0]]:
		var target=outer*band[1];ink.a=(target-previous)/maxf(.001,1-previous)
		ellipse(view,g.center,g.radii*band[0],ink);previous=target
	for contact in g.contacts:
		var strength=float(contact.strength)*g.opacity
		if strength<=0:continue
		ink.a=.23*strength;ellipse(view,contact.point,contact.radii,ink)
		ink.a=.17*strength;ellipse(view,contact.point,Vector2(contact.radii.x*.78,maxf(1.6,contact.radii.y*.5)),ink)
