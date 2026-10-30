extends Node
const Home=preload("res://scripts/pixel_home/home.gd")
const Data=preload("res://scripts/pixel_home/demo_data.gd")
var home
var menu:Control
var banner:Button
var font=preload("res://scripts/pixel_home/typography.gd").regular()
var buttons:Dictionary={}
var status:Label
var serial=0
var current=""
var active_profile=""
var data_root=""
var loading=false
func panel() -> StyleBoxFlat:
	var style=StyleBoxFlat.new();style.bg_color=Color("19212b");style.border_color=Color("af9570");style.set_border_width_all(2);style.content_margin_left=20;style.content_margin_right=20;style.content_margin_top=12;style.content_margin_bottom=12;return style
func label(text:String,position:Vector2,size:Vector2,points:int,parent:Node) -> Label:
	var node=Label.new();node.text=text;node.position=position;node.size=size;node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_override("font",font);node.add_theme_font_size_override("font_size",points);node.add_theme_color_override("font_color",Color("dfded6"));parent.add_child(node);return node
func _ready() -> void:
	preload("res://scripts/pixel_home/typography.gd").install(get_window())
	if data_root=="":data_root=OS.get_user_data_dir()+"/flow-demo/"
	data_root=data_root.trim_suffix("/")+"/";DirAccess.make_dir_recursive_absolute(data_root)
	var canvas=CanvasLayer.new();canvas.layer=20;add_child(canvas)
	menu=Control.new();menu.size=Vector2(1600,900);canvas.add_child(menu)
	var bg=ColorRect.new();bg.color=Color("10151f");bg.size=menu.size;menu.add_child(bg)
	label("无限异常 · 流程演示",Vector2(70,35),Vector2(1450,60),36,menu)
	label("独立演示进度，不读取或覆盖正常存档。每次选择会开启一份新的演示。",Vector2(70,110),Vector2(1450,40),23,menu)
	label("星球与Boss沿用已有图片测试功能，正式新场景和怪物尚待制作。2000房间只作规划，没有批量生成。",Vector2(70,155),Vector2(1450,65),21,menu)
	for i in range(Data.ENTRIES.size()):
		var entry=Data.ENTRIES[i];var kind=entry[0];var x=70+(i%2)*750;var y=250+(i/2)*132
		var button=Button.new();button.text=entry[1];button.position=Vector2(x,y);button.size=Vector2(710,64)
		button.add_theme_font_override("font",font);button.add_theme_font_size_override("font_size",25);button.add_theme_stylebox_override("normal",panel());button.pressed.connect(func():select(kind));menu.add_child(button);buttons[kind]=button
		label(entry[2],Vector2(x+5,y+74),Vector2(700,45),20,menu)
	status=label("轩轩负责房间探索；粉粉、高哥、七七、大东老师、老王固定互动。",Vector2(70,820),Vector2(1450,55),21,menu)
	banner=Button.new();banner.position=Vector2(20,205);banner.size=Vector2(535,44);banner.text="演示模式 · 独立进度 · 返回目录 [F2]"
	banner.add_theme_font_override("font",font);banner.add_theme_font_size_override("font_size",19);banner.add_theme_stylebox_override("normal",panel());banner.pressed.connect(show_menu);canvas.add_child(banner);banner.hide()
	get_window().title="无限异常 · 独立流程演示"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--demo-start="):call_deferred("select",arg.trim_prefix("--demo-start="))
		if arg.begins_with("--demo-capture="):call_deferred("capture_smoke",arg.trim_prefix("--demo-capture="))
func write_json(path:String,value:Variant) -> bool:
	var file=FileAccess.open(path,FileAccess.WRITE)
	if file==null:return false
	file.store_string(JSON.stringify(value));file.close();return true
func clear_home() -> void:
	if is_instance_valid(home):
		home.gear.persist();remove_child(home);home.queue_free()
	home=null
func show_menu() -> void:
	if loading:return
	clear_home();current="";menu.show();banner.hide();get_window().title="无限异常 · 独立流程演示"
func select(kind:String) -> void:
	if loading:return
	var snapshot=Data.profile(kind)
	if snapshot.is_empty():status.text="未知演示项目。";return
	loading=true;clear_home();menu.show();banner.hide();serial+=1
	var folder=data_root+"%d-%d-%s/"%[Time.get_ticks_usec(),serial,kind];DirAccess.make_dir_recursive_absolute(folder)
	active_profile=folder+"demo-profile.json";var save=Data.Gear.Save.new(active_profile)
	if not save.save(snapshot):status.text="演示进度无法写入："+save.error;loading=false;return
	var prepared=Home.new();prepared.profile_override=active_profile
	if kind=="finale":
		var pack=Data.pack(true)
		if not Data.Content.validate_pack(pack,true).ok or not write_json(folder+"finale.json",pack) or not write_json(folder+"finale-registry.json",{"schema":1,"pack":folder+"finale.json"}):
			status.text="演示Boss素材校验失败。";prepared.free();loading=false;return
		prepared.finale_registry_path=folder+"finale-registry.json";prepared.allow_test_finale=true
	home=prepared;add_child(home);current=kind;menu.hide();banner.show();loading=false
	await get_tree().process_frame
	if not is_instance_valid(home):return
	get_window().title="无限异常 · 演示模式 · 独立存档 · F2返回目录"
	match kind:
		"planet":
			var pack=Data.pack();var level=pack.level.duplicate(true);level.campaign_id=301;level.enemy_catalog=pack.enemies
			if not Data.Content.validate_pack(pack).ok:show_menu();status.text="演示星球素材校验失败。";return
			var room=Data.Gear.Campaign.Layout.expand([level]).levels[0]
			room.rating_base=1 # Explicitly isolated demonstration strength, not production balance.
			home.battle.roster.merge(pack.visuals);var levels=home.battle.model.level_defs.duplicate(true);levels.append(room);home.battle.model.configure_levels(levels);home.depart(levels.size()-1)
		"finale":home.finale_menu()
		"second":home.open_cycles()
func capture_smoke(path:String) -> void:
	await get_tree().create_timer(1.0).timeout;await RenderingServer.frame_post_draw
	var error=get_viewport().get_texture().get_image().save_png(path)
	print("FLOW_DEMO_CAPTURE ",error_string(error),"; isolated_profile=",active_profile,"; version=",ProjectSettings.get_setting("application/config/version"))
	get_tree().quit(0 if error==OK else 1)
func _input(event:InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode==KEY_F2:
		show_menu();get_viewport().set_input_as_handled()
func _process(_delta:float) -> void:
	if is_instance_valid(home):
		banner.visible=home.mode in ["home","battle","retreat"]
		banner.position=Vector2(1045,80) if home.mode=="home" else Vector2(20,205)
