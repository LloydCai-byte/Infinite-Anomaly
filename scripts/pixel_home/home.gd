extends Node2D
## Xuan is the player; companions have authored routines in their own rooms.
const View=preload("res://scripts/pixel_hyakki/view.gd")
const Gear=preload("res://scripts/pixel_home/gear.gd")
const Intro=preload("res://scripts/pixel_home/intro.gd")
const HomeBattle=preload("res://scripts/pixel_home/battle.gd")
const CampaignUI=preload("res://scripts/pixel_home/campaign_ui.gd")
const CosmosUI=preload("res://scripts/pixel_home/cosmos_ui.gd")
const FinaleBattle=preload("res://scripts/pixel_home/finale_battle.gd")
const CyclesUI=preload("res://scripts/pixel_home/cycles_ui.gd")
const ART="res://art/pixel-home-20261028/"
const XUAN_ART="res://art/xuan-motion-20261029/"
const Life=preload("res://scripts/pixel_home/life.gd")
const Rooms=preload("res://scripts/pixel_home/rooms.gd")
const Ambient=preload("res://scripts/pixel_home/ambient.gd")
const WALK_SPEED=360.0
var backdrop
var current_room="living"
var ROOM:Rect2:
	get:return Rooms.data(current_room).floor
var BLOCKS:Array:
	get:return Rooms.data(current_room).blocks
var OBJECTS:Array:
	get:return Rooms.data(current_room).objects
const NPCS=Life.NPCS
var life=Life.new()
var life_clock=0.0
var battle
var gear
var mode="home"
var player=Vector2(800,740)
var facing=0
var walk_clock=0.0
var moving=false
var path=PackedVector2Array()
var grid=AStarGrid2D.new()
var textures={}
var frames={}
var font=preload("res://scripts/pixel_home/typography.gd").regular()
var ui:Control
var interaction_hint:Label
var dialog:PanelContainer
var dialog_text:RichTextLabel
var dialog_title:Label
var dialog_next:Button
var choices:HBoxContainer
var lines:Array=[]
var line_index=0
var dialog_done:Callable
var overlay_return=false
var departure=false
var original_pause=false
var arrival=0.0
var cinematic=false
var intro
var script_walk=false
var replay_button:Button
var type_clock=0.0
var event_open=false
var startup_return_failed=false
var campaign_ui
var graduation_open=false
var cosmos_ui
var story_open=false
var ending_open=false
var campaign_battle
var finale_registry_path=HomeBattle.Content.FINALE_REGISTRY
var allow_test_finale=false
var cycle_intro_open=false
var cycles_ui
var profile_override=""
var return_to_records=false

func texture(file:String) -> Texture2D:
	if not textures.has(file):
		var im=Image.load_from_file(file if file.begins_with("res://") else ART+file)
		assert(im!=null,"主神空间素材缺失："+file)
		textures[file]=ImageTexture.create_from_image(im)
	return textures[file]

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	preload("res://scripts/pixel_home/typography.gd").install(get_window())
	frames=JSON.parse_string(FileAccess.get_file_as_string(ART+"frames.json"))
	frames.xuan=life.atlas.xuan.frames.map(func(frame):return frame.rect)
	for id in life.atlas:texture(life.texture_path(id))
	battle=View.new();battle.equipment=Gear.new();battle.model=HomeBattle.new();battle.set_meta("home_enabled",true)
	if profile_override!="":battle.profile_path=profile_override;battle.profile_locked=true
	add_child(battle);gear=battle.equipment
	battle.return_home_requested.connect(return_home)
	battle.room_selection_requested.connect(func():return_to_records=true;return_home())
	battle.hide();battle.set_process(false);battle.set_process_unhandled_input(false)
	current_room=gear.home.get("room","living");player=Vector2(gear.home.position[0],gear.home.position[1])
	if blocked(player):player=Rooms.data(current_room).spawn
	backdrop=Ambient.new(self);add_child(backdrop)
	build_grid();build_ui()
	intro=Intro.new(self)
	if not gear.events.ticket.is_empty():startup_return_failed=not gear.complete_trip()
	get_window().title="无限异常 · 主神空间"
	for arg in OS.get_cmdline_user_args():
		if arg=="--home-no-intro":gear.home.intro_done=true;gear.home.intro_version=Intro.VERSION
		if arg.begins_with("--home-capture="):call_deferred("capture_smoke",arg.trim_prefix("--home-capture="))
	if startup_return_failed:call_deferred("retry_startup_return")
	elif gear.home.get("intro_version",0)<Intro.VERSION:call_deferred("start_intro")
	else:call_deferred("present_pending_event")
	queue_redraw()

