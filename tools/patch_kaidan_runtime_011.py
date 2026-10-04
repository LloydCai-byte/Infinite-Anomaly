from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def edit(file,fn):
    p=ROOT/file;s=p.read_text(encoding='utf-8');p.write_text(fn(s),encoding='utf-8',newline='\n')
def replace(s,a,b):
    assert a in s,a[:100]
    return s.replace(a,b,1)
def catalog(s):
    line=next(x for x in s.splitlines() if x.startswith('\treturn {"巡游"'))
    s=s.replace(line+'\n','')
    marker='\nstatic func stage_unlocked'
    return replace(s,marker,'\n'+line+'\n'+marker)
edit('scripts/earth/catalog.gd',catalog)
def view(s):
    s=replace(s,'var motion_data: Dictionary={}','var motion_data: Dictionary={}\nconst AnomalyUnit=preload("res://scripts/earth/anomaly_unit.gd")\nvar entity_layer: Node2D\nvar foreground: Node2D\nvar unit_nodes: Dictionary={}\nvar texture_cache: Dictionary={}\n')
    start=s.index('\tfor spirit in game.model.gear_spirits():')
    end=s.index('\nfunc draw_spirit',start)
    effects=s[start:end]
    for method in ['draw_spirit','draw_texture_rect','draw_line','draw_arc','draw_string']:
        if method=='draw_spirit':effects=effects.replace('draw_spirit(pos,','draw_spirit_on(canvas,pos,')
        else:effects=effects.replace(method+'(', 'canvas.'+method+'(')
    s=s[:start]+'\tif not m.has("anomaly"):draw_foreground_on(self,b)\n\nfunc draw_foreground_on(canvas: CanvasItem,b: Dictionary) -> void:\n'+effects+s[end:]
    # Move drawing commands in spirit helper to its supplied drawing CanvasItem.
    start=s.index('func draw_spirit(');end=s.index('\nfunc card_border',start)
    spirit=s[start:end].replace('func draw_spirit(pos:', 'func draw_spirit_on(canvas: CanvasItem,pos:')
    for method in ['draw_colored_polygon','draw_polyline','draw_circle','draw_arc','draw_line']:
        spirit=spirit.replace(method+'(', 'canvas.'+method+'(')
    s=s[:start]+spirit+s[end:]
    s=replace(s,'\tif m.bg=="street":','\tif m.has("anomaly"):\n\t\tfor tile in anomaly_rects(b.stage,b.camera):draw_texture_rect(tile.texture,tile.rect,false)\n\telif m.bg=="street":')
    s=replace(s,'\tvar sorted=b.units.duplicate()','\tvar sorted=[] if m.has("anomaly") else b.units.duplicate()')
    s=replace(s,'\tArt.initialize()','\tentity_layer=Node2D.new();entity_layer.y_sort_enabled=true;add_child(entity_layer)\n\tforeground=Node2D.new();add_child(foreground)\n\tforeground.draw.connect(func():\n\t\tif game!=null and not game.model.s.battle.is_empty() and C.Anomalies.has_stage(game.model.s.battle.stage):draw_foreground_on(foreground,game.model.s.battle))\n\tArt.initialize()')
    s+='''
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
'''
    return s
