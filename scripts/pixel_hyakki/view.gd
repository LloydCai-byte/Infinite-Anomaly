extends Node2D
signal return_home_requested
const Model=preload("res://scripts/pixel_hyakki/progression/battle.gd")
const Equipment=preload("res://scripts/pixel_hyakki/progression/gear.gd")
const Hud=preload("res://scripts/pixel_hyakki/battle_hud.gd")
const ElementVfx=preload("res://scripts/pixel_hyakki/element_vfx.gd")
const Travel=preload("res://scripts/pixel_hyakki/travel.gd")
const ChapterHud=preload("res://scripts/pixel_hyakki/chapter_hud.gd")
var travel=Travel.new()
var enemy_arrival=preload("res://scripts/pixel_hyakki/enemy_arrival.gd").new()
var action_skin=preload("res://scripts/pixel_home/portal_skin.gd").new()
var hud_skin=preload("res://scripts/pixel_hyakki/hud_skin.gd").new()
var notices=preload("res://scripts/pixel_hyakki/battle_notices.gd").new()
var ground_shadows=preload("res://scripts/pixel_hyakki/ground_shadows.gd").new()
const ART="res://art/pixel-hyakki-level-20261024/"
const CAMPAIGN="res://assets/pixel_campaign/first_two.json"
const BATTLE_ACTOR_SCALE=2.35
const REAR_ACTOR_SCALE=2.25
var model=Model.new()
var equipment=Equipment.new()
var equipment_ui
var growth_ui
var selected_depth=1
var repeat_run=false
var run_start_level=0
var profile_path="user://pixel-equipment.json"
var observed_level=1
var observed_cards={}
var growth_notice=""
var growth_notice_time=0.0
var save_disabled=false
var profile_locked=false
var look_cache={}
var textures:Dictionary={}
var background_paths:Dictionary={}
var backgrounds=preload("res://scripts/pixel_home/image_cache.gd").new(3)
var roster:Dictionary={}
var font=preload("res://scripts/pixel_home/typography.gd").regular()
var controls:Dictionary={}
var paused=false
var speed=1.0
var auto_next=true
var sound_enabled=true
var screen="battle"
var atlas_actor="fenfen"
var atlas_clip="attack"
var atlas_clock=0.0
var was_paused=false
var visual_clock=0.0
var end_clock=0.0
var prev_phase=""
var sound_cursor=0
var audio_players:Array=[]
var audio_index=0
var streams:Dictionary={}
var ui:Control
var event_audio=true
var content_errors:Array=[]
func is_finale() -> bool:return model.has_method("is_finale") and model.is_finale()
func is_room() -> bool:return model.has_method("room_mode") and model.room_mode()

func texture(path:String)->Texture2D:
	if background_paths.has(path):return backgrounds.get_texture(path)
	if not textures.has(path):
		var image=Image.load_from_file(path)
		if image==null:return null
		textures[path]=ImageTexture.create_from_image(image)
	return textures[path]

func _ready()->void:
	get_window().title="无限异常 · 像素篇"
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	preload("res://scripts/pixel_home/typography.gd").install(get_window())
	roster=JSON.parse_string(FileAccess.get_file_as_string(ART+"sprites/roster.json"))
	var campaign=model.load_content() if model.has_method("load_content") else JSON.parse_string(FileAccess.get_file_as_string(CAMPAIGN))
	assert(campaign is Dictionary and campaign.has("levels"))
	roster.merge(campaign.get("visuals",{}));content_errors=campaign.get("errors",[])
	for error in content_errors:push_warning(error)
	for id in roster:
		if id in campaign.get("visuals",{}):continue
		texture(portrait_path(id))
		for clip in roster[id].clips:texture(clip_path(id,clip))
	model.configure_levels(campaign.levels)
	for level in model.level_defs:
		for scene in level.scenes:
			background_paths[scene.image]=true
			assert(FileAccess.file_exists(scene.image),"场景图片缺失："+scene.image)
			if int(level.id)<=2:assert(texture(scene.image)!=null,"场景图片加载失败："+scene.image)
	for i in range(6):
		var player=AudioStreamPlayer.new();player.volume_db=-12;add_child(player);audio_players.append(player)
	for name in ["shot","heavy","heal","victory","defeat"]:
		var path="res://assets/reboot/audio/"+name+".wav"
		if FileAccess.file_exists(path):streams[name]=AudioStreamWAV.load_from_file(path)
	streams.teleport_out=Travel.sound();streams.teleport_arrive=Travel.sound(true)
	ui=Control.new();ui.size=Vector2(1600,900);ui.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(ui)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--profile=") and not profile_locked:profile_path=arg.trim_prefix("--profile=")
	if not save_disabled:equipment.open_profile(profile_path)
	model.attach(equipment)
	observed_level=equipment.s.level
	for id in equipment.growth.cards:observed_cards[id]=equipment.growth.cards[id].copies
	equipment_ui=preload("res://scripts/pixel_hyakki/equipment_ui.gd").new();add_child(equipment_ui);equipment_ui.setup(self,equipment);equipment_ui.hide()
	growth_ui=preload("res://scripts/pixel_hyakki/progression/ui.gd").new();add_child(growth_ui);growth_ui.setup(self,equipment);growth_ui.hide()
	var fade=preload("res://scripts/pixel_hyakki/fade_screen.gd").new();fade.host=self;fade.z_index=100;add_child(fade)
	for arg in OS.get_cmdline_user_args():
		if arg=="--autostart":begin_level(0)
		if arg=="--mute":sound_enabled=false
		if arg=="--equipment":open_equipment()
		if arg=="--growth":open_growth()
	build_controls();queue_redraw()

