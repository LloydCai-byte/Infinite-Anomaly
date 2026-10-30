extends RefCounted
## Presentation only: every value comes from the live ATB units.
const Builds=preload("res://scripts/pixel_hyakki/progression/rules.gd")
const Model=preload("res://scripts/pixel_hyakki/model.gd")
const PAPER=Color("eee4ca")
const MUTED=Color("a6becb")
const GOLD=Color("c6a66a")
const ALLY=Color("79c893")
const ENEMY=Color("e48676")

static func hp_label(unit:Dictionary) -> String:return "%d / %d"%[maxi(0,unit.hp),unit.max_hp]
static func fit(font:Font,value:String,size:int,width:float) -> String:
	if font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x<=width:return value
	while value.length()>0 and font.get_string_size(value+"…",HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>width:value=value.left(-1)
	return value+"…"
static func text(view,value:String,point:Vector2,size:int=17,color:Color=PAPER,width:float=-1) -> void:
	view.text(fit(view.font,value,size,width) if width>0 else value,point,size,color)
static func panel(view,area:Rect2,active:bool=false) -> void:
	view.draw_rect(area,Color("111e29"));view.draw_rect(area.grow(-2),Color("1d303f"))
	view.draw_rect(Rect2(area.position+Vector2(3,3),Vector2(area.size.x-6,3)),Color("344c5a"))
	view.draw_rect(area,GOLD if active else Color("60717a"),false,2)
	for corner in [area.position,area.position+Vector2(area.size.x-6,0),area.end-Vector2(6,6),area.position+Vector2(0,area.size.y-6)]:view.draw_rect(Rect2(corner,Vector2(6,6)),GOLD)

static func health(view,unit:Dictionary,top:float) -> void:
	var label=hp_label(unit);var width=clampf(view.font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x+16,108,184)
	var area=Rect2(Vector2(unit.pos.x-width*.5,top).round(),Vector2(width,19))
	view.draw_rect(area.grow(2),Color("101820"));view.draw_rect(area,Color("393c42"))
	view.draw_rect(Rect2(area.position,Vector2(floorf(width*clampf(float(unit.hp)/unit.max_hp,0,1)),19)),Color("468458") if unit.side==0 else Color("a74f43"))
	var x=area.get_center().x-view.font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x*.5
	text(view,label,Vector2(x,area.position.y+15),15,Color.WHITE)
	if view.model.shields.size()>unit.uid and view.model.shields[unit.uid]>0:
		view.draw_rect(Rect2(area.position+Vector2(0,21),Vector2(width*minf(1,view.model.shields[unit.uid]/(unit.max_hp*.35)),3)),Color("80cfdf"))
	if view.model.focus==unit.uid:
		view.draw_rect(area.grow(5),Color("ffe093"),false,2);text(view,"集火",area.position+Vector2(width*.5-16,-9),14,Color("ffe093"))

static func timeline_layout(model,side:int=-1) -> Array:
	var entries=[];var start=936.0;var end=1518.0;var y=67.0
	for unit in model.alive(0)+model.alive(1):
		var active=not model.action.is_empty() and model.action.actor==unit.uid
		var waiting=model.ready_queue.has(unit.uid)
		var charge=clampf(unit.charge,0,1)
		entries.append({"uid":unit.uid,"side":unit.side,"active":active,"waiting":waiting,"anchor":end if waiting or active else lerpf(start,end,charge),"center":end if waiting or active else lerpf(start,end,charge),"y":y})
	entries.sort_custom(func(a,b):
		if not is_equal_approx(a.anchor,b.anchor):return a.anchor<b.anchor
		if a.active!=b.active:return b.active
		if a.waiting and b.waiting:return model.ready_queue.find(a.uid)>model.ready_queue.find(b.uid)
		return a.uid<b.uid)
	for entry in entries:entry.rect=Rect2(roundf(entry.center)-16,y-16,32,32)
	return entries if side<0 else entries.filter(func(entry):return entry.side==side)

static func timeline(view) -> void:
	# Portraits float over the scene; the only backdrop is the painted ivory rail.
	view.hud_skin.rail(view,Rect2(918,91,646,16))
	for entry in timeline_layout(view.hud_model()):
		var unit=view.hud_model().units[entry.uid];var color=ALLY if unit.side==0 else ENEMY
		view.draw_line(Vector2(entry.center,85),Vector2(entry.anchor,96),Color(color,.65),1)
		view.draw_rect(Rect2(entry.anchor-3,94,6,5),color)
		view.portrait(unit.get("visual_id",unit.id),entry.rect,GOLD if entry.active else color)
		if entry.waiting:view.draw_rect(Rect2(entry.rect.position+Vector2(26,0),Vector2(6,6)),GOLD)
		if entry.active:view.draw_rect(entry.rect.grow(3),Color("f4d98a"),false,2)

static func miniature(view,hero:int,area:Rect2) -> void:
	var id=view.hud_model().units[hero].id;var bounds=view.equipment_ui.actor_bounds[id]
	var scale=minf(area.size.x/bounds.size.x,area.size.y/bounds.size.y)
	var size=(bounds.size*scale).round();var destination=Rect2(Vector2(area.get_center().x-size.x*.5,area.end.y-size.y).round(),size)
	var theme=view.hud_model().looks_live[hero] if view.hud_model().looks_live.size()==5 else -1
	view.draw_texture_rect_region(view.look_texture(id,"idle",theme),destination,bounds,Color.WHITE if view.hud_model().units[hero].hp>0 else Color("777b83"))

static func party(view) -> void:
	var skin=view.hud_skin
	var sources=[Rect2(15,15,359,140),Rect2(391,15,361,141),Rect2(772,15,366,141),Rect2(1151,15,372,141),Rect2(1542,15,363,141)]
	var skills=[Rect2(306,100,47,47),Rect2(685,100,48,47),Rect2(1065,100,48,47),Rect2(1455,100,48,47),Rect2(1834,100,48,47)]
	for hero in range(5):
		var unit=view.hud_model().units[hero];var x=4+hero*319;var active=not view.hud_model().action.is_empty() and view.hud_model().action.actor==hero
		var card=Rect2(x,777,316,119);var source=sources[hero]
		skin.region(view,skin.party,card,source)
		# Replace all reference lettering, portraits and numbers with live content.
		skin.region(view,skin.party,Rect2(x+8,784,300,105),Rect2(source.position.x+210,138,65,6))
		miniature(view,hero,Rect2(x+11,790,106,94))
		text(view,unit.name,Vector2(x+123,800),20,PAPER,180)
		skin.region(view,skin.party,Rect2(x+122,808,18,17),Rect2(150,54,24,22))
		var area=Rect2(x+143,809,157,15)
		view.draw_rect(area,Color("263d30"))
		var hp=clampf(float(unit.hp)/unit.max_hp,0,1)
		if hp>0:skin.region(view,skin.party,Rect2(area.position,Vector2(floorf(area.size.x*hp),15)),Rect2(325,57,24,14))
		var label=hp_label(unit);var left=area.get_center().x-view.font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x*.5
		text(view,label,Vector2(left,822),14,Color.WHITE)
		skin.region(view,skin.party,Rect2(x+122,835,17,18),Rect2(151,84,23,24))
		skin.region(view,skin.party,Rect2(x+122,863,17,18),Rect2(151,115,23,23))
		text(view,"攻 %s"%str(unit.power),Vector2(x+143,850),17,PAPER,101)
		text(view,"速 %.1f"%unit.agility,Vector2(x+143,878),17,PAPER,101)
		skin.region(view,skin.party,Rect2(x+250,832,48,48),skills[hero],Color.WHITE if unit.hp>0 else Color(.45,.45,.45))
		if active:view.draw_rect(card.grow(-3),Color("f8dc8b"),false,2)
