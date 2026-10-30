extends Node2D
const G=preload("res://scripts/turnbased/gear.gd")
const Art=preload("res://scripts/pixel_hyakki/equipment_art.gd")
const Drag=preload("res://scripts/pixel_hyakki/equipment_drag.gd")
const HEROES=["粉粉","高哥","七七","大东老师","老王"]
const IDS=["fenfen","gao","qiqi","dadong","wang"]
const TAB_X=[136,427,662,915,1165]
const TAB_W=[282,225,242,239,230]
const SCALE=Vector2(1600.0/1774.0,1600.0/1774.0)
const OFFSET=Vector2(0,50)
const GOLD=Color("ffa64c")
const WHITE=Color("f0e8d4")
const MUTED=Color("b9cbd1")
const INK=Color("111824")
var host
var gear
var font
var title_font=preload("res://scripts/pixel_home/typography.gd").bold()
var layer:Control
var controls={}
var hero=0
var selected=0
var target_slot=""
var type_filter=0
var quality_filter=0
var sort_mode=0
var page=0
var clock=0.0
var toast=""
var toast_time=0.0
var confirm_salvage=false
var art=Art.new()
var actor_bounds={}
var portrait_bounds={}
var drag
var skin=preload("res://scripts/pixel_hyakki/equipment_skin.gd").new()
var chrome=[]
var list_view=false

func r(x:float,y:float,w:float,h:float)->Rect2:return Rect2(OFFSET+Vector2(x,y)*SCALE,Vector2(w,h)*SCALE)
func p(x:float,y:float)->Vector2:return OFFSET+Vector2(x,y)*SCALE
func setup(owner_view,store)->void:
	host=owner_view;gear=store;font=host.font;texture_filter=TEXTURE_FILTER_NEAREST
	art.reference_skin=true
	layer=Control.new();layer.size=Vector2(1600,900);layer.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(layer)
	var overlay=preload("res://scripts/pixel_hyakki/equipment_overlay.gd").new();overlay.owner_ui=self;add_child(overlay)
	drag=Drag.new();add_child(drag);drag.setup(self)
	selected=gear.s.inventory[5].id if gear.s.inventory.size()>5 else 0
	for id in IDS:
		var im=host.texture(host.clip_path(id,"idle")).get_image()
		actor_bounds[id]=Rect2(im.get_region(Rect2i(0,0,160,144)).get_used_rect())
		portrait_bounds[id]=Rect2(host.texture(host.ART+"sprites/"+id+"/portrait.png").get_image().get_used_rect())
	refresh()
func _process(dt:float)->void:
	if not visible:return
	clock+=dt;toast_time=maxf(0,toast_time-dt);queue_redraw()
func message(value:String)->void:toast=value;toast_time=4
func changed(value:String)->void:
	message(value if gear.persist() else "保存失败："+gear.last_error)
	refresh()
func glass(color:Color,border:Color=Color.TRANSPARENT)->StyleBoxFlat:
	var box=StyleBoxFlat.new();box.bg_color=color;box.border_color=border;box.set_border_width_all(2);return box
func material(selected:bool=false)->StyleBoxFlat:
	var box=glass(Color("f7a34c") if selected else Color("102238"),Color("ffd29a") if selected else Color("52718b"))
	box.border_width_bottom=4;box.set_content_margin_all(5);return box
