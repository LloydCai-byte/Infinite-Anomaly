extends Control
const Campaign=preload("res://scripts/pixel_home/campaign.gd")
const Rules=preload("res://scripts/pixel_hyakki/progression/rules.gd")
const ImageCache=preload("res://scripts/pixel_home/image_cache.gd")
const PortalSkin=preload("res://scripts/pixel_home/portal_skin.gd")
const RoomCovers=preload("res://scripts/pixel_home/room_covers.gd")
const ART="res://art/feedback-portal-polish-20261030/plate.png"
const SCALE=Vector2(1600.0/1672.0,900.0/941.0)
const CARD_WIDTH=190.0
const GROUP_WIDTH=130.0
var home
var skin=PortalSkin.new()
var selected=0
var entries:Array=[]
var all_entries:Array=[]
var indices={}
var cards=[]
var card_ids=[]
var seen=[]
var frontier=0
var depth_value=1
var detail:Label
var title:Label
var status:Label
var reward:Label
var depth_label:Label
var index_label:Label
var depth_count:Label
var minus:Button
var plus:Button
var start:Button
var scroll:ScrollContainer
var grid:Control
var group_scroll:ScrollContainer
var group_grid:Control
var groups=[]
var group_buttons=[]
var group_ids=[]
var current_group=0
var visible_first=-1
var visible_group_first=-1
var thumbnails=ImageCache.new(16,400)
var portals=ImageCache.new(3,1024)
var covers=RoomCovers.new()
var background:Texture2D
var active_card_ids=[]
var controls={}
var clock=0.0
var equipment_art=preload("res://scripts/pixel_hyakki/equipment_art.gd").new()
var equipment_icon_bases=[]
var drag_scroll:ScrollContainer
var drag_origin=Vector2.ZERO
var drag_start=0.0
var dragging=false
var suppress_click=false
var collection_layer:Control
func _init(owner_home)->void:home=owner_home
func r(x:float,y:float,w:float,h:float)->Rect2:return Rect2(Vector2(x,y)*SCALE,Vector2(w,h)*SCALE)
func label(value:String,rect:Rect2,point_size:int=20,color:Color=PortalSkin.PAPER,heading:bool=false)->Label:
	var node=Label.new();node.text=value;node.position=rect.position;node.size=rect.size
	node.add_theme_font_override("font",skin.font if heading else home.font);node.add_theme_font_size_override("font_size",point_size);node.add_theme_color_override("font_color",color)
	node.add_theme_color_override("font_shadow_color",Color("050a13"));node.add_theme_constant_override("shadow_offset_y",2)
	node.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	node.mouse_filter=MOUSE_FILTER_IGNORE;add_child(node);return node
func button(value:String,rect:Rect2,action:Callable,key:String="",kind:String="small")->Button:
	var node=Button.new();node.text=value;node.position=rect.position;node.size=rect.size;node.add_theme_font_size_override("font_size",24);add_child(node);skin.style_button(node,kind)
	if value in ["+","−","‹","›"]:
		node.text="";var glyph=preload("res://scripts/pixel_home/portal_symbol.gd").new();glyph.symbol=value;node.add_child(glyph)
	node.pressed.connect(action)
	if key!="":controls[key]=node
	return node
func make_scroll(rect:Rect2)->ScrollContainer:
	var node=ScrollContainer.new();node.position=rect.position;node.size=rect.size;node.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;node.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER
	node.mouse_filter=MOUSE_FILTER_STOP;add_child(node);return node