func play_sound(id:String)->void:
	if not sound_enabled or not streams.has(id) or not event_audio:return
	var p=audio_players[audio_index%audio_players.size()];audio_index+=1;p.stream=streams[id];p.play();p.stream_paused=paused

func button(text:String,rect:Rect2,fn:Callable,id:String)->Button:
	var b=Button.new();b.text=text;b.position=rect.position;b.size=rect.size;b.add_theme_font_override("font",font);b.add_theme_font_size_override("font_size",18)
	for pair in [["normal","182b3a"],["hover","34485a"],["pressed","0b1622"]]:
		var s=StyleBoxFlat.new();s.bg_color=Color(pair[1]);s.border_color=Color("b49764");s.set_border_width_all(2);b.add_theme_stylebox_override(pair[0],s)
	b.add_theme_color_override("font_color",Color("f2dfb1"));b.pressed.connect(fn);ui.add_child(b);controls[id]=b;return b

func toolbar(id:String,icon_name:String,rect:Rect2,action:Callable,hint:String) -> Button:
	var control=button("",rect,action,id);control.tooltip_text=hint
	for state in ["normal","hover","pressed","disabled","focus"]:control.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	control.add_theme_color_override("font_outline_color",Color("060b12"));control.add_theme_constant_override("outline_size",6)
	control.add_theme_color_override("font_shadow_color",Color.BLACK);control.add_theme_constant_override("shadow_offset_x",3);control.add_theme_constant_override("shadow_offset_y",4)
	if icon_name!="":
		var glyph=preload("res://scripts/pixel_hyakki/hud_icon.gd").new();glyph.image=hud_skin.icon(icon_name);glyph.size=rect.size;control.add_child(glyph)
	return control

