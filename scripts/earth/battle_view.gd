extends Control
const C=preload("res://scripts/earth/catalog.gd")
const Art=preload("res://scripts/reboot/art.gd")
const Assets=preload("res://scripts/earth/assets.gd")
const Gait=preload("res://scripts/earth/gait.gd")
var game: Control
var frames: Dictionary={}
var backgrounds: Dictionary={}
var motion_data: Dictionary={}
const AnomalyUnit=preload("res://scripts/earth/anomaly_unit.gd")
var entity_layer: Node2D
var foreground: Node2D
var unit_nodes: Dictionary={}
var texture_cache: Dictionary={}


func actor_path(role: int,tier: int) -> String:
	var base="res://assets/earth/actors/"+C.PEOPLE[role].id
	var final_path=base+"/t%d/sprite_frames.tres"%tier
	if ResourceLoader.exists(final_path): return final_path
	var test_path=base+"/temp-test/sprite_frames.tres"
	return test_path if ResourceLoader.exists(test_path) else ""

func street_width() -> float:
	var width=0.0
	for i in range(1,6):
		var tex=backgrounds.get(str(i)) as Texture2D
		if tex!=null: width+=tex.get_width()*900.0/tex.get_height()
	return width

func street_rects(camera: float) -> Array:
	# Preserve source aspect and translate adjacent tiles continuously. Old code
	# stretched one entire 3:1 segment to 16:9 and swapped it every 2100 units.
	var offset=-clampf(camera,0,maxf(0,street_width()-1600))
	var rects=[]
	for i in range(1,6):
		var tex=backgrounds.get(str(i)) as Texture2D
		if tex==null: continue
		var width=tex.get_width()*900.0/tex.get_height()
		if offset<1600 and offset+width>0:
			rects.append({"texture":tex,"rect":Rect2(offset,0,width,900)})
		offset+=width
	return rects

func draw_street(camera: float) -> void:
	for tile in street_rects(camera):
		draw_texture_rect(tile.texture,tile.rect,false)

func _ready() -> void:
	size=Vector2(1600,900)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	entity_layer=Node2D.new();entity_layer.y_sort_enabled=true;add_child(entity_layer)
	foreground=Node2D.new();add_child(foreground)
	foreground.draw.connect(func():
		if game!=null and not game.model.s.battle.is_empty() and C.Anomalies.has_stage(game.model.s.battle.stage):draw_foreground_on(foreground,game.model.s.battle))
	Art.initialize()
	for id in ["pale-hair-katana","bull-spider"]:
		frames[id]=load("res://assets/character_sequences/"+id+"/sprite_frames.tres")
	for i in range(1,6): backgrounds[str(i)]=Assets.texture("battle.street.%d"%i)