func _ready()->void:
	size=Vector2(1600,900);mouse_filter=MOUSE_FILTER_STOP;texture_filter=TEXTURE_FILTER_NEAREST
	background=ImageTexture.create_from_image(Image.load_from_file(ART))
	for type in ["weapon","head","armor"]:
		for i in range(home.gear.G.bases.size()):
			if home.gear.G.bases[i].type==type:equipment_icon_bases.append(i);break
	var back=button("",r(1581,16,68,62),home.close_campaign,"back")
	var icon=AtlasTexture.new();icon.atlas=skin.texture;icon.region=Rect2(1599,29,36,36);back.icon=icon;back.expand_icon=true;back.add_theme_constant_override("icon_max_width",34)
	back.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER;back.vertical_icon_alignment=VERTICAL_ALIGNMENT_CENTER
	index_label=label("",r(1316,73,170,60),32,PortalSkin.PAPER,true);index_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	title=label("",Rect2());title.hide()
	detail=label("",Rect2());detail.hide()
	status=label("",r(1164,149,474,40),22,Color("f26045"));status.clip_text=true;status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label("挑战难度",r(1210,251,155,44),25,PortalSkin.PAPER,true)
	minus=button("−",r(1342,248,59,58),func():set_depth(depth_value-1),"minus")
	plus=button("+",r(1570,248,61,58),func():set_depth(depth_value+1),"plus")
	depth_label=label("",r(1427,245,121,63),36,PortalSkin.PAPER,true);depth_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	depth_count=label("",r(1570,313,65,34),20)
	label("可能获得",r(1211,367,220,43),28,PortalSkin.PAPER,true)
	reward=label("",Rect2());reward.hide()
	label("异常卡牌",r(1210,581,230,43),28,PortalSkin.PAPER,true)
	collection_layer=Control.new();collection_layer.mouse_filter=MOUSE_FILTER_IGNORE;add_child(collection_layer)
	start=button("消灭异常",r(1154,790,492,88),launch,"launch","action");start.add_theme_font_size_override("font_size",40)
	button("‹",r(20,749,47,90),func():scroll.scroll_horizontal-=CARD_WIDTH*3,"previous")
	button("›",r(1069,749,43,90),func():scroll.scroll_horizontal+=CARD_WIDTH*3,"next")
	scroll=make_scroll(r(77,715,981,158));grid=Control.new();grid.custom_minimum_size=Vector2(0,150);scroll.add_child(grid)
	scroll.get_h_scroll_bar().value_changed.connect(func(_value):refresh_visible_cards())
	group_scroll=make_scroll(r(43,879,1024,45));group_grid=Control.new();group_scroll.add_child(group_grid)
	group_scroll.get_h_scroll_bar().value_changed.connect(func(_value):refresh_group_buttons())
	refresh()
func content_index(id:int)->int:return int(indices.get(id,-1))
func next_mission()->int:
	var begin=1001 if home.gear.campaign.phase=="cosmos" else 1
	for id in range(begin,begin+1000):
		if home.gear.campaign.levels.get(Campaign.key(id),{}).get("clears",0)==0:return id if indices.has(id) else 0
	return 0
func available(id:int)->bool:
	return home.gear.can_enter_level(id) and (id==frontier or id in seen or home.gear.campaign.levels.has(Campaign.key(id)))
func group_of(id:int)->int:return maxi(0,int((id-1)/50))
func group_label(group:int)->String:return "%d~%d"%[1 if group==0 else group*50,(group+1)*50]
func refresh()->void:
	indices.clear();all_entries=[]
	for i in range(home.battle.model.level_defs.size()):
		var level=home.battle.model.level_defs[i];var id=int(level.get("campaign_id",level.id));indices[id]=i
		if id<=1000 or home.gear.campaign.phase=="cosmos":all_entries.append(id)
	all_entries.sort();seen=home.gear.encountered_levels(home.battle.model.level_defs);frontier=next_mission()
	var reached=1
	for id in seen:
		if id<=1000 or home.gear.campaign.phase=="cosmos":reached=maxi(reached,id)
	for key in home.gear.campaign.levels:
		var id=int(str(key).trim_prefix("R"))
		if id<=1000 or home.gear.campaign.phase=="cosmos":reached=maxi(reached,id)
	groups=range(group_of(reached)+1)
	if home.gear.campaign.phase=="cosmos" and not 20 in groups:groups=range(21)
	var remembered=int(home.get_meta("selected_room",0))
	var target=remembered if remembered in all_entries and group_of(remembered) in groups else frontier if frontier>0 and group_of(frontier) in groups else int(all_entries[0]) if not all_entries.is_empty() else 0
	current_group=group_of(target);set_depth(home.battle.selected_depth);set_group(current_group,false)
	if target>0:choose(target)
	call_deferred("reveal_selection")