edit('scripts/earth/battle_view.gd',view)
def main(s):
    s=replace(s,'var stage01_preview = false','var stage01_preview = false\nvar kaidan_preview = false')
    s=replace(s,'transient = "--earth-test" in OS.get_cmdline_user_args() or stage01_preview','kaidan_preview = "--earth-kaidan-preview" in OS.get_cmdline_user_args()\n\ttransient = "--earth-test" in OS.get_cmdline_user_args() or stage01_preview or kaidan_preview')
    s=replace(s,'if stage01_preview: call_deferred("start_stage01_preview")','if stage01_preview: call_deferred("start_stage01_preview")\n\telif kaidan_preview:call_deferred("start_kaidan_preview",301)')
    s=replace(s,'func start_stage01_preview() -> void:', '''func start_kaidan_preview(stage: int=301) -> void:
	model.reset();model.s.intro_done=true
	model.depart(stage);paused=false;battle_speed=1.0;tick_accumulator=0;refresh_clock=0
	navigate("battle")

func preview_anomaly_segment(index: int) -> void:
	if not kaidan_preview or not model.active():return
	var stage=int(model.s.battle.stage)
	start_kaidan_preview(stage)
	var b=model.s.battle
	var tile=C.Anomalies.info(stage).scenes[index]
	var offset=float(tile.world_x)
	for u in b.units:u.x+=offset
	b.encounter=index;model.spawn_encounter()
	b.camera=clampf(offset,0,C.Anomalies.info(stage).world_width-1600)
	battlefield.sync_anomaly_units();battlefield.queue_redraw();refresh_battle()

func start_stage01_preview() -> void:''')
    s=s.replace('0.10 · 异境挑战 / 装备与召唤','0.11 · 怪谈异境 / 装备与召唤')
    s=replace(s,'"异常记录 %d / 300 · 已开放 %d"','"异常记录 %d / 302 · 主线开放 %d"')
    s=replace(s,'portal.destination=Art.texture("battle.street.1" if m.bg=="street" else "battle."+m.bg)','portal.destination=C.Anomalies.background(selected_stage) if m.has("anomaly") else Art.texture("battle.street.1" if m.bg=="street" else "battle."+m.bg)')
    s=s.replace('portal.locked=selected_stage>model.s.max_stage','portal.locked=not C.stage_unlocked(selected_stage,model.s.max_stage)')
    s=replace(s,'C.AREAS[(selected_stage-1)%10][0]','m.name')
    s=replace(s,'\tfor i in range(10):\n\t\tvar stage=mission_page*10+i+1','\tbutton("kaidan_missions","常规异境" if mission_page==30 else "怪谈异境 · 新",Rect2(1258,117,246,40),func():mission_page=0 if mission_page==30 else 30;selected_stage=mission_page*10+1;draw_view())\n\tfor i in range(2 if mission_page==30 else 10):\n\t\tvar stage=mission_page*10+i+1')
    s=s.replace('"锁定" if stage>model.s.max_stage','"锁定" if not C.stage_unlocked(stage,model.s.max_stage)')
    s=replace(s,'[stage,C.AREAS[i][0],label]','[stage,C.mission(stage).name,label]')
    s=s.replace('draw_view(),mission_page==0)','draw_view(),mission_page in [0,30])')
    s=s.replace('draw_view(),mission_page==29)','draw_view(),mission_page>=29)')
    s=replace(s,'text("第 %d / 30 组"%(mission_page+1)','text("怪谈异境 / 2 套" if mission_page==30 else "第 %d / 30 组"%(mission_page+1)')
    s=replace(s,'var unlocked=selected_stage<=model.s.max_stage','var unlocked=C.stage_unlocked(selected_stage,model.s.max_stage)')
    s=replace(s,'if portal_opening or selected_stage>model.s.max_stage:return','if portal_opening or not C.stage_unlocked(selected_stage,model.s.max_stage):return')
    s=replace(s,'\ttext("五人临时动作测试 · 正式战斗服待制作",Rect2(33,114,650,35),20,GOLD)','\ttext(C.Anomalies.info(m.stage).scenes[clampi(model.s.battle.encounter-1,0,4)].name if m.has("anomaly") else "向右推进 · 肃清异常",Rect2(33,114,650,35),20,GOLD)\n\tif kaidan_preview:\n\t\tbutton("preview_hasshaku","八尺大人",Rect2(35,158,160,40),func():start_kaidan_preview(301))\n\t\tbutton("preview_kuchisake","裂口女",Rect2(205,158,160,40),func():start_kaidan_preview(302))\n\t\tfor i in range(5):button("preview_segment_%d"%i,"第 %d 段"%(i+1),Rect2(710+i*135,112,123,40),func():preview_anomaly_segment(i))')
    s=replace(s,'\tvar can_next=r.reason=="victory" and r.stage<C.STAGE_COUNT','\tvar next=C.next_stage(r.stage)\n\tvar can_next=r.reason=="victory" and next>0')
    s=s.replace('"已到本阶段终点" if r.stage==C.STAGE_COUNT','"已到本阶段终点" if next==0')
    s=replace(s,'func():continue_after_result(r.stage+1)','func():continue_after_result(next)')
    s=replace(s,'if stage01_preview:button("preview_restart","重置第一关测试",Rect2(1140,27,365,55),start_stage01_preview)','if stage01_preview:button("preview_restart","重置第一关测试",Rect2(1140,27,365,55),start_stage01_preview)\n\telif kaidan_preview:button("preview_restart","重置怪谈测试",Rect2(1140,27,365,55),func():start_kaidan_preview(r.stage))')
    return s
edit('scripts/earth/main.gd',main)
for f in ['project.godot','tools/build_earth.gd','tools/build_earth.ps1','启动地球篇.cmd']:
    p=ROOT/f;s=p.read_text(encoding='utf-8').replace('0.10.0-earth-loot-portal','0.11.0-earth-kaidan').replace('InfiniteAnomaly-Earth-0.10.0','InfiniteAnomaly-Earth-0.11.0')
    if f.endswith('.gd'):s=s.replace('"import"]','"import","gdshader"]')
    p.write_text(s,encoding='utf-8',newline='\r\n' if f.endswith('.cmd') else '\n')
(ROOT/'启动怪谈测试.cmd').write_text('@echo off\nchcp 65001 >nul\nsetlocal\ncd /d "%~dp0"\ncall "%~dp0启动地球篇.cmd" %* -- --earth-kaidan-preview\nexit /b %errorlevel%\n',encoding='utf-8',newline='\r\n')
print('Runtime, model, menu and 0.11 build entry patched.')