func build_controls()->void:
	for child in ui.get_children():ui.remove_child(child);child.queue_free()
	controls={}
	if screen=="atlas":
		var ids=Model.HERO_IDS+Model.ENEMY_IDS
		for i in range(ids.size()):
			var id=ids[i];button((Model.HERO_NAMES+Model.ENEMY_NAMES)[i],Rect2(100+i*140,208,130,40),func():atlas_actor=id;atlas_clock=0,"actor_"+id)
		for i in range(5):
			var clip=["idle","walk","attack","hurt","die"][i]
			button(["待机","行走","攻击","受击","倒下"][i],Rect2(425+i*150,718,140,42),func():atlas_clip=clip;atlas_clock=0,"clip_"+clip)
		button("返回战斗",Rect2(1260,60,230,46),close_atlas,"close_atlas");return
	toolbar("pause","play" if paused else "pause",Rect2(26,110,66,50),toggle_pause,"继续 / 暂停 [空格]")
	var speed_button=toolbar("speed","",Rect2(110,110,66,50),func():speed=2.0 if speed==1 else 3.0 if speed==2 else 1.0;build_controls(),"切换战斗速度")
	speed_button.text="× %.1f"%speed
	var automatic=toolbar("auto_next","auto",Rect2(194,110,66,50),func():auto_next=not auto_next;build_controls(),"自动推进：开" if auto_next else "自动推进：关")
	automatic.modulate=Color.WHITE if auto_next else Color(.55,.63,.72)
	toolbar("equipment","backpack",Rect2(278,110,66,50),open_equipment,"装备背包 [B]")
	if is_finale():controls.equipment.disabled=true
	if has_meta("home_enabled"):toolbar("home","home",Rect2(362,110,66,50),func():return_home_requested.emit(),"返回主神空间 [H]")
	if has_meta("home_enabled") and not is_finale():
		build_room_actions();return
	if repeat_run and model.phase!="ready":button("停止同档循环",Rect2(575,94,270,24),func():repeat_run=false;build_controls(),"stop_repeat").add_theme_font_size_override("font_size",14)
	if model.phase=="ready":
		if is_finale():
			button("继续中枢决战",Rect2(505,512,590,62),func():begin_level(0),"start");return
		elif model.level_index()<2 and not is_room():
			button("第一关 · 百鬼夜行",Rect2(505,512,290,62),func():begin_level(0),"start")
			button("第二关 · 眠兽余温",Rect2(805,512,290,62),func():begin_level(1),"start_level_2")
		else:button("重新挑战 · "+model.level_title(),Rect2(505,512,590,62),func():begin_level(model.level_index()),"start")
		var depth_control=SpinBox.new();depth_control.min_value=1;depth_control.max_value=equipment.unlocked_depth();depth_control.step=1;depth_control.value=selected_depth
		depth_control.position=Vector2(755,602);depth_control.size=Vector2(135,45);depth_control.add_theme_font_size_override("font_size",22)
		depth_control.value_changed.connect(func(value):selected_depth=int(value);queue_redraw())
		ui.add_child(depth_control);controls["depth"]=depth_control
		button("同档循环：开" if repeat_run else "同档循环：关",Rect2(605,673,390,45),func():repeat_run=not repeat_run;build_controls(),"repeat")
	if not travel.active and model.phase=="clear" and (not auto_next or is_finale()):button("重复本房间" if repeat_run and model.is_level_end() else "进入下一房间" if model.is_level_end() else "迎战下一波" if is_room() else "进入下一景",Rect2(650,520,300,58),advance_selected,"next")
	if not travel.active and model.phase in ["victory","defeat"]:button("重试本关 / 选择关卡",Rect2(650,555,300,60),restart,"again")
	if is_finale():
		if controls.has("next"):controls.next.text="进入下一战"
		if controls.has("again"):controls.again.text="返回房间 · 重新整备"
		if model.phase=="checkpoint":button("重试保存",Rect2(650,555,300,60),func():model.save_outcome();build_controls(),"save_retry")
	elif is_room() and model.phase=="checkpoint":
		button("重试保存",Rect2(650,555,300,60),func():model.save_room_outcome();build_controls(),"save_retry")
	if is_room() and model.phase=="checkpoint" and controls.has("home"):controls.home.disabled=true

func begin_level(index:int)->void:
	travel.active=false;notices.clear()
	selected_depth=clampi(selected_depth,1,equipment.unlocked_depth());model.depth=selected_depth;run_start_level=index
	model.reset(index);model.start();sound_cursor=0;end_clock=0;paused=false;prev_phase="";build_controls()
	enemy_arrival.active=false
	if is_room() and model.phase=="fight":enemy_arrival.begin()

signal room_selection_requested
func build_room_actions()->void:
	if travel.active:return
	if model.phase=="ready":
		button("返回异常记录",Rect2(1240,700,300,52),func():room_selection_requested.emit(),"rooms")
	elif model.phase=="checkpoint":
		button("重试保存",Rect2(1240,700,300,52),func():model.save_room_outcome();build_controls(),"save_retry")
		if controls.has("home"):controls.home.disabled=true
	elif model.phase=="clear" and not auto_next:
		button("进入下一房间" if model.is_level_end() else "迎战下一波",Rect2(1240,700,300,52),advance_selected,"next")
	elif model.phase in ["victory","defeat"]:
		button("重新挑战",Rect2(1030,700,235,52),func():begin_level(model.level_index()),"retry")
		button("异常记录",Rect2(1280,700,260,52),func():room_selection_requested.emit(),"rooms")
	for key in ["retry","rooms","next","save_retry"]:
		if controls.has(key):action_skin.style_button(controls[key],"action" if key=="retry" else "range");controls[key].add_theme_font_size_override("font_size",25)