func set_group(group:int,select_first:bool=true)->void:
	if not group in groups:return
	current_group=group;entries=all_entries.filter(func(id):return group_of(id)==group)
	grid.custom_minimum_size=Vector2(entries.size()*CARD_WIDTH,150);scroll.scroll_horizontal=0;visible_first=-1
	group_grid.custom_minimum_size=Vector2(groups.size()*GROUP_WIDTH+maxf(0,group_scroll.size.x-GROUP_WIDTH),group_scroll.size.y)
	visible_group_first=-1
	if select_first:
		if entries.is_empty():selected=0;title.text="尚无场景";index_label.text="";start.disabled=true;active_card_ids=[]
		else:choose(int(entries[0]))
	call_deferred("align_group")
	refresh_visible_cards();refresh_group_buttons();queue_redraw()
func align_group()->void:
	group_scroll.scroll_horizontal=groups.find(current_group)*GROUP_WIDTH
	refresh_group_buttons()
func reveal_selection()->void:
	var index=entries.find(selected)
	if index>=0:scroll.scroll_horizontal=maxi(0,index-2)*CARD_WIDTH
	refresh_visible_cards()
func clear_children(node:Node)->void:
	for child in node.get_children():node.remove_child(child);child.queue_free()
func refresh_group_buttons()->void:
	var first=maxi(0,int(group_scroll.scroll_horizontal/GROUP_WIDTH)-1)
	if first==visible_group_first:return
	visible_group_first=first;clear_children(group_grid);group_buttons=[];group_ids=[]
	for index in range(first,mini(groups.size(),first+10)):
		var group=int(groups[index]);var node=Button.new();node.text=group_label(group);node.position=Vector2(index*GROUP_WIDTH,0);node.size=Vector2(GROUP_WIDTH-6,40)
		node.add_theme_font_override("font",home.font);node.add_theme_font_size_override("font_size",18);skin.style_button(node,"range",group==current_group)
		node.pressed.connect(func():if not suppress_click:set_group(group))
		group_grid.add_child(node);group_buttons.append(node);group_ids.append(group)
func refresh_visible_cards()->void:
	var first=maxi(0,int(scroll.scroll_horizontal/CARD_WIDTH)-1)
	if first==visible_first:return
	visible_first=first;clear_children(grid);cards=[];card_ids=[]
	for index in range(first,mini(entries.size(),first+8)):
		var id=int(entries[index]);var level=home.battle.model.level_defs[content_index(id)]
		var card=Button.new();card.position=Vector2(index*CARD_WIDTH,5);card.size=Vector2(180,141);skin.style_button(card,"room",id==selected)
		card.pressed.connect(func():if not suppress_click:choose(id));grid.add_child(card);cards.append(card);card_ids.append(id)
		var picture=TextureRect.new();picture.name="FirstScene";picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.position=Vector2(6,8);picture.size=Vector2(168,94);picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;picture.mouse_filter=MOUSE_FILTER_IGNORE
		var cover_path=covers.path_for(id,level.scenes[0].image,"landscape")
		picture.texture=thumbnails.get_texture(cover_path);picture.set_meta("source",cover_path);card.add_child(picture)
		if not available(id):picture.modulate=Color(.38,.43,.49)
		var caption=Label.new();caption.name="RoomNumber";caption.text="%03d"%id;caption.position=Vector2(7,105);caption.size=Vector2(166,29);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;caption.clip_text=true;caption.add_theme_font_override("font",home.font);caption.add_theme_font_size_override("font_size",18);caption.add_theme_color_override("font_color",PortalSkin.PAPER);caption.mouse_filter=MOUSE_FILTER_IGNORE;card.add_child(caption)
		var badge=Label.new();badge.name="Badge";badge.position=Vector2(8,9);badge.add_theme_font_override("font",home.font);badge.add_theme_font_size_override("font_size",15);badge.add_theme_constant_override("outline_size",4);badge.add_theme_color_override("font_outline_color",Color.BLACK);badge.mouse_filter=MOUSE_FILTER_IGNORE
		var mark=Campaign.badge(home.gear.campaign.levels.get(Campaign.key(id),{}));badge.text=Campaign.badge_title(mark) if mark in ["silver","gold","shimmer"] else "未抵达" if not available(id) else "";badge.set_meta("shimmer",mark=="shimmer");badge.add_theme_color_override("font_color",badge_color(mark));card.add_child(badge)
	update_card_selection();queue_redraw()