func retry_startup_return() -> void:
	if not gear.complete_trip():show_choices("返家记录未保存",gear.last_error,[["重试保存",retry_startup_return]]);return
	startup_return_failed=false;close_dialog()
	if gear.home.get("intro_version",0)<Intro.VERSION:start_intro()
	else:present_pending_event()

func capture_smoke(path:String) -> void:
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	var error=get_viewport().get_texture().get_image().save_png(path)
	print("HOME_ENTRY_CAPTURE ",error_string(error),"; controlled_character=xuan; companions=5; version=",ProjectSettings.get_setting("application/config/version"))
	get_tree().quit(0 if error==OK else 1)

func style() -> StyleBoxFlat:
	var s=StyleBoxFlat.new();s.bg_color=Color("151925");s.border_color=Color("9e8970");s.set_border_width_all(2)
	s.content_margin_left=22;s.content_margin_right=22;s.content_margin_top=14;s.content_margin_bottom=14
	return s

func add_button(label:String,action:Callable,parent:Node=null) -> Button:
	if parent==null:parent=ui
	var b=Button.new();b.text=label;b.add_theme_font_override("font",font);b.add_theme_font_size_override("font_size",20)
	b.add_theme_stylebox_override("normal",style());b.pressed.connect(action);parent.add_child(b);return b

func build_ui() -> void:
	ui=Control.new();ui.size=Vector2(1600,900);ui.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(ui)
	replay_button=add_button("跳过演出 [Esc]",finish_intro);replay_button.position=Vector2(1350,18);replay_button.size=Vector2(220,44);replay_button.hide()
	interaction_hint=Label.new();interaction_hint.add_theme_font_override("font",font);interaction_hint.add_theme_font_size_override("font_size",20);interaction_hint.add_theme_color_override("font_color",Color("ffe5a3"));ui.add_child(interaction_hint)
	interaction_hint.add_theme_color_override("font_outline_color",Color("17232f"));interaction_hint.add_theme_constant_override("outline_size",4)
	dialog=PanelContainer.new();dialog.position=Vector2(160,620);dialog.size=Vector2(1280,235);dialog.add_theme_stylebox_override("panel",style());ui.add_child(dialog)
	var column=VBoxContainer.new();column.add_theme_constant_override("separation",8);dialog.add_child(column)
	dialog_title=Label.new();dialog_title.add_theme_font_override("font",font);dialog_title.add_theme_font_size_override("font_size",24);dialog_title.add_theme_color_override("font_color",Color("e9c792"));column.add_child(dialog_title)
	dialog_text=RichTextLabel.new();dialog_text.custom_minimum_size=Vector2(1220,92);dialog_text.fit_content=true;dialog_text.bbcode_enabled=false;dialog_text.add_theme_font_override("normal_font",font);dialog_text.add_theme_font_size_override("normal_font_size",23);column.add_child(dialog_text)
	choices=HBoxContainer.new();choices.add_theme_constant_override("separation",18);column.add_child(choices)
	dialog_next=add_button("继续 [E / 空格]",next_line,choices)
	dialog.hide()

func blocked(p:Vector2) -> bool:
	if not ROOM.has_point(p) and not Rooms.data(current_room).get("passages",[]).any(func(rect):return rect.has_point(p)):return true
	for r in BLOCKS:
		if r.grow(15).has_point(p):return true
	for npc in companions():
		if Rect2(npc.foot-Vector2(24,13),Vector2(48,26)).grow(8).has_point(p):return true
	return false

func companions() -> Array:return life.actors(current_room)

func change_room(destination:String,spawn:Vector2) -> bool:
	if destination not in Rooms.IDS:return false
	var old_room=current_room;var old_position=player
	current_room=destination;player=spawn
	if blocked(player):player=Rooms.data(destination).spawn
	if not remember_position():current_room=old_room;player=old_position;return false
	path=PackedVector2Array();moving=false;build_grid();arrival=.28
	if backdrop!=null:backdrop.sync_room()
	close_dialog();queue_redraw();return true