func advance_selected()->void:
	if travel.active:return
	if is_room() and not model.is_level_end():
		if model.advance_stage():end_clock=0;prev_phase=model.phase;enemy_arrival.begin();build_controls()
		return
	var loop_level=run_start_level if repeat_run and model.is_level_end() else -1
	if travel.begin(model,loop_level):
		play_sound("teleport_out")
		backgrounds.get_texture(model.scene_info(model.level_offset(loop_level) if loop_level>=0 else model.stage+1).image)
		end_clock=0;prev_phase=model.phase;build_controls()

func restart()->void:
	travel.active=false
	if is_finale():return_home_requested.emit();return
	begin_level(model.level_index())

func open_growth()->void:
	if is_finale():return
	was_paused=paused;paused=true;screen="growth";ui.hide();growth_ui.show();growth_ui.refresh()

func close_growth()->void:
	growth_ui.hide();ui.show();screen="battle";paused=was_paused
	if model.phase=="ready":model.apply_loadout()
	build_controls()

func open_equipment()->void:
	if is_finale():return
	was_paused=paused;paused=true;screen="equipment";ui.hide();equipment_ui.show();equipment_ui.refresh()
func close_equipment()->void:
	equipment_ui.hide();ui.show();screen="battle";paused=was_paused
	model.looks_live=equipment.equipped_looks()
	if model.phase=="ready":model.apply_loadout()
	equipment.persist();build_controls()

func clip_path(id:String,clip:String) -> String:
	# The original unwarped plate keeps the head, hands and torso connected.
	if clip=="idle" and not roster[id].clips[clip].has("path"):return ART+"sprites/"+id+"/base.png"
	return str(roster[id].clips[clip].get("path",ART+"sprites/"+id+"/"+clip+".png"))

func idle_stretch(clock:float) -> float:return 1.0+.010*(.5-.5*cos(clock*TAU/2.8))
func portrait_path(id:String) -> String:return str(roster[id].get("portrait",ART+"sprites/"+id+"/portrait.png"))

func look_texture(id:String,clip:String,theme:int)->Texture2D:
	var path=clip_path(id,clip)
	if theme<0:return texture(path)
	var key=path+str(theme)
	if look_cache.has(key):return look_cache[key]
	# Runtime clothing palette swap. Keep face and hair pixels unchanged.
	var im=texture(path).get_image();var meta=roster[id];var tint=Color(["528b72","507eaa","ab8750"][theme])
	for y in range(im.get_height()):
		var local_y=y%144
		if local_y<meta.body_top+meta.height*.34:continue
		for x in range(im.get_width()):
			var c=im.get_pixel(x,y)
			if c.a>.5 and c.v>.06 and c.v<.42 and c.r<c.b*1.3 and c.g<c.b*1.3:
				im.set_pixel(x,y,Color(tint.r*(.4+c.v*1.9),tint.g*(.4+c.v*1.9),tint.b*(.4+c.v*1.9),c.a))
	look_cache[key]=ImageTexture.create_from_image(im);return look_cache[key]

func toggle_pause()->void:
	paused=not paused
	for p in audio_players:p.stream_paused=paused
	build_controls()

func open_atlas()->void:
	was_paused=paused;paused=true;screen="atlas";atlas_clock=0;build_controls()

func close_atlas()->void:
	screen="battle";paused=was_paused;build_controls()

func _unhandled_input(event:InputEvent)->void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_H and screen=="battle" and has_meta("home_enabled"):
			return_home_requested.emit();return
		if event.keycode==KEY_B:
			if screen=="equipment":close_equipment()
			elif screen=="battle":open_equipment()
		elif event.keycode==KEY_G:
			if screen=="growth":close_growth()
			elif screen=="battle":open_growth()
		elif event.keycode==KEY_SPACE and screen=="battle":toggle_pause()
		elif event.keycode==KEY_ESCAPE:
			if screen=="equipment":close_equipment()
			elif screen=="growth":close_growth()
			elif screen=="atlas":close_atlas()
			else:toggle_pause()
	elif event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and screen=="battle" and not travel.active and not enemy_arrival.active:
		var point=get_global_mouse_position()
		for u in model.units:
			if u.side==1 and u.hp>0 and Rect2(u.pos-Vector2(80,190),Vector2(160,200)).has_point(point):model.focus=u.uid;break

