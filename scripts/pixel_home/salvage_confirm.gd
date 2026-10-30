extends Control
var ui
var plan={}
var controls={}
var completed:Callable
var error:Label
func setup(owner_ui,preview:Dictionary,callback:Callable=Callable())->void:
	ui=owner_ui;plan=preview.duplicate(true);completed=callback;size=Vector2(1600,900);mouse_filter=Control.MOUSE_FILTER_STOP;z_index=300
	label("确认分解",Rect2(540,293,520,48),30)
	label("%d 件装备"%plan.ids.size(),Rect2(540,360,520,55),38)
	label("获得 %d 金币"%plan.gold,Rect2(540,425,520,40),24)
	error=label("",Rect2(535,470,530,38),18)
	add_button("取消",Rect2(535,529,240,52),"cancel",func():queue_free(),false)
	add_button("确认分解 %d 件"%plan.ids.size(),Rect2(800,529,265,52),"confirm",confirm,true)
func label(value:String,rect:Rect2,font_size:int)->Label:
	var node=Label.new();node.text=value;node.position=rect.position;node.size=rect.size;node.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	node.add_theme_font_override("font",ui.font);node.add_theme_font_size_override("font_size",font_size);node.add_theme_color_override("font_color",Color("f1dbb4"));add_child(node);return node
func add_button(value:String,rect:Rect2,key:String,callback:Callable,warm:bool)->void:
	var node=Button.new();node.text=value;node.position=rect.position;node.size=rect.size;node.add_theme_font_override("font",ui.font);node.add_theme_font_size_override("font_size",22)
	var style=StyleBoxFlat.new();style.bg_color=Color("d17b35") if warm else Color("14283b");style.border_color=Color("e8b875");style.set_border_width_all(2)
	node.add_theme_stylebox_override("normal",style);var hover=style.duplicate();hover.bg_color=style.bg_color.lightened(.15);node.add_theme_stylebox_override("hover",hover)
	node.pressed.connect(callback);add_child(node);controls[key]=node
func confirm()->void:
	controls.confirm.disabled=true
	var result=ui.gear.salvage_selection(plan.ids,plan.gold)
	if result.count!=plan.ids.size():error.text=ui.gear.last_error;controls.confirm.disabled=false;return
	ui.selected=0;ui.confirm_salvage=false;ui.message("%d件 · +%d金币"%[result.count,result.gold]);ui.refresh()
	if completed.is_valid():completed.call(result)
	queue_free()
func _draw()->void:
	draw_rect(Rect2(0,0,1600,900),Color(0,0,0,.65));ui.skin.box(self,Rect2(500,263,600,350),Rect2(1236,223,430,661),ui.skin.NAVY,.9,12)
func _input(event:InputEvent)->void:
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:get_viewport().set_input_as_handled();queue_free()