func button(value:String,rect:Rect2,fn:Callable,key:String,active:bool=false,disabled:bool=false,_baked:bool=true)->Button:
	var b=Button.new();b.text=value;b.position=rect.position;b.size=rect.size;b.disabled=disabled
	var emphasized=active or key in ["equip","train"]
	b.add_theme_font_override("font",title_font if emphasized else font);b.add_theme_font_size_override("font_size",21)
	b.add_theme_color_override("font_color",INK if emphasized else WHITE)
	b.add_theme_color_override("font_hover_color",INK if emphasized else Color.WHITE)
	b.add_theme_color_override("font_pressed_color",INK if emphasized else WHITE)
	b.add_theme_color_override("font_disabled_color",Color("7b8591"))
	b.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover",glass(Color(1,.72,.3,.08),Color(1,.76,.4,.65)))
	b.add_theme_stylebox_override("pressed",glass(Color(0,0,0,.18),GOLD))
	b.add_theme_stylebox_override("focus",glass(Color.TRANSPARENT,Color("f3cd88")))
	b.add_theme_stylebox_override("disabled",StyleBoxEmpty.new())
	var source=Rect2(1256,747,195,54) if emphasized else Rect2(1460,747,183,54)
	var fill=skin.ORANGE if emphasized else skin.NAVY
	if key.begins_with("hero_"):
		source=Rect2(136,151,282,63) if active else Rect2(427,151,225,63)
		fill=skin.ORANGE if active else skin.BLUE
		b.add_theme_color_override("font_color",INK if active else Color("9cc9ef"))
	elif key=="train":source=Rect2(112,812,419,49)
	elif key.begins_with("slot_"):
		source=Rect2(259,582,123,100) if key=="slot_weapon" else Rect2(122,312,89,84)
	elif key in ["prev","next","back","view_grid","view_list","recent"] or key.begins_with("item_"):source=Rect2()
	if source.has_area():chrome.append({"rect":rect,"source":source,"fill":fill})
	b.pressed.connect(fn);layer.add_child(b);controls[key]=b;return b
func dropdown(values:Array,rect:Rect2,value:int,fn:Callable,key:String)->void:
	var b=OptionButton.new();b.position=rect.position;b.size=rect.size
	b.add_theme_font_override("font",font);b.add_theme_font_size_override("font_size",19)
	b.add_theme_color_override("font_color",WHITE);b.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover",glass(Color(1,.7,.2,.08),GOLD));b.add_theme_stylebox_override("focus",glass(Color.TRANSPARENT,GOLD))
	b.add_theme_constant_override("arrow_margin",12)
	var arrow=AtlasTexture.new();arrow.atlas=skin.texture;arrow.region=Rect2(738,314,20,16)
	b.add_theme_icon_override("arrow",arrow)
	for v in values:b.add_item("  "+v)
	b.select(value);b.item_selected.connect(fn)
	var menu=b.get_popup();menu.add_theme_font_override("font",font);menu.add_theme_font_size_override("font_size",19)
	menu.add_theme_stylebox_override("panel",material());menu.add_theme_stylebox_override("hover",glass(Color("426c7a")))
	menu.add_theme_color_override("font_color",WHITE)
	chrome.append({"rect":rect,"source":Rect2(591,300,181,44),"fill":skin.NAVY})
	layer.add_child(b);controls[key]=b
func label(value:String,rect:Rect2,size:int=18,color:Color=WHITE,heading:bool=false)->Label:
	var l=Label.new();l.text=value;l.position=rect.position;l.size=rect.size
	l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;l.mouse_filter=Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font",title_font if heading else font);l.add_theme_font_size_override("font_size",size);l.add_theme_color_override("font_color",color)
	layer.add_child(l);return l