func room_interaction(id:String) -> void:
	var late=gear.cosmos.unlocked
	match id:
		"sink":show_lines([["水槽边的杯子","五只杯子已经洗净。第六只仍放在轩轩手边，杯底写着每个人归来的日期。"],["轩轩","这一页还没填满。"]])
		"fridge":show_lines([["冰箱上的便签","七七画了一排歪歪扭扭的星球，最后一个旁边写着：回来吃饭。" if late else "高哥写了五个人的口味，最下面又补了一行：别忘了轩轩。"]])
		"stove":show_lines([["灶台上的锅","锅里没有火，盖子却还温着。每次小队回来的那一天，饭总是刚好做熟。"]])
		"mirror":show_lines([["镜子","镜中的房间和身后一样。只有镜子里的门，比真正的门晚了半拍合上。"],["轩轩","我看见了。今天先当作没看见。"]])
		"shower":show_lines([["淋浴间","排水口旁夹着一小片银灰色的砂。它不属于地球上任何一场雨。" if late else "毛巾被整齐地叠成五份。水声停下来后，轩轩又数了一遍。"]])
		"wardrobe":show_lines([["衣柜","备用衣物按名字分好。衣柜最里面挂着一件陌生的制服，口袋里却是小队的合照。"]])
		"plants":show_lines([["窗边的植物","叶子总朝着黑门的方向生长。轩轩每天转一次花盆，第二天又会恢复原样。"]])
		"laundry":show_lines([["晾着的衣服","衣服在微风里轻轻摇晃。再远的征途，也总要留下一个可以晾衣服的家。"]])
		"hall_picture":show_lines([["墙上的合照","六个人站在同一间客厅里。轩轩不记得是谁按下了快门。"]])

func build_grid() -> void:
	grid.region=Rect2i(0,0,100,57);grid.cell_size=Vector2(16,16);grid.offset=Vector2(8,8)
	grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES;grid.update()
	for y in range(57):
		for x in range(100):grid.set_point_solid(Vector2i(x,y),blocked(Vector2(x*16+8,y*16+8)))

func move_to(destination:Vector2) -> void:
	path=PackedVector2Array()
	var a=Vector2i((player-Vector2(8,8))/16)
	var b=Vector2i((destination-Vector2(8,8))/16)
	if not grid.is_in_boundsv(b) or grid.is_point_solid(b):return
	path=grid.get_point_path(a,b)

func nearest() -> Dictionary:
	var best={};var distance=100.0
	for entry in OBJECTS+companions():
		var p=entry.get("point",entry.get("foot",Vector2.ZERO))
		var d=player.distance_to(p)
		if d<distance:best=entry;distance=d
	return best

func remember_position() -> bool:
	var before=gear.snapshot()
	gear.home.position=[player.x,player.y];gear.home.room=current_room
	if not gear.commit_home(before):show_lines([["存档未写入",gear.last_error]]);return false
	return true

func open_overlay(kind:String) -> void:
	if not remember_position():return
	mode="overlay";overlay_return=true;ui.hide();battle.set_meta("home_backdrop",true);battle.show();queue_redraw()
	battle.set_process(true);battle.set_process_unhandled_input(true)
	if kind=="equipment":battle.open_equipment()
	else:battle.open_growth()

func depart(index:int) -> void:
	if gear.cycles.pending_intro!=0:present_pending_event();return
	if gear.ending_pending():present_pending_event();return
	if gear.graduation_pending():present_graduation();return
	if gear.story_waiting():present_pending_event();return
	if index<0 or index>=battle.model.level_defs.size():return
	var entry=battle.model.level_defs[index]
	if not gear.can_enter_level(int(entry.get("campaign_id",entry.get("id",0)))):return
	if not gear.events.pending.is_empty():present_pending_event();return
	if not remember_position():return
	if not gear.begin_trip():show_lines([["暂时无法出战",gear.last_error if gear.last_error!="" else "请先完成本次返家的记录。"]]);return
	close_dialog();mode="battle";departure=true;ui.hide()
	battle.show();battle.set_process(true);battle.set_process_unhandled_input(true);battle.begin_level(index)

func return_home() -> void:
	if mode!="battle":return
	battle.paused=true;interaction_hint.hide();replay_button.hide()
	if battle.model.has_method("save_room_outcome") and not battle.model.save_room_outcome():
		ui.show();show_choices("房间成绩未保存",gear.last_error,[["重试保存并返家",return_home]]);return
	if battle.model.has_method("save_outcome") and not battle.model.save_outcome():
		ui.show();show_choices("决战记录未保存",gear.last_error,[["重试保存并返家",return_home]]);return
	finish_return()

func finish_return() -> void:
	if not gear.complete_trip():
		mode="retreat";battle.paused=true;ui.show()
		show_choices("返家记录未保存",gear.last_error,[["重试保存",finish_return]]);return
	close_dialog();mode="home";battle.hide();battle.set_process(false);battle.set_process_unhandled_input(false)
	if campaign_battle!=null:battle.model=campaign_battle;campaign_battle=null
	battle.repeat_run=false;battle.model.reset();battle.paused=false;ui.show()
	current_room="living";player=Vector2(535,310);build_grid();path=PackedVector2Array();arrival=1.0
	battle.travel.active=false
	departure=false
	remember_position()
	present_pending_event()

