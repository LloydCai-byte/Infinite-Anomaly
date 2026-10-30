extends Control
var ui
var quality=0
var amount=1
var controls={}
var message=""
var font

func setup(owner_ui)->void:
	ui=owner_ui;font=ui.font;size=Vector2(1600,900);mouse_filter=Control.MOUSE_FILTER_STOP;z_index=200
	rebuild()

func box(color:Color,border:Color)->StyleBoxFlat:
	var style=StyleBoxFlat.new();style.bg_color=color;style.border_color=border;style.set_border_width_all(2);style.set_content_margin_all(10);return style

func text(value:String,position:Vector2,size_value:int=22,color:Color=Color("f0e8d4"))->void:
	var label=Label.new();label.text=value;label.position=position;label.add_theme_font_override("font",font);label.add_theme_font_size_override("font_size",size_value);label.add_theme_color_override("font_color",color);add_child(label)

func button(value:String,rect:Rect2,key:String,callback:Callable,disabled:bool=false)->void:
	var b=Button.new();b.text=value;b.position=rect.position;b.size=rect.size;b.disabled=disabled;b.add_theme_font_override("font",font);b.add_theme_font_size_override("font_size",22)
	b.add_theme_stylebox_override("normal",box(Color("bc612d"),Color("e6b378")));b.add_theme_stylebox_override("hover",box(Color("d67f40"),Color("ffe0aa")));b.add_theme_stylebox_override("pressed",box(Color("7f442a"),Color("e6b378")))
	b.pressed.connect(callback);add_child(b);controls[key]=b

func choice(values:Array,index:int,position:Vector2,key:String,callback:Callable)->void:
	var options=OptionButton.new();options.position=position;options.size=Vector2(365,48)
	for value in values:options.add_item(value)
	options.select(index);options.add_theme_font_override("font",font);options.add_theme_font_size_override("font_size",22)
	options.add_theme_stylebox_override("normal",box(Color("21354b"),Color("647d8c")));options.item_selected.connect(callback);add_child(options);controls[key]=options

func close()->void:
	ui.refresh();queue_free()

func apply(all_items:bool)->void:
	var plan=ui.gear.salvage_plan(quality,-1 if all_items else amount)
	if plan.ids.is_empty():return
	var dialog=preload("res://scripts/pixel_home/salvage_confirm.gd").new();ui.add_child(dialog)
	dialog.setup(ui,plan,func(result):message="%d件 · +%d金币"%[result.count,result.gold];rebuild())

func rebuild()->void:
	for child in get_children():remove_child(child);child.queue_free()
	controls={}
	text("装备分解",Vector2(462,236),32,Color("edbd83"))
	button("×",Rect2(1094,226,48,48),"close",close)
	text("品质",Vector2(466,320));choice(ui.G.QUALITY,quality,Vector2(684,310),"quality",func(index):quality=index;amount=1;rebuild())
	var plan=ui.gear.salvage_plan(quality);amount=clampi(amount,1,maxi(1,plan.ids.size()))
	text("数量",Vector2(466,390))
	var count=SpinBox.new();count.position=Vector2(684,380);count.size=Vector2(180,48);count.min_value=1;count.max_value=maxi(1,plan.ids.size());count.value=amount;count.add_theme_font_override("font",font);count.add_theme_font_size_override("font_size",22)
	count.get_line_edit().add_theme_font_override("font",font);count.get_line_edit().add_theme_font_size_override("font_size",22)
	count.value_changed.connect(func(value):amount=int(value);update_count());add_child(count);controls["quantity"]=count
	text("可分解 %d 件"%plan.ids.size(),Vector2(886,390),20)
	button("",Rect2(464,456,320,56),"batch",func():apply(false),plan.ids.is_empty())
	button("一键分解 %d件 · +%d"%[plan.ids.size(),plan.gold],Rect2(804,456,334,56),"all",func():apply(true),plan.ids.is_empty())
	text("自动分解新掉落",Vector2(464,565),24,Color("edbd83"))
	var choices=["关闭"]
	for name in ui.G.QUALITY:choices.append(name+"及以下")
	choice(choices,ui.gear.salvage_rules.auto_max_quality+1,Vector2(772,554),"auto",func(index):
		if ui.gear.set_auto_salvage(index-1):message="已保存"
		else:message="保存失败："+ui.gear.last_error
		rebuild())
	text(message,Vector2(464,642),20,Color("f0cb84"));update_count();queue_redraw()

func update_count()->void:
	var plan=ui.gear.salvage_plan(quality,amount)
	controls.batch.text="分解 %d件 · +%d金币"%[plan.ids.size(),plan.gold]

func _draw()->void:
	draw_rect(Rect2(0,0,1600,900),Color(0,0,0,.68))
	draw_rect(Rect2(432,210,736,490),Color("111e30"));draw_rect(Rect2(432,210,736,490),Color("d3a36f"),false,3)
	draw_line(Vector2(460,535),Vector2(1140,535),Color("526779"),2)

func _input(event:InputEvent)->void:
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		get_viewport().set_input_as_handled();close()