func badge_color(mark:String)->Color:return Color("c3d4e2") if mark=="silver" else Color("ffcf67") if mark=="gold" else Color("c5f3ff") if mark=="shimmer" else Color("b6a78c")
func update_card_selection()->void:
	for i in range(cards.size()):
		var source=Rect2(265,716,195,155) if card_ids[i]==selected else Rect2(77,724,180,142)
		cards[i].add_theme_stylebox_override("normal",skin.frame(source,9))
func set_depth(value:int)->void:
	depth_value=clampi(value,1,10);home.battle.selected_depth=depth_value;depth_label.text="%02d"%depth_value;depth_count.text="%d / 10"%depth_value;minus.disabled=depth_value<=1;plus.disabled=depth_value>=10
	if selected>0:update_rewards()
	queue_redraw()
func choose(id:int)->void:
	if content_index(id)<0 or not group_of(id) in groups:return
	if group_of(id)!=current_group:set_group(group_of(id),false)
	selected=id;home.set_meta("selected_room",id);var level=home.battle.model.level_defs[content_index(id)];var record=home.gear.campaign.levels.get(Campaign.key(id),{})
	index_label.text="%03d"%id;title.text=""
	status.text=(Campaign.badge_title(Campaign.badge(record))+"  %d / 10"%Campaign.difficulty_count(record)) if not record.is_empty() else "未通关" if available(id) else "尚未抵达"
	status.add_theme_color_override("font_color",badge_color(Campaign.badge(record)) if not record.is_empty() else Color("ed654b"));status.set_meta("shimmer",Campaign.badge(record)=="shimmer")
	detail.text="";start.disabled=not available(id);start.text="消灭异常" if available(id) else "尚未抵达"
	update_rewards();update_card_selection();queue_redraw()
func update_rewards()->void:
	var index=content_index(selected)
	if index<0:return
	var level=home.battle.model.level_defs[index]
	reward.text=""
	active_card_ids=[]
	for id in level.scenes[0].get("enemies",["tengu","umbrella","oni","kappa","wheel"]):
		if id in Rules.CARD_IDS and id not in active_card_ids:active_card_ids.append(id)
	var source=level.get("source_world_key","")
	if level.get("source_image_index",-1)==9 and source in Rules.CARD_IDS and source not in active_card_ids:active_card_ids.append(source)
	clear_children(collection_layer)
	for i in range(active_card_ids.size()):
		var id=active_card_ids[i];var card=Control.new();card.position=card_rect(i).position;card.size=card_rect(i).size;card.mouse_filter=MOUSE_FILTER_STOP
		card.tooltip_text=Rules.CARD_NAMES[Rules.CARD_IDS.find(id)]+"\n"+Rules.card_description(id,maxi(1,Rules.card_rank(home.gear.growth.cards.get(id,{}).get("copies",0))));collection_layer.add_child(card)
	queue_redraw()
func card_rect(i:int)->Rect2:
	var width=minf(94,486.0/maxi(1,active_card_ids.size())-8)
	return r(1158+i*(width+8),632,width,133)
func launch()->void:
	var index=content_index(selected)
	if index<0 or not available(selected):return
	home.battle.selected_depth=depth_value;home.close_campaign();home.depart(index)
func launch_new()->void:
	if frontier<=0:return
	var index=content_index(frontier)
	if index>=0:home.close_campaign();home.depart(index)
func select_relative(direction:int)->void:
	var index=entries.find(selected)+direction
	if index>=0 and index<entries.size():choose(entries[index]);reveal_selection()
func draw_scene()->void:
	var index=content_index(selected)
	if index<0:return
	var path=covers.path_for(selected,home.battle.model.level_defs[index].scenes[0].image,"portrait")
	var texture=portals.get_texture(path)
	if texture==null:return
	var target=r(529,105,286,481);var source=RoomCovers.source_rect(texture.get_size(),target.size)
	draw_texture_rect_region(texture,target,source,Color.WHITE if available(selected) else Color(.48,.53,.61))
