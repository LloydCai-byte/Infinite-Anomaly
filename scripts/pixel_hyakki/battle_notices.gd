extends RefCounted
const DURATION=2.0
const EXIT_TIME=.35
const VISIBLE_LIMIT=3
var entries:Array=[]
var seen_loot:Dictionary={}
func clear() -> void:entries=[];seen_loot={}
func push(label:String,item:Dictionary={}) -> void:
	entries.append({"label":label,"item":item.duplicate(true),"age":0.0})
func collect(view) -> void:
	for effect in view.model.effects:
		if effect.kind!="loot":continue
		var id=int(effect.item.id)
		if seen_loot.has(id):continue
		seen_loot[id]=true;push("获得 "+view.equipment.G.name_of(effect.item),effect.item)
func tick(delta:float) -> void:
	for i in range(mini(VISIBLE_LIMIT,entries.size())):entries[i].age+=delta
	entries=entries.filter(func(entry):return entry.age<DURATION)
func offset(entry:Dictionary) -> float:
	var t=clampf((entry.age-(DURATION-EXIT_TIME))/EXIT_TIME,0,1)
	return 720*t*t
func draw(view) -> void:
	for i in range(mini(VISIBLE_LIMIT,entries.size())):
		var entry=entries[i];var width=notice_width(view,entry);var x=1573-width+offset(entry);var y=121+i*66
		view.hud_skin.panel(view,Rect2(x,y,width,59))
		var color=Color("f2d49a");var text_x=x+22
		if not entry.item.is_empty():
			view.equipment_ui.art.draw(view,entry.item,Rect2(x+12,y+9,40,40));text_x=x+66
			color=Color(view.equipment.G.COLORS[entry.item.quality])
		view.text(view.Hud.fit(view.font,entry.label,19,width-(text_x-x)-18),Vector2(text_x,y+36),19,color)

func notice_width(view,entry:Dictionary)->float:
	return clampf(view.font.get_string_size(entry.label,HORIZONTAL_ALIGNMENT_LEFT,-1,19).x+(84 if not entry.item.is_empty() else 40),180,540)