func present_pending_event() -> void:
	if cinematic or mode!="home":return
	if gear.cycles.pending_intro!=0:present_cycle_intro();return
	if gear.graduation_pending():present_graduation();return
	if not gear.prepare_story():show_choices("主线记录未保存",gear.last_error,[["重试保存",present_pending_event]]);return
	if not gear.narrative.pending.is_empty():present_story();return
	if gear.ending_pending() and not (gear.campaign.cycle==3 and not gear.events.pending.is_empty()):present_ending();return
	if gear.events.pending.is_empty():return
	var event=Gear.Events.find(gear.events.pending.id);event_open=true
	show_lines([["归来事件 · "+event.title,"门合上了。房间里有些东西，和出发时不一样。"]]+event.lines,finish_pending_event)

func present_story() -> void:
	if story_open:return
	var chapter=Gear.Narrative.find(gear.narrative.pending.id)
	story_open=true;event_open=true
	show_lines([["宇宙主线 · "+chapter.title,"小队归来，房间里的记录又多了一页。"]]+chapter.lines,func():finish_story(chapter.id))

func finish_story(id:String) -> void:
	if not gear.complete_story(id):show_choices("主线记录未保存",gear.last_error,[["重试保存",func():finish_story(id)]]);return
	story_open=false;event_open=false;present_pending_event()

func story_journal() -> void:
	var entries=[]
	for entry in gear.narrative.seen:
		var chapter=Gear.Narrative.find(entry.id)
		entries.append(["第%d周目 · %s"%[entry.cycle,chapter.title],chapter.lines[0][1]])
		entries.append_array(chapter.lines.slice(1))
	for record in gear.cycles.history:
		entries.append(["第%d周目结局"%record.cycle,"已完成的归来记录。"]);entries.append_array(ending_lines(record.cycle))
	show_lines(entries if not entries.is_empty() else [["世界档案","小队已经读过的故事会留在这里。"]])

func present_graduation() -> void:
	if mode!="home" or graduation_open or not gear.graduation_pending():return
	graduation_open=true;event_open=true;arrival=1.0
	show_lines([
		["书柜里的档案","最后一处地球异常的记录亮起。所有日期同时消失，只剩下五个人的名字。"],
		["大东老师","地球上的异常，全都通过了。我们终于可以回到正常的生活了？"],
		["黑门后的声音","你们小队通过了考验。游戏正式开始。"],
		["老王","……正式开始？那么此前死去的人，留下的伤口，都算什么？"],
		["黑门后的声音","地球正在培养能够离开母星作战的人员。这里是训练场，也是等待你们归来的地方。"],
		["轩轩","你一直让我留在这里。因为你知道，他们还会回来，对不对？"],
		["黑门后的声音","星门已接通。第一份外星战报，已经送达。"],
		["粉粉","那就把门打开。我们要亲眼看看，是谁把地球变成了战场。"]
	],finish_graduation)

func finish_graduation() -> void:
	if not gear.finish_graduation():
		show_choices("毕业记录未保存",gear.last_error,[["重试保存",finish_graduation]]);return
	graduation_open=false;event_open=false
	show_lines([["星门开放","地球考验已完成，星球征途已开放。工作间现可进行星际整备：五枚星核与10份星尘已经送达，新的自动技能也已开放。\n房间仍在这里，轩轩会继续等待小队归来。"]],present_pending_event)

func open_campaign() -> void:
	if gear.cycles.pending_intro!=0:present_pending_event();return
	if gear.ending_pending():present_pending_event();return
	if gear.graduation_pending():present_graduation();return
	if gear.story_waiting():present_pending_event();return
	if not gear.events.pending.is_empty():present_pending_event();return
	if not remember_position():return
	close_dialog();path=PackedVector2Array();mode="campaign";ui.hide()
	campaign_ui=CampaignUI.new(self);add_child(campaign_ui)

func close_campaign() -> void:
	if is_instance_valid(campaign_ui):campaign_ui.queue_free()
	campaign_ui=null;mode="home";ui.show()