func _draw()->void:
	if background==null:return
	draw_texture_rect(background,Rect2(0,0,1600,900),false);draw_scene()
	skin.box(self,r(1316,73,170,60),Rect2(1165,73,108,56),Color("241d12"),15)
	skin.box(self,r(1427,245,121,63),Rect2(1426,244,123,64),Color("241d12"),18)
	skin.region(self,r(1162,251,31,44),Rect2(1163,249,29,46))
	skin.region(self,r(1158,366,48,36),Rect2(1158,365,49,37))
	skin.region(self,r(1158,581,42,39),Rect2(1157,581,43,40))
	for y in [391,606]:skin.region(self,r(1380,y,260,10),Rect2(1384,387,258,12))
	for i in range(10):
		var center=Vector2(1196+i*35,327)*SCALE;var polygon=PackedVector2Array([center+Vector2(0,-8),center+Vector2(8,0),center+Vector2(0,8),center+Vector2(-8,0)])
		draw_colored_polygon(polygon,Color("ffc66f") if i==depth_value-1 else Color("5e5d57"));polygon.append(polygon[0]);draw_polyline(polygon,Color("c8ab79"),1)
	for i in range(5):
		var area=r(1162+i*99,417,83,78);skin.box(self,area,Rect2(1161,416,86,80),Color("0b1c29"))
		if i<3:equipment_art.draw(self,{"base":equipment_icon_bases[i]},area.grow(-10))
		elif i==3:skin.region(self,area.grow(-15),Rect2(1470,431,51,50))
		else:skin.region(self,area.grow(-16),Rect2(1574,433,47,48))
	for i in range(active_card_ids.size()):
		var id=active_card_ids[i];var area=card_rect(i);skin.box(self,area,Rect2(1157,631,88,137),Color("0c1b27"),10)
		var picture=Rect2(area.position+Vector2(7,8),Vector2(area.size.x-14,area.size.y-43))
		if id in home.battle.roster:draw_texture_rect(home.battle.texture(home.battle.portrait_path(id)),picture,false)
		var caption=Rect2(area.position+Vector2(5,area.size.y-33),Vector2(area.size.x-10,25));draw_rect(caption,Color("dec99f"))
		draw_string(home.font,caption.position+Vector2(1,20),Rules.CARD_NAMES[Rules.CARD_IDS.find(id)].replace("观察",""),HORIZONTAL_ALIGNMENT_CENTER,caption.size.x-2,18 if active_card_ids.size()<=5 else 14,Color("201b15"))
func _process(dt:float)->void:
	clock+=dt
	for card in cards:
		var badge=card.get_node("Badge")
		if badge.get_meta("shimmer",false):badge.modulate=Color.from_hsv(.52+.20*sin(clock),.30,1)
	status.modulate=Color.from_hsv(.52+.20*sin(clock),.30,1) if status.get_meta("shimmer",false) else Color.WHITE
func clear_click_suppression()->void:suppress_click=false
func _input(event:InputEvent)->void:
	if event is InputEventKey and event.pressed:
		if event.keycode==KEY_ESCAPE:home.close_campaign();get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_LEFT,KEY_RIGHT]:select_relative(-1 if event.keycode==KEY_LEFT else 1);get_viewport().set_input_as_handled()
	if event is InputEventMouseButton:
		var point=event.position
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			var target=group_scroll if group_scroll.get_global_rect().has_point(point) else scroll if scroll.get_global_rect().has_point(point) else null
			if target!=null:target.scroll_horizontal+=(-1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1)*GROUP_WIDTH;get_viewport().set_input_as_handled()
		elif event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed:
				suppress_click=false;dragging=false;drag_scroll=group_scroll if group_scroll.get_global_rect().has_point(point) else scroll if scroll.get_global_rect().has_point(point) else null
				if drag_scroll!=null:drag_origin=point;drag_start=drag_scroll.scroll_horizontal
			else:
				if dragging:suppress_click=true;get_viewport().set_input_as_handled();call_deferred("clear_click_suppression")
				drag_scroll=null;dragging=false
	elif event is InputEventMouseMotion and drag_scroll!=null:
		var delta=event.position.x-drag_origin.x
		if absf(delta)>7:dragging=true;suppress_click=true
		if dragging:drag_scroll.scroll_horizontal=int(drag_start-delta);get_viewport().set_input_as_handled()
