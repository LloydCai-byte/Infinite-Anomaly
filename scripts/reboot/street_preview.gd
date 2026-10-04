extends Control
const Model = preload("res://scripts/reboot/street_model.gd")
const Art = preload("res://scripts/reboot/art.gd")
const Gait = preload("res://scripts/earth/gait.gd")
var game: Control
var model = Model.new()
var sheets: Dictionary = {}
var tiles: Array = []
var hud: Control
var labels: Dictionary = {}
var bars: Array = []
var controls: Dictionary = {}
var particles: Array = []
var font: Font
var hud_clock = 0.0
var sound_clock = 0.0
var last_result = ""
var ready_for_play = false
var load_index = 0
var loading_label: Label
var tile_origins = [0.0,2172.0,4343.0,6515.0,8687.0]
var paths = [
	"res://assets/character_sequences/male-heavy/sprite_frames.tres",
	"res://assets/character_sequences/pale-hair-katana/sprite_frames.tres",
	"res://assets/character_sequences/bull-spider/sprite_frames.tres",
	"res://assets/reboot/street/01.png", "res://assets/reboot/street/02.png",
	"res://assets/reboot/street/03.png", "res://assets/reboot/street/04.png",
	"res://assets/reboot/street/05.png"
]

func _ready() -> void:
	size = Vector2(1600,900)
	mouse_filter = Control.MOUSE_FILTER_STOP
	font = get_theme_default_font()
	model.invincible = game.model.invincible
	hud = Control.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.size = size
	add_child(hud)
	game.ui.image(hud,Art.ui("dim"),Rect2(0,0,1600,900))
	loading_label = game.ui.text(hud,"正在载入街区与角色…",Rect2(400,395,800,100),30,Color("e4e6d9"),HORIZONTAL_ALIGNMENT_CENTER)
	for path in paths: ResourceLoader.load_threaded_request(path)
	queue_redraw()

func poll_loading() -> void:
	if load_index >= paths.size(): return
	var path: String = paths[load_index]
	var status = ResourceLoader.load_threaded_get_status(path)
	if status==ResourceLoader.THREAD_LOAD_FAILED or status==ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		loading_label.text = "素材加载失败，请返回标题后重试。"
		if not controls.has("exit"):
			controls.exit = game.ui.button(hud,"street_load_exit","返回",Rect2(680,520,240,60),game.close_street_preview,"back")
		return
	if status!=ResourceLoader.THREAD_LOAD_LOADED: return
	var resource = ResourceLoader.load_threaded_get(path)
	if load_index<3: sheets[["male-heavy","pale-hair-katana","bull-spider"][load_index]] = resource
	else: tiles.append(resource)
	load_index += 1
	loading_label.text = "正在载入街区与角色… %d / 8"%load_index
	if load_index==paths.size():
		ready_for_play = true
		build_hud()
		game.set_music("battle")