func _draw() -> void:
	if game==null or game.model.s.battle.is_empty(): return
	var b=game.model.s.battle
	var m=C.mission(b.stage)
	if m.has("anomaly"):
		for tile in anomaly_rects(b.stage,b.camera):draw_texture_rect(tile.texture,tile.rect,false)
	elif m.bg=="street":
		draw_street(b.camera)
	else: draw_texture_rect(Assets.texture("battle."+m.bg),Rect2(0,0,1600,900),false)
	var sorted=[] if m.has("anomaly") else b.units.duplicate()
	sorted.sort_custom(func(a,c): return a.lane<c.lane)
	for u in sorted:
		var pos=Vector2(u.x-b.camera,u.lane)
		if pos.x< -300 or pos.x>1900: continue
		if u.side==0:
			var sprite_path=actor_path(u.role,u.suit)
			if sprite_path!="":
				if not frames.has(sprite_path): frames[sprite_path]=load(sprite_path)
				if not motion_data.has(sprite_path):
					var meta_path=sprite_path.get_base_dir().path_join("motion.json")
					motion_data[sprite_path]=JSON.parse_string(FileAccess.get_file_as_string(meta_path)) if FileAccess.file_exists(meta_path) else {}
				draw_actor(frames[sprite_path],u,pos,193.0 if u.role==4 else 215.0,motion_data[sprite_path])
			else:
				# Explicit identity stand-ins during staged production, never a shared replacement person.
				var p=C.portrait(u.role)
				var r=Rect2(pos-Vector2(50,110),Vector2(100,100))
				draw_texture_rect(p,r,false,Color(1,1,1,.35 if u.hp<=0 else 1))
				draw_style_box(card_border(u.suit),r)
		else:
			var custom=Assets.path("enemy.%s.%s"%[m.enemy,"boss" if u.boss else "normal"])
			if custom!="":
				if not frames.has(custom): frames[custom]=load(custom)
				if not motion_data.has(custom):
					var meta_path=custom.get_base_dir().path_join("motion.json")
					motion_data[custom]=JSON.parse_string(FileAccess.get_file_as_string(meta_path)) if FileAccess.file_exists(meta_path) else {}
				draw_actor(frames[custom],u,pos,260.0 if u.boss else 220.0,motion_data[custom])
			elif m.enemy=="katana" or u.boss and m.enemy=="hound":
				var kind="bull-spider" if u.boss and m.enemy=="hound" else "pale-hair-katana"
				draw_actor(frames[kind],u,pos,260.0 if u.boss else 220.0,{"stride_pixels":Gait.CYCLE_PIXELS[kind],"native_height":224})
			else:
				var action="fall" if u.hp<=0 else ("move" if u.state=="move" else "attack" if u.state=="attack" else "idle")
				var id=m.enemy
				if Art.manifest.has(id):
					var start=8 if u.boss else 0
					var f=start+int(u.anim*(8 if action=="move" else 2))%4
					if action=="attack": f=start+4+mini(3,int(u.anim*8))
					if action=="fall": f=start+3
					var tex=Art.frame(id,f)
					draw_texture_rect(tex,Rect2(pos-Vector2(95,210),Vector2(190,215)),false,Color(1,1,1,.25 if action=="fall" else 1))
		if u.hp>0:
			draw_rect(Rect2(pos+Vector2(-48,6),Vector2(96,6)),Color("182226"))
			draw_rect(Rect2(pos+Vector2(-48,6),Vector2(96*u.hp/u.max_hp,6)),Color("97c7a7") if u.side==0 else Color("d68472"))
		var title=C.PEOPLE[u.role].name if u.side==0 else (m.boss if u.boss else "异常体")
		draw_string(get_theme_default_font(),pos+Vector2(-48,33),title,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("ece8d7"))
	if not m.has("anomaly"):draw_foreground_on(self,b)

func draw_foreground_on(canvas: CanvasItem,b: Dictionary) -> void:
	for spirit in game.model.gear_spirits():
		var owner=b.units[spirit.owner]
		if owner.hp<=0:continue
		var pos=Vector2(owner.x-b.camera-26+spirit.slot*36,owner.lane-258+sin(b.time*3+spirit.owner)*5)
		draw_spirit_on(canvas,pos,spirit.kind,b.time)
	for e in b.effects:
		var pos=Vector2(e.x-b.camera,e.y-100)
		var custom=Assets.path("effect."+e.type)
		if custom!="":
			if not frames.has(custom):frames[custom]=load(custom)
			var sprite=frames[custom] as SpriteFrames
			if sprite!=null and sprite.has_animation("default") and sprite.get_frame_count("default")>0:
				var duration={"hit":.38,"heal":.7,"laser":.48,"enemy_laser":.45,"bomb":.7}[e.type]
				var frame=mini(sprite.get_frame_count("default")-1,int(maxf(0,duration-e.life)*sprite.get_animation_speed("default")))
				var tex=sprite.get_frame_texture("default",frame)
				canvas.draw_texture_rect(tex,Rect2(pos-tex.get_size()/2,tex.get_size()),false)
				continue
		if e.type=="laser":
			var origin=Vector2(e.source_x-b.camera,e.source_y) if e.has("source_x") else Vector2(0,240)
			canvas.draw_line(origin,pos,Color("88d844"),8,true)
			canvas.draw_line(origin,pos,Color("f0ffbd"),3,true)
		elif e.type=="enemy_laser": canvas.draw_line(Vector2(1600,250),pos,Color("ee846f"),5,true)
		elif e.type=="bomb": canvas.draw_arc(pos,85*(1-e.life),0,TAU,36,Color("ffac71"),5,true)
		else:
			canvas.draw_string(get_theme_default_font(),pos,e.get("text","+%d"%e.amount if e.type=="heal" else "-%d"%e.amount),HORIZONTAL_ALIGNMENT_LEFT,-1,25,Color("8cddaa") if e.type=="heal" else Color("fff1d2"))

