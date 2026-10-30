extends RefCounted
## Immutable atlases. Live values and hit targets are drawn by the game.
const ROOT="res://art/feedback-round3-20261028/"
const ICONS={"play":Rect2(235,75,235,260),"pause":Rect2(665,80,210,245),"auto":Rect2(1080,80,270,250),"backpack":Rect2(185,375,300,285),"home":Rect2(610,380,320,280),"plus":Rect2(1090,400,250,250),"minus":Rect2(197,780,280,110),"claw":Rect2(610,690,320,290),"star":Rect2(1090,710,250,250)}
var plate:Texture2D
var icons:Texture2D
var party:Texture2D
var frame=preload("res://scripts/pixel_hyakki/equipment_skin.gd").new()
func _init() -> void:
	plate=ImageTexture.create_from_image(Image.load_from_file(ROOT+"hud-atlas.png"))
	icons=ImageTexture.create_from_image(Image.load_from_file(ROOT+"icons.png"))
	party=ImageTexture.create_from_image(Image.load_from_file(ROOT+"party-reference.png"))
func region(canvas:CanvasItem,texture:Texture2D,target:Rect2,source:Rect2,tint:Color=Color.WHITE) -> void:
	canvas.draw_texture_rect_region(texture,target,source,tint)
func icon(name:String) -> AtlasTexture:
	var result=AtlasTexture.new();result.atlas=icons;result.region=ICONS[name];return result
func icon_draw(canvas:CanvasItem,name:String,target:Rect2,tint:Color=Color.WHITE) -> void:
	var source:Rect2=ICONS[name];var scale=minf(target.size.x/source.size.x,target.size.y/source.size.y)
	var size=(source.size*scale).round()
	region(canvas,icons,Rect2((target.get_center()-size*.5).round(),size),source,tint)
func style(tint:Color=Color.WHITE) -> StyleBoxTexture:
	var atlas=AtlasTexture.new();atlas.atlas=frame.texture;atlas.region=Rect2(1461,748,182,52)
	var result=StyleBoxTexture.new();result.texture=atlas;result.modulate_color=tint
	result.draw_center=false
	for side in range(4):result.set_texture_margin(side,6);result.set_content_margin(side,8)
	return result
func style_button(button:Button) -> void:
	var background=TextureRect.new();var fill=AtlasTexture.new();fill.atlas=frame.texture;fill.region=frame.NAVY
	background.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;background.texture=fill;background.mouse_filter=Control.MOUSE_FILTER_IGNORE
	background.show_behind_parent=true;button.add_child(background);background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.offset_left=3;background.offset_top=3;background.offset_right=-3;background.offset_bottom=-3
	button.add_theme_stylebox_override("normal",style())
	button.add_theme_stylebox_override("hover",style(Color(1.2,1.16,1.04)))
	button.add_theme_stylebox_override("pressed",style(Color(.73,.80,.88)))
	button.add_theme_stylebox_override("disabled",style(Color(.55,.57,.60)))
	button.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
	button.add_theme_color_override("font_color",Color("f5e6bb"))
	button.add_theme_color_override("icon_disabled_color",Color(.50,.50,.50,.65))
	button.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
func panel(canvas:CanvasItem,rect:Rect2,_tint:Color=Color.WHITE) -> void:
	frame.box(canvas,rect,Rect2(1231,222,434,659),frame.NAVY,.8,12)
func lantern(canvas:CanvasItem,rect:Rect2,lit:bool,tint:Color=Color.WHITE) -> void:
	region(canvas,plate,rect,Rect2(67,560 if lit else 790,93,190),tint)
func rail(canvas:CanvasItem,rect:Rect2) -> void:region(canvas,plate,rect,Rect2(78,421,1380,67))