func open_cosmos() -> void:
	if gear.cycles.pending_intro!=0:present_pending_event();return
	if gear.ending_pending():present_pending_event();return
	if gear.graduation_pending():present_graduation();return
	if gear.story_waiting():present_pending_event();return
	if not gear.events.pending.is_empty():present_pending_event();return
	if not gear.cosmos.unlocked:return
	if not remember_position():return
	close_dialog();path=PackedVector2Array();mode="cosmos";ui.hide();cosmos_ui=CosmosUI.new(self);add_child(cosmos_ui)

func close_cosmos() -> void:
	if is_instance_valid(cosmos_ui):cosmos_ui.queue_free()
	cosmos_ui=null;mode="home";ui.show()

func finish_pending_event() -> void:
	var receipt=gear.claim_event()
	if receipt.is_empty():
		show_choices("事件记录未保存",gear.last_error,[["重试保存与领取",finish_pending_event]]);return
	event_open=false
	show_lines([[receipt.title,receipt.reward+"。\n可在工作间查看支援装置，在座椅旁重读归来记录。"]],present_pending_event)

func support_menu() -> void:
	var options=[];var cfg=Gear.Events.catalog()
	for id in gear.events.supports:
		var support_id=id
		options.append([cfg.supports[id].name+" · Lv.%d"%gear.events.supports[id],func():manage_support(support_id)])
	options.append(["返回",close_dialog])
	var description="可同时装配两种不同的支援装置，对整支五人小队生效。" if gear.campaign.cycle>=2 else "每次可装配一件支援装置，对整支五人小队生效。"
	show_choices("支援整备 · 稳定介质 %d"%gear.events.materials,description+"返家事件可带来新装置和稳定介质，介质用于强化支援。" if not gear.events.supports.is_empty() else "目前没有支援装置。完成出战并返家时，可能收到包裹或发现异常遗物。",options)

func manage_support(id:String) -> void:
	var info=Gear.Events.catalog().supports[id];var rank=gear.events.supports[id];var cost=gear.support_upgrade_cost(id)
	var options=[["卸下" if gear.events.equipped==id else "装配",func():
		if gear.equip_support("" if gear.events.equipped==id else id):manage_support(id)
		else:show_lines([["保存失败",gear.last_error]])]]
	if gear.campaign.cycle>=2:options.append(["卸下副支援" if gear.cycles.secondary_support==id else "装入副支援",func():
		if gear.equip_support("" if gear.cycles.secondary_support==id else id,1):manage_support(id)
		else:show_lines([["暂时无法装配",gear.last_error]],func():manage_support(id))])
	if rank<3:options.append(["强化 · %d介质"%cost,func():
		if gear.upgrade_support(id):manage_support(id)
		else:show_lines([["暂时无法强化","需要%d个稳定介质，当前%d个。"%[cost,gear.events.materials] if gear.last_error=="" else gear.last_error]],support_menu)])
	options.append(["返回支援列表",support_menu])
	show_choices(info.name+" · Lv.%d%s"%[rank," · 主支援" if gear.events.equipped==id else " · 副支援" if gear.cycles.secondary_support==id else ""],info.description+"\n稳定介质：%d"%gear.events.materials,options)

func event_journal() -> void:
	var entries=[]
	for entry in gear.events.history.slice(maxi(0,gear.events.history.size()-10)):
		var event=Gear.Events.find(entry.id)
		entries.append([entry.get("title",event.title),entry.reward+"\n"+event.lines[-1][0]+"："+event.lines[-1][1]])
	show_lines(entries if not entries.is_empty() else [["归来记录","还没有记录。等他们回来，这里会留下属于小队的故事。"]])

func interact() -> void:
	var entry=nearest()
	if entry.is_empty():return
	gear.remember_interaction(entry.id)
	if entry.has("to"):
		change_room(entry.to,entry.spawn);return
	if entry.has("line"):
		show_lines([[entry.name,entry.line],["轩轩","我会记住。你们回来时，我还在这里。"]]);remember_position();return
	match entry.id:
		"exit":open_campaign()
		"relic":work_menu()
		"equipment":open_overlay("equipment")
		"work_archive":story_journal()
		"archive":show_choices("书柜 · 小队档案","翻阅成长、战役和逐步揭开的世界真相。",[["成长档案 [G]",func():open_overlay("growth")],["异常记录 [C]",open_campaign],["世界档案",story_journal],["返回",close_dialog]])
		"tea":show_lines([["轩轩","茶还温着。五个人的杯子，一个也没有少。"],["茶几上的记录","出战、归来、整备。今天也按这个顺序继续。"]])
		"window":show_lines([["轩轩","栏杆外没有城市，也没有地平线。那片黑暗一直在流动，却从没靠近过屋里的灯。"]])
		"chair","bed":event_journal()
		_:room_interaction(entry.id)
	remember_position()