func draw_spirit_on(canvas: CanvasItem,pos: Vector2,kind: String,time: float) -> void:
	var color={"laser":Color("b6ed64"),"bomb":Color("ffad56"),"regen":Color("85cced")}[kind]
	var dark=Color("141c19")
	var flap=sin(time*8)*5
	var left=PackedVector2Array([pos+Vector2(-10,-3),pos+Vector2(-31,-12+flap),pos+Vector2(-22,8),pos+Vector2(-8,11)])
	var right=PackedVector2Array([pos+Vector2(10,-3),pos+Vector2(31,-12+flap),pos+Vector2(22,8),pos+Vector2(8,11)])
	for wing in [left,right]:
		canvas.draw_colored_polygon(wing,color.darkened(.28));var border=wing.duplicate();border.append(wing[0]);canvas.draw_polyline(border,dark,3,true)
	canvas.draw_circle(pos,17,dark)
	canvas.draw_circle(pos,13,color)
	canvas.draw_arc(pos,12,0,PI,12,color.darkened(.4),4,true)
	if kind=="laser":
		canvas.draw_circle(pos+Vector2(3,-1),7,dark);canvas.draw_circle(pos+Vector2(5,-3),3,Color("fff7d6"))
	elif kind=="bomb":
		canvas.draw_colored_polygon(PackedVector2Array([pos+Vector2(-6,5),pos+Vector2(0,-10),pos+Vector2(7,5)]),dark)
	else:
		canvas.draw_line(pos+Vector2(-7,0),pos+Vector2(7,0),dark,4,true);canvas.draw_line(pos+Vector2(0,-7),pos+Vector2(0,7),dark,4,true)

func card_border(tier: int) -> StyleBoxFlat:
	var s=StyleBoxFlat.new()
	s.bg_color=Color(0,0,0,0)
	s.border_color=[Color("a4b4ae"),Color("d8bc7a"),Color("b6a0d3")][clampi(tier-1,0,2)]
	s.set_border_width_all(2)
	return s

func draw_actor(sprite: SpriteFrames,u: Dictionary,pos: Vector2,height: float,metadata: Dictionary={}) -> void:
	var action="idle" if not sprite.has_animation(u.state) else u.state
	var count=sprite.get_frame_count(action)
	if count==0: return
	var time=float(u.anim)
	var frame=int(time*sprite.get_animation_speed(action))
	frame=frame%count if sprite.get_animation_loop(action) else mini(count-1,frame)
	if action=="move": frame=Gait.frame(u.move_distance,float(metadata.get("stride_pixels",315))*height/float(metadata.get("native_height",224)),count)
	var tex=sprite.get_frame_texture(action,frame)
	var scale=height/float(metadata.get("native_height",224))
	var pivot=metadata.get("pivot",[216,235])
	var r=Rect2(-Vector2(pivot[0],pivot[1])*scale,Vector2(tex.get_width(),tex.get_height())*scale)
	# Legacy enemy source already faces left. Negative AtlasTexture rectangles offset margins.
	var source_direction=-1.0 if u.side==1 else 1.0
	draw_set_transform(pos,0,Vector2(u.get("facing",source_direction)/source_direction,1))
	draw_texture_rect(tex,r,false)
	draw_set_transform(Vector2.ZERO)

func cached_texture(path: String) -> Texture2D:
	if not texture_cache.has(path):texture_cache[path]=load(path)
	return texture_cache[path]

func cache_actor(path: String) -> void:
	if not frames.has(path):frames[path]=load(path)
	if not motion_data.has(path):
		var meta=path.get_base_dir().path_join("motion.json")
		motion_data[path]=JSON.parse_string(FileAccess.get_file_as_string(meta)) if FileAccess.file_exists(meta) else {}

func anomaly_rects(stage: int,camera: float) -> Array:
	var info=C.Anomalies.info(stage)
	var offset=-clampf(camera,0,maxf(0,info.world_width-1600))
	var result=[]
	for tile in info.scenes:
		if offset<1600 and offset+tile.world_width>0:result.append({"texture":cached_texture(tile.path),"rect":Rect2(offset,0,tile.world_width,900)})
		offset+=tile.world_width
	return result

func sync_anomaly_units() -> void:
	var active=game!=null and not game.model.s.battle.is_empty() and C.Anomalies.has_stage(game.model.s.battle.stage)
	entity_layer.visible=active;foreground.visible=active
	if not active:return
	var b=game.model.s.battle
	var keep={}
	for u in b.units:
		if u.hp<=0 and u.anim>1.7:continue
		keep[u.id]=true
		if not unit_nodes.has(u.id):
			unit_nodes[u.id]=AnomalyUnit.new();entity_layer.add_child(unit_nodes[u.id])
		unit_nodes[u.id].sync(self,u,b.stage)
	for id in unit_nodes.keys():
		if not keep.has(id):unit_nodes[id].queue_free();unit_nodes.erase(id)
	foreground.queue_redraw()

func _process(_delta: float) -> void:
	sync_anomaly_units()