func _process(delta:float)->void:
	if screen in ["equipment","growth"]:return
	if screen=="atlas":atlas_clock+=delta;queue_redraw();return
	if travel.active:
		if not paused:
			# Readable at every combat speed. Pause still freezes the exact transition frame.
			var dt=minf(delta,.1);var cues=travel.tick(dt);visual_clock+=dt
			if cues.has("switched"):
				if travel.repeat_level>=0:sound_cursor=0
				prev_phase=model.phase;end_clock=0
				if is_room():enemy_arrival.begin()
			if cues.has("failed"):auto_next=false
			if cues.has("arrived"):play_sound("teleport_arrive")
			if cues.has("finished"):build_controls()
		queue_redraw();return
	if enemy_arrival.active:
		if model.phase!="fight":enemy_arrival.active=false
		elif not paused:enemy_arrival.tick(minf(delta,.1))
		queue_redraw();return
	if not paused:
		var dt=minf(delta,.1)*speed;visual_clock+=dt
		growth_notice_time=maxf(0,growth_notice_time-delta)
		notices.tick(minf(delta,.1))
		model.advance(dt)
		if model.phase!="fight":
			for u in model.units:u.anim_time+=dt;u.dead_time+=dt if u.hp<=0 else 0
			for e in model.effects:e.age+=dt
			model.effects=model.effects.filter(func(e):return e.age<e.life)
		if model.phase in ["clear","victory","defeat"]:end_clock+=dt
		if model.phase=="defeat":repeat_run=false
		if repeat_run and end_clock>3.2 and (model.phase=="victory" or (model.phase=="clear" and model.is_level_end())):
			advance_selected()
		elif model.phase=="clear" and auto_next and end_clock>(3.2 if is_finale() else 1.0):advance_selected()
	while sound_cursor<model.event_log.size():
		var e=model.event_log[sound_cursor];sound_cursor+=1
		if e.type=="projectile":play_sound("shot" if e.kind=="bullet" else "heal")
		elif e.type=="damage" and e.kind in ["melee","slash"]:play_sound("heavy")
		elif e.type in ["victory","defeat"]:play_sound(e.type)
	if prev_phase!=model.phase:
		prev_phase=model.phase;end_clock=0;build_controls()
	notices.collect(self)
	var announcements=[]
	if equipment.s.level>observed_level:announcements.append("队伍升至 Lv.%d"%equipment.s.level)
	observed_level=equipment.s.level
	for id in equipment.growth.cards:
		var copies=equipment.growth.cards[id].copies
		if copies>observed_cards.get(id,0):announcements.append(Equipment.Builds.CARD_NAMES[Equipment.Builds.CARD_IDS.find(id)]+" +%d"%(copies-observed_cards.get(id,0)))
		observed_cards[id]=copies
	for announcement in announcements:notices.push(announcement)
	queue_redraw()