func show_lines(content:Array,on_done:Callable=Callable()) -> void:
	path=PackedVector2Array();lines=content;line_index=0;dialog_done=on_done
	for child in choices.get_children():child.queue_free()
	dialog_next=add_button("继续 [E / 空格]",next_line,choices)
	if cinematic:add_button("跳过演出",finish_intro,choices)
	dialog.show();render_line()

func render_line() -> void:
	if line_index>=lines.size():
		var done=dialog_done;close_dialog()
		if done.is_valid():done.call()
		return
	dialog_title.text=lines[line_index][0];dialog_text.text=lines[line_index][1]
	type_clock=0;dialog_text.visible_characters=0
	if cinematic and intro!=null:intro.on_line(line_index)

func next_line() -> void:
	if lines.is_empty():return
	if dialog_text.visible_characters>=0 and dialog_text.visible_characters<dialog_text.get_total_character_count():
		dialog_text.visible_characters=-1;return
	line_index+=1;render_line()

func show_choices(title:String,description:String,options:Array) -> void:
	path=PackedVector2Array();lines=[];dialog_done=Callable();dialog_title.text=title;dialog_text.text=description;dialog_text.visible_characters=-1
	for child in choices.get_children():child.queue_free()
	for option in options:add_button(option[0],option[1],choices)
	dialog.show()

func close_dialog() -> void:
	dialog.hide();lines=[];dialog_done=Callable()

func start_intro() -> void:
	if mode!="home":return
	if gear.cycles.pending_intro!=0:present_pending_event();return
	if gear.ending_pending():present_pending_event();return
	if gear.graduation_pending():present_graduation();return
	if gear.story_waiting():present_pending_event();return
	if not gear.events.pending.is_empty():present_pending_event();return
	if current_room!="living" and not change_room("living",Vector2(1160,723)):return
	intro.start()

func finish_intro() -> void:
	if intro!=null:intro.stop()
	close_dialog();cinematic=false;arrival=0;gear.home.intro_done=true;gear.home.intro_version=Intro.VERSION
	replay_button.hide();remember_position()
	present_pending_event()

func _unhandled_input(event:InputEvent) -> void:
	if mode not in ["home","retreat"]:return
	if event is InputEventKey and event.pressed and not event.echo:
		if cinematic:
			if event.keycode==KEY_ESCAPE:finish_intro()
			elif event.keycode in [KEY_E,KEY_SPACE,KEY_ENTER] and dialog.visible:next_line()
			return
		if event.keycode in [KEY_E,KEY_SPACE,KEY_ENTER]:
			if dialog.visible:next_line()
			elif mode=="home":interact()
		elif event.keycode==KEY_ESCAPE and dialog.visible and not cinematic and mode=="home" and not event_open:close_dialog()
		elif event.keycode==KEY_B and not dialog.visible:open_overlay("equipment")
		elif event.keycode==KEY_G and not dialog.visible:open_overlay("growth")
		elif event.keycode==KEY_C and not dialog.visible:open_campaign()
		elif event.keycode==KEY_U and not dialog.visible and gear.cosmos.unlocked:open_cosmos()
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and mode=="home" and not dialog.visible and not cinematic:move_to(get_global_mouse_position())

func _process(delta:float) -> void:
	if mode=="home":life_clock+=delta
	if backdrop!=null:backdrop.tick(delta)
	if mode=="battle" and battle.model.has_method("is_finale") and gear.ending_pending() and battle.model.pending_outcome.is_empty():finish_return()
	if mode=="battle" and gear.graduation_pending() and battle.model.phase in ["clear","victory"]:
		finish_return()
	if mode=="overlay" and overlay_return and battle.screen=="battle":
		overlay_return=false;mode="home";battle.set_meta("home_backdrop",false);battle.hide();battle.set_process(false);battle.set_process_unhandled_input(false);ui.show()
	if mode!="home":return
	if return_to_records and not dialog.visible and not cinematic and not event_open:
		return_to_records=false;open_campaign();return
	if intro!=null:intro.tick(delta)
	if dialog.visible and not lines.is_empty() and dialog_text.visible_characters>=0:
		type_clock+=delta;dialog_text.visible_characters=floori(type_clock*34)
	arrival=maxf(0,arrival-delta);moving=false
	if (not dialog.visible and not cinematic) or script_walk:
		var walk_start=player
		var input=Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
		if cinematic:input=Vector2.ZERO
		if input.length_squared()>0:path=PackedVector2Array();input=input.normalized()
		elif path.size()>0:
			if player.distance_to(path[0])<6:path.remove_at(0)
			if path.size()>0:input=(path[0]-player).normalized()
		if input.length_squared()>0:
			var distance=WALK_SPEED*minf(delta,.05)
			if not path.is_empty():distance=minf(distance,player.distance_to(path[0]))
			move_checked(input*distance)
			facing=(2 if input.x>0 else 1) if absf(input.x)>absf(input.y) else (0 if input.y>0 else 3)
		walk_clock+=life.player_stride_seconds(player.distance_to(walk_start),WALK_SPEED)
		if not moving:walk_clock=0.0
		if path.is_empty():script_walk=false
	var target=nearest();interaction_hint.visible=mode=="home" and not dialog.visible and not target.is_empty() and not cinematic
	if interaction_hint.visible:
		interaction_hint.text="[E]  "+target.name
		interaction_hint.position=Vector2(clampf(player.x-80,30,1250),player.y+18)
	queue_redraw()