func txt(value:String,point:Vector2,size:int=18,color:Color=WHITE,heading:bool=false)->void:
	draw_string(title_font if heading else font,point,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
func items()->Array:
	var a=gear.s.inventory.filter(func(i):return (type_filter==0 or G.type_of(i)==G.TYPES[type_filter-1]) and (quality_filter==0 or i.quality==quality_filter-1))
	a.sort_custom(func(x,y):
		if sort_mode==1:return G.score(x)>G.score(y) if not is_equal_approx(G.score(x),G.score(y)) else x.id>y.id
		if sort_mode==2:return x.quality>y.quality if x.quality!=y.quality else x.id>y.id
		return x.id>y.id)
	return a
func slot_for(item:Dictionary)->String:
	var type=G.type_of(item)
	return (target_slot if target_slot in ["ring_a","ring_b"] else "ring_a") if type=="ring" else type
func slot_rect(i:int)->Rect2:
	if i==0:return r(259,582,123,100)
	var ys=[312,405,498,590]
	return r(122 if i<=4 else 431,ys[(i-1)%4],89 if i<=4 else 91,84 if (i-1)%4<3 else 88)
func page_size()->int:return 7 if list_view else 35
func cell_rect(n:int)->Rect2:
	if list_view:return r(587,362+n*60,617,56)
	var xs=[587,675,763,851,939,1028,1118]
	var ys=[362,447,533,618,703]
	return r(xs[n%7],ys[int(n/7)],83,79)
func icon_area(rect:Rect2)->Rect2:return Rect2(rect.position+Vector2(8,5)*SCALE,rect.size-Vector2(16,21)*SCALE)
func choose(id:int)->void:
	selected=id;target_slot="";confirm_salvage=false;refresh()
func refresh()->void:
	for c in layer.get_children():layer.remove_child(c);c.queue_free()
	controls={};chrome=[]
	button("",r(1598,50,47,46),host.close_equipment,"back").tooltip_text="关闭装备 [B / Esc]"
	for h in range(5):
		var n=h
		button("       "+HEROES[h],r(TAB_X[h],151,TAB_W[h],63),func():hero=n;target_slot="";confirm_salvage=false;refresh(),"hero_%d"%h,hero==h)
	for i in range(9):
		var slot=G.SLOTS[i];var id=int(gear.s.equipped[hero].get(slot,0));var item=gear.item_by_id(id)
		var b=button("",slot_rect(i),func():target_slot=slot;selected=id;confirm_salvage=false;refresh(),"slot_"+slot)
		b.tooltip_text=G.SLOT_NAMES[i]+(" · "+G.name_of(item) if id else " · 空槽")
	var cost=gear.train_cost(hero)
	button("培养 · %d金币"%cost,r(112,812,419,49),func():if gear.train(hero):changed("培养完成：生命 +14，攻击 +2"),"train",false,gear.s.gold<cost).tooltip_text="生命 +14，攻击 +2；下个场景应用。需要 %d 金币。"%cost
	dropdown(["全部部位","职业武器","头盔","护甲","手套","靴子","腰带","项链","戒指"],r(591,300,181,44),type_filter,func(i):type_filter=i;page=0;refresh(),"filter_type")
	dropdown(["全部品质"]+G.QUALITY,r(784,300,184,44),quality_filter,func(i):quality_filter=i;page=0;refresh(),"filter_quality")
	dropdown(["最新获得","评分排序","品质排序"],r(981,300,219,44),sort_mode,func(i):sort_mode=i;page=0;refresh(),"sort")
	var a=items();var pages=maxi(1,ceili(float(a.size())/page_size()));page=clampi(page,0,pages-1)
	for n in range(page_size()):
		if page*page_size()+n>=a.size():break
		var item=a[page*page_size()+n];var b=button("",cell_rect(n),func():choose(item.id),"item_%d"%item.id)
		b.tooltip_text=G.name_of(item)+"\n"+G.QUALITY[item.quality]+" · 等级 "+str(item.level)
	button("",r(703,812,78,43),func():page-=1;refresh(),"prev",false,page==0).tooltip_text="上一页"
	button("",r(1003,812,78,43),func():page+=1;refresh(),"next",false,page>=pages-1).tooltip_text="下一页"
	list_view=false
	if gear.has_method("salvage_batch"):
		button("整理",r(1008,246,108,40),func():
			var panel=preload("res://scripts/pixel_home/salvage_ui.gd").new();add_child(panel);panel.setup(self),"organize")
	if not gear.s.loot_log.is_empty():
		var recent=gear.s.loot_log.back()
		button("",r(1508,245,57,39),func():type_filter=0;quality_filter=0;sort_mode=0;page=0;choose(recent.id),"recent",false,gear.item_by_id(recent.id).is_empty()).tooltip_text="最新掉落："+recent.name+" · 点击查看"
	details();queue_redraw()

func details()->void:
	var item=gear.item_by_id(selected)
	if item.is_empty():
		label("选择一件装备",r(1404,327,238,70),25,GOLD,true)
		for action in [["穿戴装备",r(1256,747,195,54),"equip"],["卸下",r(1460,747,183,54),"unequip"],["   锁定",r(1255,813,194,52),"lock"],["   分解",r(1460,813,183,52),"salvage"]]:
			button(action[0],action[1],func():pass,action[2],false,true)
		return
	var color=Color(G.COLORS[item.quality]);var slot=slot_for(item);var own=gear.owner(item.id);var can=G.can_equip(item,hero,slot)
	label(G.name_of(item),r(1404,311,238,60),27,Color("4098e9") if item.quality==1 else color,true)
	var type_name=G.SLOT_NAMES[G.SLOTS.find(slot)]
	label(G.QUALITY[item.quality]+" · "+type_name+"\n物品等级 %d"%item.level,r(1404,366,238,66),21,MUTED)
	var body="[color=#ff8c30]固有属性[/color]\n"
	for k in G.inherent(item):body+=G.line(k,G.inherent(item)[k])+"\n"
	body+="[color=#ff8c30]随机词条[/color]\n"
	for k in item.affixes:body+=G.line(k,item.affixes[k])+"\n"
	if item.affixes.is_empty():body+="无随机词条\n"
	if item.power!="":body+="[color=#e4bb79]"+G.POWERS[item.power][0]+"[/color]："+G.POWERS[item.power][1]
	var set_id=int(G.bases[item.base].get("set",-1))
	if set_id>=0:
		var count=0
		for id in gear.s.equipped[hero].values():
			if int(G.bases[gear.item_by_id(id).base].get("set",-1))==set_id:count+=1
		body+="[color=#91d2a4]"+G.SETS[set_id]+(" · 已穿戴 %d/4[/color]\n2件：攻击 +10%%\n4件："%count)+["额外波及一名敌人，35%伤害","行动治疗最低生命队友","每次行动获得10点护盾"][set_id]
	var rich=RichTextLabel.new();rich.bbcode_enabled=true;rich.text=gear.describe_rules(body.strip_edges());rich.position=r(1268,441,365,174).position;rich.size=r(1268,441,365,174).size
	rich.add_theme_font_override("normal_font",font);rich.add_theme_font_size_override("normal_font_size",21);rich.add_theme_color_override("default_color",WHITE)
	rich.scroll_active=true;rich.add_theme_constant_override("line_separation",0);layer.add_child(rich);controls["details_body"]=rich
	var before=gear.item_by_id(gear.s.equipped[hero].get(slot,0))
	label("替换："+("空槽位" if before.is_empty() else G.name_of(before)),r(1268,636,366,31),20,MUTED)
	if can:
		var delta=host.model.preview_equipment(item.id,hero,slot).delta
		rich.tooltip_text+="\n装备后护甲变化：%+.1f"%float(delta.armor)
		var keys=["atk","hp","speed","crit"];var names=["攻击","生命","速度","暴击"]
		for i in range(keys.size()):
			var value=float(delta[keys[i]])
			label(names[i]+" %+.1f"%value+("%" if keys[i]=="crit" else ""),r(1268+(i%2)*198,670+int(i/2)*31,193,29),20,MUTED)
	else:label("职业不符：仅"+HEROES[G.bases[item.base].hero]+"可使用",r(1268,671,365,50),19,Color("ec9d8d"))
	if G.type_of(item)=="ring":
		button("戒指Ⅰ",r(1404,425,112,29),func():target_slot="ring_a";refresh(),"ring_a",slot=="ring_a",false,false).add_theme_font_size_override("font_size",15)
		button("戒指Ⅱ",r(1522,425,112,29),func():target_slot="ring_b";refresh(),"ring_b",slot=="ring_b",false,false).add_theme_font_size_override("font_size",15)
	elif set_id>=0:rich.tooltip_text+="\n"+("整套外观已生效" if gear.equipped_look(hero)==set_id else "穿齐同套头盔、护甲、手套、靴子后自动换装")
	elif own>=0:rich.tooltip_text+="\n当前穿戴："+HEROES[own]+(" · 穿戴会转交" if own!=hero else "")
	button("转交给"+HEROES[hero] if own>=0 and own!=hero else "穿戴装备",r(1256,747,195,54),func():if gear.equip(item.id,hero,slot):changed("已穿戴："+G.name_of(item)),"equip",false,not can)
	button("卸下",r(1460,747,183,54),func():
		for k in gear.s.equipped[hero].keys():
			if gear.s.equipped[hero][k]==item.id:gear.unequip(hero,k)
		changed("装备已放回背包"),"unequip",false,own!=hero)
	button("   解除锁定" if item.get("locked",false) else "   锁定",r(1255,813,194,52),func():item.locked=not item.get("locked",false);changed("锁定状态已更新"),"lock")
	button("确认分解1件" if confirm_salvage else "   分解",r(1460,813,183,52),func():
		if gear.has_method("salvage_selection"):
			var dialog=preload("res://scripts/pixel_home/salvage_confirm.gd").new();add_child(dialog);dialog.setup(self,{"ids":[item.id],"gold":gear.salvage_gold(item)})
		elif not confirm_salvage:confirm_salvage=true;refresh()
		elif gear.salvage(item.id):selected=0;confirm_salvage=false;changed("+%d金币"%gear.salvage_gold(item)),"salvage",false,own>=0 or item.get("locked",false)).tooltip_text="分解1件 · +%d金币"%gear.salvage_gold(item)

func preview_scale() -> float:
	var reference=actor_bounds.fenfen;var area=r(215,380,230,202)
	return minf(area.size.x/reference.size.x,area.size.y/reference.size.y)

func atlas(source:Rect2)->void:skin.region(self,r(source.position.x,source.position.y,source.size.x,source.size.y),source)
func fill(rect:Rect2,source:Rect2)->void:skin.region(self,rect,source)
func _draw()->void:
	if host==null:return
	draw_rect(Rect2(0,0,1600,900),Color(0,0,0,.48))
	# A broad falling shadow separates the original supplied window from the scene.
	for step in range(24,0,-2):
		var shadow=StyleBoxFlat.new();shadow.bg_color=Color(0,0,0,.025);shadow.set_corner_radius_all(8)
		var shadow_rect=r(77,35,1589,849).grow(step);shadow_rect.position.y+=10;draw_style_box(shadow,shadow_rect)
	# Exact supplied chrome, with all changing pixels replaced before live content.
	for source in [Rect2(110,35,1547,190),Rect2(77,223,488,661),Rect2(565,223,669,661),Rect2(1236,223,430,661)]:atlas(source)
	# Clear baked portrait overspill below the tab edges before drawing live tabs.
	fill(r(112,146,1298,79),skin.NAVY)
	fill(r(1122,244,92,44),skin.CREAM)
	fill(r(1260,71,143,36),skin.NAVY)
	txt("金币 %d"%gear.s.gold,p(1267,99),24,Color("f4d6b0"))
	fill(r(144,241,359,45),skin.CREAM)
	fill(r(600,241,395,45),skin.CREAM)
	txt(HEROES[hero]+" · Lv.%d"%gear.s.level,p(148,278),28,INK,true)
	txt("背包 · %d件"%gear.s.inventory.size(),p(603,278),28,INK,true)
	skin.tile(self,r(115,306,420,382),skin.GRID,SCALE.x)
	fill(r(585,359,624,428),skin.NAVY)
	fill(r(1255,299,389,317),skin.NAVY)
	fill(r(1264,630,375,106),skin.NAVY)
	# Erase only numbers; retain the reference's stat symbols and labels.
	for x in [235,448]:
		for y in [706,738,770]:fill(r(x,y,79,30),skin.NAVY)
	var st=host.model.preview_stats(hero)
	for i in range(3):
		txt(["%d"%st.hp,"%.1f"%st.armor,"%.1f%%"%st.crit][i],p(237,730+i*32),20)
		txt(["%.1f"%st.atk,"%.1f"%st.speed,"%.0f%%"%st.crit_damage][i],p(452,730+i*32),20)
	fill(r(819,805,147,52),skin.CREAM)
	var pages=maxi(1,ceili(float(items().size())/page_size()))
	txt("%d / %d"%[page+1,pages],p(861,842),24,INK)
	for n in range(page_size()):
		var rect=cell_rect(n);fill(rect,skin.NAVY);draw_rect(rect,Color("324c64"),false,1)
	for c in chrome:skin.box(self,c.rect,c.source,c.fill,SCALE.x)
	atlas(Rect2(119,823,20,29));atlas(Rect2(505,823,17,29))
	# The weapon slot belongs in front of the pose, as in the reference.
	var id=IDS[hero];var bounds=actor_bounds[id];var area=r(215,380,230,202)
	var size=bounds.size*preview_scale()*Vector2(1,host.idle_stretch(clock))
	var dest=Rect2(Vector2(area.get_center().x-size.x*.5,area.end.y-size.y),size)
	draw_texture_rect_region(host.look_texture(id,"idle",gear.equipped_look(hero)),dest,bounds)
	skin.box(self,slot_rect(0),Rect2(259,582,123,100),skin.NAVY,SCALE.x)
	skin.box(self,r(1260,315,126,117),Rect2(1260,315,126,117),skin.NAVY,SCALE.x,10)
	if list_view:
		fill(r(1126,250,34,34),skin.CREAM);fill(r(1171,250,34,34),skin.ORANGE)
		atlas(Rect2(1135,257,19,20));atlas(Rect2(1179,257,20,20))
	# Action glyphs are fixed ornament; their labels and callbacks remain live.
	atlas(Rect2(1281,823,25,31));atlas(Rect2(1506,826,30,28))
	if items().is_empty():txt("没有符合筛选条件的装备",p(720,570),20,MUTED)
	if toast_time>0:
		var w=minf(950,font.get_string_size(toast,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x+44)
		var box=Rect2(Vector2((1600-w)*.5,856),Vector2(w,33))
		draw_rect(box,Color("102034"));draw_rect(box,GOLD,false,1);txt(toast,box.position+Vector2(20,23),18,WHITE)

func draw_lock(canvas:Node2D,rect:Rect2) -> void:
	var origin=(rect.end-Vector2(22,30)).round()
	canvas.draw_rect(Rect2(origin-Vector2(3,3),Vector2(19,21)),Color("152330"))
	canvas.draw_rect(Rect2(origin+Vector2(3,0),Vector2(7,8)),Color("edcf8d"),false,2)
	canvas.draw_rect(Rect2(origin+Vector2(0,6),Vector2(13,10)),Color("edcf8d"))
	canvas.draw_rect(Rect2(origin+Vector2(6,9),Vector2(2,5)),Color("314350"))

func draw_icons(canvas:Node2D)->void:
	for h in range(5):
		var bounds=portrait_bounds[IDS[h]];var area=r(TAB_X[h]+24,159,59,47)
		var size=bounds.size*minf(area.size.x/bounds.size.x,area.size.y/bounds.size.y)
		canvas.draw_texture_rect_region(host.texture(host.ART+"sprites/"+IDS[h]+"/portrait.png"),Rect2(area.get_center()-size*.5,size),bounds)
	for i in range(9):
		var rect=slot_rect(i);var item=gear.item_by_id(gear.s.equipped[hero].get(G.SLOTS[i],0))
		var slot_area=icon_area(rect) if i==0 else Rect2(rect.position+Vector2(18,12)*SCALE,rect.size-Vector2(36,41)*SCALE)
		if not item.is_empty():art.draw(canvas,item,slot_area)
		else:
			var placeholder={"base":[0,20,26,32,38,44,50,56,56][i]}
			art.draw(canvas,placeholder,slot_area,Color(1,1,1,.27))
		if item.get("locked",false):draw_lock(canvas,rect)
		if target_slot==G.SLOTS[i]:canvas.draw_rect(rect.grow(-1),GOLD,false,2)
		canvas.draw_string(font,Vector2(rect.position.x+5,rect.end.y-6),G.SLOT_NAMES[i] if i!=0 else "武器",HORIZONTAL_ALIGNMENT_CENTER,rect.size.x-10,18,WHITE)
	var a=items()
	for n in range(page_size()):
		if page*page_size()+n>=a.size():break
		var item=a[page*page_size()+n];var rect=cell_rect(n);var color=Color(G.COLORS[item.quality])
		canvas.draw_rect(rect.grow(-1),GOLD if selected==item.id else color,false,2)
		if selected==item.id:canvas.draw_rect(rect.grow(-5),Color("6d4d25"),false,1)
		var area=Rect2(rect.position+Vector2(8,4),Vector2(44,42)) if list_view else icon_area(rect)
		art.draw(canvas,item,area)
		if list_view:canvas.draw_string(font,rect.position+Vector2(69,31),G.name_of(item)+" · "+G.QUALITY[item.quality],HORIZONTAL_ALIGNMENT_LEFT,-1,19,color)
		canvas.draw_string(font,rect.position+Vector2(5,rect.size.y-5),str(item.level),HORIZONTAL_ALIGNMENT_LEFT,-1,18,color)
		if item.get("locked",false):draw_lock(canvas,rect)
		var badge="穿" if gear.owner(item.id)>=0 else ""
		canvas.draw_string(font,rect.position+Vector2(rect.size.x-19,rect.size.y-5),badge,HORIZONTAL_ALIGNMENT_LEFT,-1,12,GOLD)
	var item=gear.item_by_id(selected)
	if not item.is_empty():art.draw(canvas,item,r(1272,326,102,94))