func text(value:String,pos:Vector2,size:int=20,color:Color=Color("f4e5c4"))->void:
	draw_string_outline(font,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,3,Color("10151f"))
	draw_string(font,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func box(rect:Rect2,bg:Color=Color("111c2a"),border:Color=Color("9c8258"))->void:
	draw_rect(rect,bg);draw_rect(rect,border,false,2)

func sprite(id:String,clip:String,clock:float,foot:Vector2,scale:float=2.6,alpha:float=1.0)->void:
	var meta=roster[id];var a=meta.clips[clip];var frame=floori(clock*a.fps)
	if clip in ["idle","walk"]:frame=frame%int(a.frames)
	else:frame=mini(frame,int(a.frames)-1)
	var src=Rect2((frame%int(a.columns))*160,(frame/int(a.columns))*144,160,144)
	var dest=Rect2(foot-Vector2(80,128)*scale,Vector2(160,144)*scale)
	if clip=="idle":
		src=Rect2(0,0,160,144)
		var breath=idle_stretch(clock)
		dest=Rect2(foot-Vector2(80,128*breath)*scale,Vector2(160,144*breath)*scale)
	var h=Model.HERO_IDS.find(id);var theme=-1
	if h>=0 and model.looks_live.size()==5:theme=model.looks_live[h]
	draw_texture_rect_region(look_texture(id,clip,theme),dest,src,Color(1,1,1,alpha))

func battle_actor_scale(u:Dictionary)->float:
	# Each actor keeps the theatre-approved size in every scene, including bosses.
	return REAR_ACTOR_SCALE if u.uid in [3,4,5,6] else BATTLE_ACTOR_SCALE

func draw_actor(u:Dictionary,opacity:float=1.0,show_health:bool=true)->void:
	if opacity<=0:return
	if u.hp<=0 and u.dead_time>1.1:return
	var scale=battle_actor_scale(u)
	var alpha=(clampf(1-u.dead_time/1.2,0,1) if u.hp<=0 else 1.0)*opacity
	var p=u.pos.round()
	var clip=u.anim
	if u.hit_time>0 and (model.action.is_empty() or model.action.actor!=u.uid) and u.hp>0:clip="hurt"
	var visual_id=u.get("visual_id",u.id)
	sprite(visual_id,clip,u.anim_time,p,scale,alpha)
	if u.hp<=0 or not show_health:return
	var top=p.y-roster[visual_id].height*scale-20
	Hud.health(self,u,top-5)
	if u.burn>0:
		for i in range(3):pixel_flame(p+Vector2(-20+i*18,-15),12,visual_clock+i)
		text("燃烧",p+Vector2(-20,-roster[visual_id].height*scale-40),16,Color("ffae48"))

func draw_ellipse_shadow(p:Vector2,r:float,color:Color)->void:
	for y in range(-5,6):
		var width=r*sqrt(maxf(0,1-float(y*y)/36));draw_rect(Rect2(p.x-width,p.y+y*2,width*2,2),color)

func pixel_flame(p:Vector2,r:float,clock:float)->void:
	var phase=floori(clock*15)%4
	draw_rect(Rect2(p.x-r*.6,p.y-r,r*1.2,r*1.5),Color("f26425"))
	draw_rect(Rect2(p.x-r*.45,p.y-r*1.5-(phase%2)*3,r*.85,r*1.5),Color("ffac32"))
	draw_rect(Rect2(p.x-r*.16,p.y-r*.7,r*.43,r),Color("fff3a1"))

func draw_projectile(p:Dictionary)->void:
	var f=clampf(p.age/p.duration,0,1);var pos=p.start.lerp(p.end,f).round();var direction=(p.end-p.start).normalized()
	if p.kind=="bullet":
		for i in range(5):draw_rect(Rect2((pos-direction*i*6).round()-Vector2(3,2),Vector2(6,4)),Color(1,.8,.25,1-i*.16))
	elif p.kind in ["fire","fire_burst"]:
		# A compact stepped fireball with a pointed trailing flame.
		for i in range(5,0,-1):
			var tail=(pos-direction*(i*8+8)).round();var r=13-i*1.7
			draw_rect(Rect2(tail-Vector2(r,r),Vector2(r*2,r*2)),Color("e85b25") if i>2 else Color("ff9b2d"))
		draw_rect(Rect2(pos-Vector2(15,9),Vector2(30,18)),Color("ed6025"))
		draw_rect(Rect2(pos-Vector2(9,15),Vector2(18,30)),Color("ed6025"))
		draw_rect(Rect2(pos-Vector2(11,8),Vector2(22,16)),Color("ffb83d"))
		draw_rect(Rect2(pos-Vector2(7,11),Vector2(14,22)),Color("ffb83d"))
		draw_rect(Rect2(pos-Vector2(6,6),Vector2(12,12)),Color("fff3b1"))
	elif p.kind=="pulse":
		draw_rect(Rect2(pos-Vector2(8,8),Vector2(16,16)),Color("68e2f3"));draw_rect(Rect2(pos-Vector2(3,13),Vector2(6,26)),Color("d8ffff"))
	else:
		for i in range(3):draw_line(pos+Vector2(-18,i*7-7),pos+Vector2(18,i*7-7),Color("b8e2df"),3)

func draw_effect(e:Dictionary)->void:
	var t=e.age/e.life;var p=e.pos
	match e.kind:
		"element":ElementVfx.draw(self,e)
		"loot":
			var fade=clampf((1-t)*4,0,1);var rise=sin(minf(1,e.age/.6)*PI)*34
			var rect=Rect2((p+Vector2(-25,-53-rise)).round(),Vector2(50,50))
			var color=Color(equipment.G.COLORS[e.item.quality])
			draw_rect(rect,Color(.035,.025,.015,.85*fade));draw_rect(rect,color,false,2)
			equipment_ui.art.draw(self,e.item,rect.grow(-6),Color(1,1,1,fade))
			text("已入背包",rect.position+Vector2(-8,-8),14,Color(color,fade))
		"number":text(str(e.value),p+Vector2(-15,-t*38),24,Color(e.color,1-t))
		"muzzle":
			draw_rect(Rect2(p-Vector2(6,11),Vector2(23,22)),Color("ffc53f"));draw_rect(Rect2(p-Vector2(2,5),Vector2(26,10)),Color("fff1b5"))
		"cast":pixel_flame(p,12*(1-t),visual_clock)
		"blast":
			for i in range(8):pixel_flame(p+Vector2.from_angle(i*TAU/8)*(10+t*35),14*(1-t),visual_clock+i)
		"slash":
			var off=Vector2(55*(1-t),-45*(1-t));draw_line(p-off,p+off,Color("faecdc"),6);draw_line(p-off+Vector2(5,0),p+off+Vector2(5,0),Color("e95469"),4)
		"impact","spark":
			for i in range(6):
				var q=p+Vector2.from_angle(i*TAU/6)*(5+t*27);draw_rect(Rect2(q.round(),Vector2(5,5)),Color(e.color,1-t))

func portrait(id:String,rect:Rect2,color:Color)->void:
	box(rect,Color("142333"),color)
	draw_texture_rect(texture(portrait_path(id)),rect.grow(-2),false)

func draw_timeline()->void:
	Hud.timeline(self)

func hud_model():return travel.hud_model(model)

func draw_bottom()->void:
	Hud.party(self)

func draw_loot_notice()->void:
	notices.draw(self)

func draw_overlay()->void:
	if travel.active:return
	if model.phase=="fight":return
	if has_meta("home_enabled") and not is_finale():
		if model.phase=="checkpoint":text("成绩未保存 · 请重试",Vector2(1240,675),20,Color("f1cc85"))
		elif model.phase=="victory":text("房间已完成",Vector2(1280,675),22,Color("f1cc85"))
		return
	if model.phase=="clear" and auto_next and not is_finale():
		text("本波已清除，下一波即将到来" if is_room() and not model.is_level_end() else "此处异常已清除，准备传送",Vector2(650,292),21,Color("f1cc85"));return
	if is_finale():
		draw_rect(Rect2(0,280,1600,500),Color(.02,.03,.06,.7));box(Rect2(430,310,740,430))
		var heading="中枢决战完成" if model.phase=="victory" else "小队失利" if model.phase=="defeat" else "决战记录未保存" if model.phase=="checkpoint" else "准备继续" if model.phase=="ready" else "防线已突破"
		text(heading,Vector2(610,378),36,Color("f1cc85"))
		text(model.stage_title(),Vector2(510,435),24)
		text("生命与护盾延续，倒下队员不会自动复活。",Vector2(505,483),22)
		text("本次战败，下次从第一战重新开始。" if model.phase=="defeat" else "返家可保留已突破的防线。" if model.phase!="checkpoint" else "请重试保存，成功后继续。",Vector2(505,660),22)
		return
	draw_rect(Rect2(0,205,1600,598),Color(0.02,.03,.06,.52))
	box(Rect2(490,305,620,455 if model.phase=="ready" else 355),Color(.035,.065,.11,.97),Color("d0a965"))
	var title="选择关卡" if model.phase=="ready" else ("本关完成" if model.is_level_end() else "此景已清") if model.phase=="clear" else "本关完成" if model.phase=="victory" else "小队失利"
	text(title,Vector2(650,378),39,Color("f1cc85"))
	if is_room() and model.phase=="checkpoint":
		text("房间成绩尚未保存",Vector2(590,435),25)
		text("请重试保存，成功后继续。所得保留。",Vector2(535,485),20,Color("e0c89e"));return
	if model.phase=="ready":
		text("每房间十波 · 五人自动战斗" if is_room() else "每关十景 · 五人自动战斗",Vector2(600,427),22)
		text("头像蓄满自动出手，点击敌人指定集火。",Vector2(555,465),18,Color("b6c7d4"))
		text("挑战强度",Vector2(610,633),22)
		text("完成3 / 5 / 10种难度：银 / 金 / 闪光" if is_room() else "已开放 1—%d 档 · 最高通关 %d 档"%[equipment.unlocked_depth(),equipment.best_depth()],Vector2(550,661),17,Color("b6c7d4"))
		text("循环仅重复所选关卡与强度，失利后停止。",Vector2(550,742),17,Color("b6c7d4"))
	elif model.phase=="clear":
		var route=model.level_title()+" → "+model.level_title(model.level_index()+1) if model.is_level_end() else model.stage_title()+" → "+model.stage_title(model.stage+1)
		text(route,Vector2(535,430),22)
		text("即将重复本房间 · 难度保持 %d"%model.depth if repeat_run and model.is_level_end() else ("全队休整，传送至下一房间" if model.is_level_end() else "生命与护盾延续，准备迎战下一波" if is_room() else "小队休整恢复体力"),Vector2(555,472),19,Color("b6c7d4"))
	else:
		text("击败 %d 名敌人 · 出手 %d 次"%[model.kills,model.attacks],Vector2(615,433),22)
		text("累计伤害 %d · 用时 %d 秒"%[model.total_damage,int(model.time)],Vector2(625,476),20,Color("b6c7d4"))
		text("失利已停止循环；所得保留，可降低强度回刷。" if model.phase=="defeat" else "所得已保留"+(" · 即将重复本关" if repeat_run else " · 可挑战更高强度"),Vector2(530,520),18,Color("e0c89e"))

	if model.phase in ["clear","victory"] and model.has_method("campaign_result_text"):
		text(model.campaign_result_text(),Vector2(535,641),20,Color("f1cc85"))

func draw_atlas()->void:
	draw_rect(Rect2(0,0,1600,900),Color("101a29"));text("像素动作图鉴",Vector2(100,100),36,Color("f2d094"))
	text("五位队员与五种妖怪 · 点击切换角色与动作",Vector2(100,146),20,Color("a6bbcc"))
	for x in range(400,1200,32):
		for y in range(280,680,32):draw_rect(Rect2(x,y,32,32),Color("253447") if (x/32+y/32)%2 else Color("1c2a3a"))
	var clip=roster[atlas_actor].clips[atlas_clip];var duration=clip.frames/clip.fps
	var t=fmod(atlas_clock,duration+.35)
	sprite(atlas_actor,atlas_clip,minf(t,duration-.001),Vector2(800,650),5.0)
	text("%s · %d 帧 · %d fps"%[atlas_clip,clip.frames,clip.fps],Vector2(620,805),22)

func draw_background(path:String,offset:float=0) -> void:
	var background=backgrounds.get_texture(path)
	var fitted=background.get_size()*maxf(1600.0/background.get_width(),900.0/background.get_height())
	draw_texture_rect(background,Rect2((Vector2(1600,900)-fitted)*.5+Vector2(offset,0),fitted),false)

func _draw()->void:
	if roster.is_empty():return
	if get_meta("home_backdrop",false) and screen!="battle":return
	if screen=="atlas":draw_atlas();return
	var ground_image=travel.image_path(model) if travel.active else model.scene_info().image
	draw_background(ground_image)
	var ordered=travel.display_units(model) if travel.active else model.units.duplicate();ordered.sort_custom(func(a,b):return a.pos.y<b.pos.y)
	for u in ordered:ground_shadows.draw(self,u,(travel.actor_alpha(u.side) if travel.active else 1.0)*enemy_arrival.alpha(u.side),ground_image)
	if travel.active:travel.draw_ground(self,ordered)
	if not travel.active:enemy_arrival.draw_ground(self)
	for u in ordered:draw_actor(u,(travel.actor_alpha(u.side) if travel.active else 1.0)*enemy_arrival.alpha(u.side),not travel.active and enemy_arrival.alpha(u.side)>=.99)
	if travel.active:travel.draw_columns(self,ordered)
	else:enemy_arrival.draw_columns(self)
	if not travel.active:
		for p in model.projectiles:draw_projectile(p)
		for e in model.effects:draw_effect(e)
	var heading=travel.header(model)
	ChapterHud.draw(self,heading)
	draw_timeline();draw_bottom()
	if model.phase=="ready" and model.level_index()<2 and not is_room():
		var rating=1+10*(selected_depth-1)
		text("本档掉装等级：第一关 %d—%d，第二关 %d—%d（含首领）"%[maxi(1,rating-2),rating+12,maxi(1,rating+3),rating+17],Vector2(34,236),16,Color("f1d49b"))
	if equipment.last_error!="":text(equipment.last_error,Vector2(34,282),18,Color("f5a998"))
	if not travel.active:draw_loot_notice()
	if paused and model.phase=="fight" and not travel.active:text("已暂停",Vector2(740,260),36,Color("f6dda9"))
	draw_overlay()