func move_checked(offset:Vector2) -> void:
	# Small steps protect narrow jambs at the faster walking speed.
	var steps=maxi(1,ceili(offset.length()/6.0));var step=offset/steps
	for i in range(steps):
		if not blocked(player+Vector2(step.x,0)) and step.x!=0:player.x+=step.x;moving=true
		if not blocked(player+Vector2(0,step.y)) and step.y!=0:player.y+=step.y;moving=true

func draw_person(file:String,frame:Array,foot:Vector2,height:float=132) -> void:
	var src=Rect2(frame[0],frame[1],frame[2],frame[3]);var size=src.size*(height/src.size.y)
	draw_texture_rect_region(texture(file),Rect2((foot-Vector2(size.x/2,size.y)).round(),size.round()),src)

func _draw() -> void:
	if mode not in ["home","overlay"]:return
	if intro!=null:draw_set_transform(intro.shake)
	var actors=companions().duplicate();actors.append({"id":"xuan","foot":player})
	actors.sort_custom(func(a,b):return a.foot.y<b.foot.y)
	for actor in actors:
		var foot=actor.foot
		if not actor.get("seated",false):
			var shadow=PackedVector2Array()
			for i in range(16):shadow.append(foot+Vector2(cos(i*TAU/16)*18,sin(i*TAU/16)*5-2))
			draw_colored_polygon(shadow,Color(0.03,.03,.06,.22))
		if actor.id=="xuan":
			life.draw_actor(self,"xuan",life.player_frame(facing,moving,walk_clock),foot)
		else:life.draw_actor(self,actor.id,life.frame_index(actor.id,life_clock),foot)
		if cinematic and intro!=null and actor.get("name","")==intro.speaker:
			draw_rect(Rect2(foot.x-3,foot.y-149,6,6),Color("f2cf89"))
	if intro!=null:
		if intro.door_pulse>0:draw_rect(Rect2(444,94,137,150),Color(0.9,.65,.32,intro.door_pulse*.45),false,4)
		if intro.light_dip>0:draw_rect(Rect2(0,0,1600,900),Color(.02,.025,.055,intro.light_dip))
	draw_set_transform(Vector2.ZERO)
	if arrival>0:draw_rect(Rect2(0,0,1600,900),Color(0.02,.02,.04,clampf(arrival,0,1)))
	if cinematic:
		draw_rect(Rect2(0,0,1600,75),Color("0b0d14"));draw_rect(Rect2(0,865,1600,35),Color("0b0d14"))