func build_hud() -> void:
	for child in hud.get_children(): child.queue_free()
	var u = game.ui
	u.image(hud,Art.ui("topbar"),Rect2(0,0,1600,96))
	u.text(hud,"夜行街区",Rect2(52,5,330,44),30)
	u.text(hud,"连续行进  /  沿街遭遇  /  街尾首领",Rect2(54,48,650,27),18,u.MUTED)
	labels.location = u.text(hud,"",Rect2(570,9,640,34),23,u.ACCENT,HORIZONTAL_ALIGNMENT_CENTER)
	labels.progress = u.bar(hud,Rect2(585,57,510,8),0,true)
	labels.count = u.text(hud,"",Rect2(1190,10,360,31),23,u.GOLD,HORIZONTAL_ALIGNMENT_RIGHT)
	labels.performance = u.text(hud,"",Rect2(1185,46,365,28),18,u.MUTED,HORIZONTAL_ALIGNMENT_RIGHT)
	labels.invincible = u.text(hud,"",Rect2(45,110,425,32),20,u.GOLD)
	labels.status = u.text(hud,"",Rect2(450,133,700,47),28,u.INK,HORIZONTAL_ALIGNMENT_CENTER)
	labels.boss = u.text(hud,"",Rect2(546,195,508,34),22,u.GOLD,HORIZONTAL_ALIGNMENT_CENTER)
	labels.boss_bar = u.bar(hud,Rect2(555,236,490,12),100,true)
	u.image(hud,Art.ui("bottom_bar"),Rect2(0,807,1600,93))
	bars.clear()
	for i in range(4):
		var card = u.panel(hud,Rect2(24+i*169,823,161,65),"card")
		u.text(card,"队员 0%d"%(i+1),Rect2(12,1,130,27),18,u.INK)
		labels["hp%d"%i] = u.text(card,"",Rect2(11,27,135,22),15,u.MUTED)
		bars.append(u.bar(card,Rect2(12,53,135,6),100))
	controls.pause = u.button(hud,"street_pause","暂停",Rect2(735,832,130,48),toggle_pause,"pause")
	controls.speed = u.button(hud,"street_speed","1×",Rect2(876,832,110,48),toggle_speed,"speed")
	controls.restart = u.button(hud,"street_restart","重来",Rect2(997,832,140,48),restart,"recycle")
	controls.boss = u.button(hud,"street_boss","直达首领",Rect2(1148,832,198,48),jump_to_boss,"door")
	controls.exit = u.button(hud,"street_exit","返回游戏",Rect2(1357,832,215,48),game.close_street_preview,"back")
	refresh_hud()

func _process(delta: float) -> void:
	if not ready_for_play:
		poll_loading()
		return
	sound_clock += delta
	if not model.paused:
		# Substeps keep attack contacts deterministic at low rendering rates.
		var remaining = minf(delta,0.15)*model.speed
		while remaining>0.00001:
			var step = minf(remaining,1.0/60.0)
			advance(step)
			remaining -= step
	hud_clock += delta
	if hud_clock>=0.1:
		hud_clock = 0.0
		refresh_hud()
	queue_redraw()

func advance(delta: float) -> void:
	model.tick(delta)
	for p in particles: p.life -= delta
	particles = particles.filter(func(p): return p.life>0)
	for event in model.events:
		var p = event.duplicate()
		p.life = 0.72
		particles.append(p)
		if event.type=="hit" and sound_clock>0.13:
			game.play_sound("heavy" if event.side==1 else "blade")
			sound_clock = 0.0
	model.events.clear()
	if last_result!=model.result:
		last_result = model.result
		if last_result!="": game.play_sound("victory" if last_result=="victory" else "defeat")

func refresh_hud() -> void:
	if not ready_for_play: return
	var streets = ["餐馆与便利店","面馆与药店","旧书商店街","影院与河畔","百货店前街"]
	var section = clampi(int((model.camera_x+800)/Model.SCALE/2172),0,4)
	labels.location.text = "%s  ·  %d%%"%[streets[section],roundi(model.camera_x/(Model.LENGTH-1600)*100)]
	labels.progress.value = model.camera_x/(Model.LENGTH-1600)*100
	labels.count.text = "剩余目标  %d / 13"%model.remaining()
	labels.performance.text = "%02d:%02d  ·  %d FPS"%[int(model.elapsed)/60,int(model.elapsed)%60,Engine.get_frames_per_second()]
	labels.invincible.text = "F1 · 全员无敌" if model.invincible else "F1 无敌  ·  空格暂停  ·  R 重来"
	labels.status.text = "街区肃清" if model.result=="victory" else ("小队倒下 · 可重新挑战" if model.result=="defeat" else ("已暂停" if model.paused else ("小队就位" if model.ready_time>0 else "")))
	var boss: Dictionary = model.units.back()
	var show_boss: bool = boss.awake and boss.hp>0 and model.result==""
	labels.boss.text = "牛头巨怪" if show_boss else ""
	labels.boss_bar.visible = show_boss
	labels.boss_bar.value = boss.hp/boss.max_hp*100.0
	for i in range(4):
		var member: Dictionary = model.units[i]
		bars[i].value = member.hp/member.max_hp*100.0
		labels["hp%d"%i].text = "%d / %d"%[ceili(member.hp),int(member.max_hp)] if member.hp>0 else "已倒下"
	controls.pause.text = "继续" if model.paused else "暂停"
	controls.speed.text = "%d×"%int(model.speed)

