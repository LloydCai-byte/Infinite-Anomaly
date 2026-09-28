extends RefCounted
const Art=preload("res://scripts/reboot/art.gd")
const C=preload("res://scripts/reboot/war_catalog.gd")
const People=preload("res://scripts/reboot/catalog.gd")
var last_stream=0
var last_land=-99.0
var previous_counts=[0,0,0,0]
var casualties: Array=[]

func event(e: Dictionary,time: float) -> void:
	if e.type=="war_landing": last_stream=int(e.stream);last_land=time

func update(world: Control,delta: float) -> void:
	if not world.game.model.in_war(): return
	var counts=world.game.model.war_model().roles()
	for role in range(4):
		if counts[role]<previous_counts[role]:
			for i in range(mini(2,previous_counts[role]-counts[role])):
				casualties.append({"role":role,"life":1.5,"x":773-role*91-i*32,"y":441+fmod(world.clock*13+role*47+i*81,248)})
	previous_counts=counts
	for p in casualties: p.life-=delta
	casualties=casualties.filter(func(p): return p.life>0)
	if casualties.size()>24: casualties=casualties.slice(casualties.size()-24)

func draw(world: Control) -> void:
	var s=world.game.model.s.war
	var w=world.game.model.war_model()
	var d=C.planet(s.planet if s.active else maxi(0,s.occupied-1))
	var bg=d.bg if s.active or s.occupied>0 else "orbit"
	world.draw_texture_rect(Art.background(bg),Rect2(0,0,1600,900),false)
	var counts=w.roles()
	var total=w.soldiers()
	var push=clampf(float(s.enemy_count)/maxf(1,total)-1,0,4)/4
	var front=790.0-push*440
	var units=[]
	var named_ids=[]
	for p in s.originals:
		if p.status in ["在役","驻守"]:
			named_ids.append(p.id)
			var role=int(p.role)
			units.append({"id":p.id,"index":4+int(world.clock*7)%4 if s.phase=="landing" else (8+int(world.clock*5)%4 if s.phase=="fight" else int(world.clock)%4),"x":front-role*95,"y":640.0+role*12,"height":106.0,"side":0})
	var visible_budget=44-named_ids.size()
	var represented=0
	for role in range(4):
		var count=int(counts[role])
		for p in s.originals:
			if p.role==role and p.id in named_ids: count-=1
		if count<=0: continue
		var sample=mini(count,maxi(1,int(visible_budget*float(count)/maxi(1,total))))
		for i in range(sample):
			var x=front-role*95-int(i/5)*38
			var y=435.0+(i%5)*51+role*9
			var index=int(world.clock*2+i)%4
			if s.phase=="landing": x-=35*sin(minf(1,s.wait/3)*PI*.5);index=4+int(world.clock*8+i)%4
			if s.phase=="fight":
				index=8+int(world.clock*6+i*.6)%4
				x+=sin(world.clock*2+i)*2
			units.append({"id":C.ROLES[role].asset,"index":index,"x":x,"y":y,"height":86.0,"side":0})
			represented+=1
	var enemies=mini(36,int(s.enemy_count))
	for i in range(enemies):
		var boss=i==enemies-1 and int(s.stage)==int(d.stages)-1
		var x=front+70.0+int(i/6)*53
		var y=440.0+(i%6)*49
		if boss: x=front+103;y=636
		var index=(12 if boss else 4)+int(world.clock*5+i*.4)%4
		if push>.5: index=(8 if boss else 0)+int(world.clock*8+i)%4
		units.append({"id":d.enemy,"index":index,"x":x,"y":y,"height":158.0 if boss else 83.0,"side":1})
	units.sort_custom(func(a,b): return a.y<b.y)
	for unit in units: world.actor(unit.id,unit.index,Vector2(unit.x,unit.y),unit.height)
	if s.phase=="fight" and total>0 and s.enemy_count>0:
		for i in range(6):
			if fmod(world.clock*4+i*.27,1)>.27: continue
			world.draw_line(Vector2(front-80-i*24,391+i*47),Vector2(front+87+i*25,403+i*47),Color("d9ca99"),1.6,true)
		if counts[3]>0 and int(world.clock*2)%6==0:
			world.draw_texture_rect(Art.ui("icon_medical"),Rect2(front-50,384,22,22),false,Color(.7,1,.85,.8))
	for p in casualties:
		world.actor(C.ROLES[p.role].asset,14 if p.life>1.1 else 15,Vector2(p.x,p.y),85,Color(1,1,1,p.life/1.5))
	draw_room(world,s)
	if s.phase=="fight":
		world.draw_texture_rect(Art.ui("emblem"),Rect2(51,469,76,76),false)
		world.draw_texture_rect(Art.ui("health_bg"),Rect2(48,560,90,8),false)
		world.draw_texture_rect(Art.ui("health_fill"),Rect2(48,560,90*s.hull/1000,8),false)

func draw_room(world: Control,s: Dictionary) -> void:
	var selected=s.streams[clampi(last_stream,0,s.streams.size()-1)]
	if s.time-last_land>3:
		for stream in s.streams:
			if stream.phase in ["outbound","unloading","returning"]:
				selected=stream
				break
	if selected.phase not in ["outbound","unloading","returning"]: return
	var progress=clampf(1-selected.remaining/maxf(1,selected.duration),0,1)
	var x=180.0
	var y=363.0
	var index=0
	if selected.phase=="outbound":
		x=lerpf(-230,180,progress)
		y=lerpf(180,363,progress)
	elif selected.phase=="unloading": index=1
	elif selected.phase=="returning":
		index=2
		x=lerpf(180,-240,progress)
		y=lerpf(363,160,progress)
	world.actor("room_transport",index,Vector2(x,y),158)
