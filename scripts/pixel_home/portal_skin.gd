extends RefCounted
## Ornament from the approved image; all labels, portraits and values are live.
const PATH="res://art/feedback-portal-polish-20261030/reference.png"
const GOLD=Color("e9be73")
const PAPER=Color("ffe5ac")
var texture:Texture2D
var font=preload("res://scripts/pixel_home/typography.gd").bold()
func _init()->void:
	texture=ImageTexture.create_from_image(Image.load_from_file(PATH))
func region(canvas:CanvasItem,target:Rect2,source:Rect2,tint:Color=Color.WHITE)->void:
	canvas.draw_texture_rect_region(texture,target,source,tint)
func frame(source:Rect2,edge:float=9,tint:Color=Color.WHITE)->StyleBoxTexture:
	var atlas=AtlasTexture.new();atlas.atlas=texture;atlas.region=source
	var result=StyleBoxTexture.new();result.texture=atlas;result.draw_center=false;result.modulate_color=tint
	for side in range(4):result.set_texture_margin(side,edge);result.set_content_margin(side,4)
	return result
func box(canvas:CanvasItem,target:Rect2,source:Rect2,fill:Color=Color("0b1923"),edge:float=9,tint:Color=Color.WHITE)->void:
	canvas.draw_rect(target.grow(-4),fill);canvas.draw_style_box(frame(source,edge,tint),target)
func style_button(button:Button,kind:String="small",selected:bool=false)->void:
	var source=Rect2(1341,249,61,58);var edge=9.0;var fill=Color("0d2030")
	if kind=="action":source=Rect2(1154,790,492,88);edge=24;fill=Color("9b2814")
	elif kind=="range":source=Rect2(43,879,124,43) if selected else Rect2(174,879,124,43);edge=10;fill=Color("e9bd62") if selected else Color("0a1720")
	elif kind=="room":source=Rect2(265,716,195,155) if selected else Rect2(77,724,180,142);edge=9
	var background:Control
	if kind=="action":
		var texture_fill=TextureRect.new();var sample=AtlasTexture.new();sample.atlas=texture;sample.region=Rect2(1245,812,60,42);texture_fill.texture=sample;texture_fill.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;background=texture_fill
	else:
		var color_fill=ColorRect.new();color_fill.color=fill;background=color_fill
	background.mouse_filter=Control.MOUSE_FILTER_IGNORE;background.show_behind_parent=true;button.add_child(background);background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);background.offset_left=13 if kind=="action" else 5;background.offset_top=13 if kind=="action" else 5;background.offset_right=-13 if kind=="action" else -5;background.offset_bottom=-13 if kind=="action" else -5
	button.add_theme_stylebox_override("normal",frame(source,edge))
	button.add_theme_stylebox_override("hover",frame(source,edge,Color(1.2,1.14,1.03)))
	button.add_theme_stylebox_override("pressed",frame(source,edge,Color(.75,.73,.65)))
	button.add_theme_stylebox_override("disabled",frame(source,edge,Color(.5,.55,.6)))
	button.add_theme_stylebox_override("focus",frame(source,edge,Color(1.3,1.2,.9)))
	button.add_theme_color_override("font_color",Color("21160b") if selected and kind=="range" else PAPER)
	button.add_theme_color_override("font_hover_color",Color("21160b") if selected and kind=="range" else Color.WHITE)
	button.add_theme_color_override("font_pressed_color",PAPER)
	button.add_theme_color_override("font_disabled_color",Color("87929a"))
	button.add_theme_font_override("font",font);button.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