func toggle_pause() -> void:
	model.paused = not model.paused
	refresh_hud()

func toggle_speed() -> void:
	model.speed = 2.0 if model.speed==1.0 else 1.0
	refresh_hud()

func restart() -> void:
	model.seed_value += 1
	model.restart()
	particles.clear()
	last_result = ""
	refresh_hud()

func jump_to_boss() -> void:
	model.jump_to_boss()
	particles.clear()
	last_result = ""
	refresh_hud()

func handle_key(event: InputEventKey) -> void:
	if not event.pressed or event.echo: return
	if event.keycode==KEY_ESCAPE:
		game.close_street_preview()
	elif event.keycode==KEY_F1:
		model.invincible = not model.invincible
		if ready_for_play: refresh_hud()
	elif ready_for_play:
		match event.keycode:
			KEY_SPACE: toggle_pause()
			KEY_R: restart()

func _exit_tree() -> void:
	# Release outstanding requests even if Escape closed the loading screen early.
	for i in range(load_index,paths.size()):
		if ResourceLoader.load_threaded_get_status(paths[i])!=ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			ResourceLoader.load_threaded_get(paths[i])

func _draw() -> void:
	if not ready_for_play: return
	for i in range(tiles.size()):
		var tile: Texture2D = tiles[i]
		var x: float = tile_origins[i]*Model.SCALE-model.camera_x
		var width = tile.get_width()*Model.SCALE
		if x+width<0 or x>1600: continue
		draw_texture_rect(tile,Rect2(x,0,width,900),false)
	var ordered = model.units.duplicate()
	ordered.sort_custom(func(a,b): return a.y<b.y)
	for unit in ordered:
		if unit.removed: continue
		var x: float = unit.x-model.camera_x
		if x < -430 or x>2030: continue
		var alpha = 1.0
		if unit.hp<=0:
			alpha = clampf(1.0-(unit.anim_time-model.duration(unit,"fall")-2.0)/0.9,0,1)
			if alpha<=0: continue
		var frames: SpriteFrames = sheets[unit.kind]
		var count = frames.get_frame_count(unit.anim)
		var index = int(unit.anim_time*60)
		index = index%count if frames.get_animation_loop(unit.anim) else mini(index,count-1)
		if unit.anim=="move": index=Gait.frame(unit.move_distance,Gait.legacy_cycle(unit.kind,unit.height),count)
		var tex = frames.get_frame_texture(unit.anim,index)
		var factor: float = unit.height/224.0
		var foot = Vector2(x,unit.y)
		draw_texture_rect(Art.ui("shadow"),Rect2(foot-Vector2(unit.height*0.31,7),Vector2(unit.height*0.62,14)),false,Color(1,1,1,alpha*0.85))
		var source_direction = 1.0 if unit.side==0 else -1.0
		var flip: float = unit.get("facing",source_direction)/source_direction
		draw_set_transform(foot,0,Vector2(flip,1))
		var tint = Color(1.3,1.2,1.1,alpha) if unit.flash>0 else Color(1,1,1,alpha)
		draw_texture_rect(tex,Rect2(Vector2(-216,-235)*factor,Vector2(432,248)*factor),false,tint)
		draw_set_transform(Vector2.ZERO)
		if unit.hp>0:
			var health = Rect2(x-34,unit.y-unit.height-10,68,6)
			draw_texture_rect(Art.ui("health_bg"),health,false)
			health.size.x *= unit.hp/unit.max_hp
			draw_texture_rect(Art.ui("health_fill"),health,false,Color.WHITE if unit.side==0 else Color("e5aa92"))
	for p in particles:
		var pos = Vector2(p.x-model.camera_x,p.y-(0.72-p.life)*64)
		var word = "无敌" if p.type=="immune" else str(p.value)
		draw_string_outline(font,pos,word,HORIZONTAL_ALIGNMENT_CENTER,-1,21,4,Color(0.06,0.09,0.12,p.life/0.72))
		draw_string(font,pos,word,HORIZONTAL_ALIGNMENT_CENTER,-1,21,Color(0.94,0.87,0.69,p.life/0.72))
