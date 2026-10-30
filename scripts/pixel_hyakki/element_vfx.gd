extends RefCounted
## Read confirmed hits; this layer never rolls, deals or modifies damage.
static func emit(battle,target:int,element:String,source:int=-1) -> void:
	if element not in ["fire","cold","lightning","poison","bleed","heal"]:return
	for effect in battle.effects:
		if effect.kind=="element" and effect.target==target and effect.element==element and effect.age<.10:return
	battle.effects.append({"kind":"element","element":element,"target":target,"source":source,"pos":battle.units[target].pos+Vector2(0,-58),"age":0.0,"life":.72 if element!="lightning" else .46})

static func confirmed_hit(battle,hit:Dictionary,source:int,kind:String) -> void:
	if hit.tag in ["闪避","反伤"] or (hit.before<=hit.after and hit.tag!="护盾"):return
	var elements=[]
	var stats=battle.gear.b.units[source].stats if source>=0 and source<battle.gear.b.units.size() else {}
	if kind in ["fire","fire_burst","burn"]:elements.append("fire")
	if kind=="dot":elements.append("poison" if stats.get("poison",0)>0 else "bleed")
	elif kind not in ["burn","test","hazard"]:
		var native_element=stats.get("attack_element","physical")
		if native_element in ["fire","cold","lightning"]:elements.append(native_element)
		if battle.gear.b.units[hit.id].stats.resist<100:
			for element in ["fire","cold","lightning"]:
				if stats.get(element,0)>0 and element not in elements:elements.append(element)
		if battle.gear.b.units[hit.id].dot>0:
			if stats.get("poison",0)>0:elements.append("poison")
			elif "bleed" in stats.get("powers",[]):elements.append("bleed")
	for element in elements:emit(battle,hit.id,element,source)

static func draw(view,e:Dictionary) -> void:
	var t=e.age/e.life;var p=e.pos.round();var alpha=minf(1,(1-t)*3)
	match e.element:
		"fire":
			for i in range(4):
				var q=p+Vector2((i-1.5)*18,20-abs(i-1.5)*9-t*17)
				view.pixel_flame(q,22*(1-t*.6),e.age*2+i)
		"lightning":
			var points=PackedVector2Array();var phase=floori(e.age*18)
			for i in range(8):points.append((p+Vector2(0 if i in [0,7] else sin((i*7+phase)*2.7)*24,-146+i*22)).round())
			view.draw_polyline(points,Color(.44,.55,1,alpha),9,false);view.draw_polyline(points,Color(.91,.95,1,alpha),3,false)
			for side in [-1,1]:
				var branch=PackedVector2Array([points[3],points[3]+Vector2(side*35,18),points[3]+Vector2(side*17,35)])
				view.draw_polyline(branch,Color(.75,.85,1,alpha),3,false)
			for i in range(5):view.draw_rect(Rect2(p+Vector2((i-2)*17,15-((i+phase)%3)*7),Vector2(7,3)),Color(.85,.93,1,alpha))
		"cold":
			for i in range(5):
				var q=p+Vector2((i-2)*20,20-abs(i-2)*8-t*10);var h=29*(1-t*.35)
				view.draw_colored_polygon(PackedVector2Array([q+Vector2(-8,0),q+Vector2(-5,-h*.65),q+Vector2(2,-h),q+Vector2(9,0)]),Color(.3,.7,.85,alpha))
				view.draw_line(q+Vector2(2,-h+4),q+Vector2(2,-4),Color(.8,.98,1,alpha),3)
		"poison":
			for i in range(5):
				var q=(p+Vector2((i-2)*18+sin(i*2.2)*8,35-t*65-(i%2)*25)).round()
				view.draw_rect(Rect2(q-Vector2(6,6),Vector2(12,12)),Color(.24,.53,.26,alpha))
				view.draw_rect(Rect2(q-Vector2(3,6),Vector2(6,3)),Color(.7,.87,.38,alpha))
		"bleed":
			for i in range(4):
				var q=p+Vector2((i-1.5)*15,t*28-20)
				view.draw_line(q,q+Vector2(5,12),Color(.8,.18,.22,alpha),4)
		"heal":
			for i in range(3):
				var q=(p+Vector2((i-1)*22,-t*52-(i%2)*21)).round()
				view.draw_rect(Rect2(q-Vector2(2,7),Vector2(4,14)),Color(.53,.92,.62,alpha));view.draw_rect(Rect2(q-Vector2(7,2),Vector2(14,4)),Color(.53,.92,.62,alpha))
