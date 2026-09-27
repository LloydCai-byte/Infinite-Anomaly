extends Control
const Art=preload("res://scripts/reboot/art.gd")
const C=preload("res://scripts/reboot/catalog.gd")
var game: Control
var clock=0.0
var particles: Array=[]
var small_font: Font

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	small_font=ThemeDB.fallback_font

func _process(delta: float) -> void:
	if game==null: return
	if not game.is_paused():
		clock+=delta*game.model.s.speed
		for p in particles: p.life-=delta*game.model.s.speed
		particles=particles.filter(func(p): return p.life>0)
	queue_redraw()

func add_event(e: Dictionary) -> void:
	if e.type in ["hit","heal","attack","skill"]:
		var p=e.duplicate()
		p.life=.75 if e.type in ["hit","heal"] else .2
		particles.append(p)
	if e.type in ["between","wave","result"]: particles.clear()

func actor(id: String, index: int, foot: Vector2, height: float, tint=Color.WHITE) -> void:
	var t=Art.frame(id,index)
	var r=t.region
	var scale_factor=height/Art.manifest[id].cell[1]
	var sz=Vector2(r.size)*scale_factor
	draw_texture_rect(Art.ui("shadow"),Rect2(foot-Vector2(height*.24,7),Vector2(height*.48,15)),false,Color(1,1,1,tint.a))
	draw_texture_rect(t,Rect2(foot-Vector2(sz.x*.5,sz.y),sz),false,tint)

func _draw() -> void:
	if game==null: return
	var s=game.model.s
	var battle_view=game.view=="battle" and not s.battle.is_empty()
	draw_texture_rect(Art.background(C.mission(s.battle.mission).bg if battle_view else ("base_t2" if s.tier>=2 else "base")),Rect2(0,0,1600,900),false)
	if not battle_view:
		if not game.model.active() and game.view!="title":
			for i in range(4):
				var positions=[Vector2(442,635),Vector2(657,641),Vector2(904,645),Vector2(1119,645)]
				actor(C.PEOPLE[i].id,12 if not s.training.is_empty() else int(clock*.65+i)%4,positions[i],216)
		return
	var units=s.battle.units.duplicate()
	units.sort_custom(func(a,b): return a.y<b.y)
	for u in units:
		var index=0
		var id=C.PEOPLE[u.role].id if u.side==0 else C.mission(s.battle.mission).enemy
		if u.hp<=0:
			if u.dead_time>2.0: continue
			index=14 if u.dead_time<.35 else 15
		elif u.side==0:
			index=int(u.anim_time*2)%4
			if u.anim=="run": index=4+int(u.anim_time*8)%4
			if u.anim=="attack": index=8+mini(3,int(u.anim_time*8))
		else:
			index=(8 if u.boss else 0)+int(u.anim_time*(8 if u.anim=="run" else 2))%4
			if u.anim=="attack": index=(12 if u.boss else 4)+mini(3,int(u.anim_time*8))
			if u.hp<=0: index=11 if u.boss else 3
		var tint=Color.WHITE
		if u.flash>0 and s.settings.flash: tint=Color(1.4,1.3,1.2)
		if u.hp<=0: tint.a=maxf(0,1-u.dead_time/2.0)
		var height=166.0 if u.side==0 else (220.0 if u.boss else 131.0)
		actor(id,index,Vector2(u.x,u.y),height,tint)
		if u.hp>0:
			var bar=Rect2(u.x-32,u.y-height*.91,64,7)
			draw_texture_rect(Art.ui("health_bg"),bar,false)
			bar.size.x*=clampf(u.hp/u.max_hp,0,1)
			draw_texture_rect(Art.ui("health_fill"),bar,false,Color.WHITE if u.side==0 else Color("e6a18b"))
			if u.shield>0: draw_arc(Vector2(u.x,u.y-height*.43),height*.34,-1.5,1.5,16,Color("8be0db"),2,true)
	for p in particles:
		if p.type in ["hit","heal"]:
			if p.value==0: continue
			var text_value=("+" if p.type=="heal" else "")+str(p.value)
			var pos=Vector2(p.x-10,p.y-150-(.75-p.life)*35)
			draw_string(small_font,pos+Vector2(1,2),text_value,HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color(0,0,0,p.life/.75))
			draw_string(small_font,pos,text_value,HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("b4e8ca") if p.type=="heal" else Color("eee7d4"))
		elif p.type=="attack" and p.role>0 and p.side==0:
			draw_line(Vector2(p.x+25,p.y-91),Vector2(p.tx,p.ty-55),Color(1,.89,.64,p.life*3),2,true)
		elif p.type=="skill":
			draw_texture_rect(Art.ui("crosshair"),Rect2(p.x-35,p.y-165,70,70),false,Color(.7,1,.9,p.life*4))