func _notification(what:int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST and gear!=null:
		gear.home.position=[player.x,player.y];gear.home.room=current_room;gear.persist()

func finale_content() -> Dictionary:return HomeBattle.Content.load_finale(finale_registry_path,allow_test_finale)

func finale_menu() -> void:
	if mode!="home":return
	if gear.cycles.pending_intro!=0:present_pending_event();return
	if gear.story_waiting() or gear.ending_pending():present_pending_event();return
	var content=finale_content();var options=[]
	var description="突破三道防线，再摧毁归零核心。四战连续进行，生命与护盾延续，倒下的队员不会自动复活。\n战间可返家保留进度；战败则从第一战重新开始。"
	if gear.finale.status=="complete":description="征战中枢已经停止。小队的归来已记入世界档案。"
	elif not gear.finale_eligible():description="完成星球征途，并读完中枢入口的主线记录后，小队才能进入最后的决战。"
	elif not content.available:description+="\n中枢战场尚未开放。"
	else:options.append(["继续第%d战"%(gear.finale.next+1) if gear.finale.status=="active" else "出发 · 连续四战",depart_finale])
	options.append(["返回房间",close_dialog]);show_choices("中枢决战",description,options)

func depart_finale() -> void:
	if mode!="home":return
	if gear.cycles.pending_intro!=0:present_pending_event();return
	if gear.story_waiting() or gear.ending_pending() or not gear.events.pending.is_empty():present_pending_event();return
	var content=finale_content()
	if not content.available or not gear.finale_eligible() or gear.finale.status in ["won","complete"]:return
	for id in content.visuals:
		if battle.roster.has(id) and battle.roster[id]!=content.visuals[id]:show_lines([["中枢暂未开放","角色资料发生冲突，请保留当前进度。"]]);return
	if not remember_position():return
	if not gear.begin_finale():show_lines([["决战记录未保存",gear.last_error]]);return
	campaign_battle=battle.model;var final_model=FinaleBattle.new();final_model.configure_levels([content.level]);final_model.attach(gear)
	battle.roster.merge(content.visuals);battle.model=final_model;battle.repeat_run=false;battle.selected_depth=1
	close_dialog();mode="battle";departure=true;ui.hide();battle.show();battle.set_process(true);battle.set_process_unhandled_input(true);battle.begin_level(0)

func present_ending() -> void:
	if ending_open:return
	ending_open=true;event_open=true;arrival=1.0
	show_lines(ending_lines(gear.campaign.cycle),finish_ending)

func finish_ending() -> void:
	if not gear.finish_ending():show_choices("结局记录未保存",gear.last_error,[["重试保存",finish_ending]]);return
	ending_open=false;event_open=false
	if gear.can_start_cycle():confirm_next_cycle()
	else:present_pending_event()

func ending_lines(cycle:int) -> Array:
	return Gear.Finale.catalog().ending if cycle==1 else Gear.Cycles.catalog()["ending_%d"%cycle]

func work_menu() -> void:
	var options=[["装备背包 [B]",func():open_overlay("equipment")],["支援整备",support_menu]]
	if gear.cosmos.unlocked:options.append(["星际整备 [U]",open_cosmos])
	if gear.finale_eligible():options.append(["中枢决战",finale_menu])
	if gear.campaign.cycle>=3:options.append(["记忆共鸣",resonance_menu])
	if gear.can_start_cycle():options.append(["新的旅程",confirm_next_cycle])
	options.append(["返回",close_dialog])
	show_choices("工作间","整备小队的装备与支援装置。",options)

func resonance_menu() -> void:
	if gear.campaign.cycle<3:return
	var options=[]
	for i in range(3):
		var choice=i;var entry=gear.Cycles.catalog().resonances[i]
		options.append([("✓ " if gear.cycles.resonance==i else "")+entry.name,func():
			if gear.choose_resonance(choice):resonance_menu()
			else:show_lines([["共鸣未保存",gear.last_error]])])
	options.append(["返回",close_dialog])
	show_choices("记忆共鸣",gear.Cycles.catalog().resonances[gear.cycles.resonance].description,options)

func open_cycles() -> void:
	# Compatibility for old demo callers. The spoiler archive has no public page.
	if gear.can_start_cycle():confirm_next_cycle()
	elif gear.campaign.cycle>=3:resonance_menu()
	else:story_journal()

func close_cycles() -> void:
	if is_instance_valid(cycles_ui):cycles_ui.queue_free()
	cycles_ui=null;mode="home";ui.show()

func confirm_next_cycle() -> void:
	if not gear.can_start_cycle():return
	show_choices("进入第%d周目？"%(gear.campaign.cycle+1),"等级和经验回到1级、0经验，战役通关与金标重新开始。全部装备、星核和培养等传承保留，旧旅程会独立保存。",[["保留当前旅程",close_dialog],["确认开启新周目",start_next_cycle]])

func start_next_cycle() -> void:
	if not gear.start_next_cycle():show_choices("新周目未开启",gear.last_error,[["重试保存",start_next_cycle],["返回房间",close_dialog]]);return
	current_room="living";player=Vector2(800,740);build_grid();battle.model.reset();battle.observed_level=gear.s.level;close_dialog();present_pending_event()

func present_cycle_intro() -> void:
	if cycle_intro_open:return
	cycle_intro_open=true;event_open=true
	show_lines(Gear.Cycles.catalog()["opening_%d"%gear.cycles.pending_intro],finish_cycle_intro)

func finish_cycle_intro() -> void:
	if not gear.finish_cycle_intro():show_choices("周目记录未保存",gear.last_error,[["重试保存",finish_cycle_intro]]);return
	cycle_intro_open=false;event_open=false;present_pending_event()
