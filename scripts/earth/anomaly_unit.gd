extends Node2D
const C=preload("res://scripts/earth/catalog.gd")
const Gait=preload("res://scripts/earth/gait.gd")
const KeyShader=preload("res://scripts/earth/chroma_key.gdshader")
var body: Node2D
var sprite: Sprite2D
var unit: Dictionary={}
var label=""

func _init() -> void:
	body=Node2D.new();add_child(body)
	sprite=Sprite2D.new();sprite.centered=false;sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	body.add_child(sprite)

func sync(view: Control,u: Dictionary,stage: int) -> void:
	unit=u;position=Vector2(u.x-view.game.model.s.battle.camera,u.lane)
	visible=position.x> -400 and position.x<2000
	var metadata: Dictionary
	var height=215.0
	var pivot: Array
	var scale_factor: float
	var source_direction=1.0
	if u.side==1:
		var enemy=C.Anomalies.info(stage).enemies[int(u.get("variant",0))]
		var pose=enemy.poses.attack if u.state=="attack" and u.anim>.06 and u.anim<.36 else enemy.poses.idle
		sprite.texture=view.cached_texture(pose.path)
		pivot=pose.pivot;height=enemy.height
		scale_factor=height/float(enemy.native_height)
		label=enemy.name
		if sprite.material==null:
			var key=ShaderMaterial.new();key.shader=KeyShader;sprite.material=key
		sprite.material.set_shader_parameter("hurt",maxf(0,1-u.anim/.22) if u.state=="hit" else 0.0)
	else:
		var path=view.actor_path(u.role,u.suit)
		if path=="":visible=false;return
		view.cache_actor(path)
		var frames=view.frames[path] as SpriteFrames
		metadata=view.motion_data[path]
		var action=u.state if frames.has_animation(u.state) else "idle"
		var count=frames.get_frame_count(action)
		var frame=int(u.anim*frames.get_animation_speed(action))
		frame=frame%count if frames.get_animation_loop(action) else mini(count-1,frame)
		height=193.0 if u.role==4 else 215.0
		if action=="move":frame=Gait.frame(u.move_distance,float(metadata.get("stride_pixels",315))*height/float(metadata.get("native_height",224)),count)
		sprite.texture=frames.get_frame_texture(action,frame)
		pivot=metadata.get("pivot",[216,235]);scale_factor=height/float(metadata.get("native_height",224))
		source_direction=float(metadata.get("source_direction",1));label=C.PEOPLE[u.role].name
	var direction=float(u.get("facing",-1.0 if u.side==1 else 1.0))/source_direction
	body.scale=Vector2(scale_factor*direction,scale_factor)
	body.position=Vector2.ZERO;body.rotation=0;body.modulate=Color.WHITE
	sprite.position=-Vector2(pivot[0],pivot[1])
	if u.side==1:
		if u.state=="move":
			body.position.y=-absf(sin(u.move_distance/42.0))*4
			body.rotation=sin(u.move_distance/65.0)*.018
		elif u.state=="attack":body.position.x=direction*sin(clampf(u.anim/.42,0,1)*PI)*12
		elif u.state=="hit":body.position.x=-direction*maxf(0,1-u.anim/.2)*8
		elif u.hp<=0:
			body.rotation=direction*clampf(u.anim/.5,0,1)*1.3
			body.modulate.a=clampf(1-u.anim/1.7,0,.6)
	queue_redraw()

func _draw() -> void:
	if unit.is_empty() or unit.hp<=0:return
	draw_rect(Rect2(-42,6,84,5),Color("182226"))
	draw_rect(Rect2(-42,6,84*unit.hp/unit.max_hp,5),Color("97c7a7") if unit.side==0 else Color("d68472"))
	draw_string(ThemeDB.fallback_font,Vector2(-42,30),label,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("ece8d7"))
