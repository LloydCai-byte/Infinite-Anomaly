extends SceneTree
const Home=preload("res://scripts/pixel_home/home.gd")
var home
var checks=[]
var out=""
var trace=[]
func check(ok:bool,label:String)->void:
	checks.append({"pass":ok,"name":label})
	if not ok:push_error(label)
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shadow-output="):out=arg.trim_prefix("--shadow-output=").trim_suffix("/")+"/"
	if out.is_empty():quit(2);return
	DirAccess.make_dir_recursive_absolute(out);root.size=Vector2i(1600,900);root.content_scale_size=Vector2i(1600,900);call_deferred("run")
func shot(name:String)->void:
	home.queue_redraw();home.battle.queue_redraw();await process_frame;await process_frame;await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(out+name+".png")==OK,"capture "+name)
func run()->void:
	home=Home.new();home.profile_override=out+"isolated.json";root.add_child(home)
	await process_frame;await process_frame;home.finish_intro();home.close_dialog();home.set_process(false);home.arrival=0
	var v=home.battle;v.set_process(false);v.sound_enabled=false;v.auto_next=false;home.mode="battle";home.ui.hide();v.show()
	v.begin_level(14);v.set_process(false);v.enemy_arrival.active=false;v.travel.active=false;v.visual_clock=0
	var m=v.model;var shadows=v.ground_shadows
	check(shadows.data.actors.size()==10,"all five heroes and five existing monsters calibrated")
	for path in shadows.data.source_hashes:check(FileAccess.get_sha256(path)==shadows.data.source_hashes[path],"profile matches unchanged source art: "+path)
	var total=0
	for actor in shadows.data.actors:
		var source=m.units.filter(func(u):return u.id==actor)[0]
		var unit=source.duplicate(true);unit.hit_time=0;unit.hp=100;unit.dead_time=0
		var profile=shadows.data.actors[actor]
		check(profile.standing.size()==(1 if actor=="umbrella" else 2),"actual foot count "+actor)
		for clip in profile.clips:
			var valid=true;var frames=profile.clips[clip];var spec=v.roster[actor].clips[clip]
			var image=Image.load_from_file("res://art/pixel-hyakki-level-20261024/sprites/"+actor+"/"+("base" if clip=="idle" else clip)+".png")
			for i in range(frames.size()):
				unit.anim=clip;unit.anim_time=(i+.1)/float(spec.fps);var g=shadows.geometry(v,unit);total+=1
				valid=valid and g.pose.frame==i and g.center.is_finite() and g.radii.x>g.radii.y
				for foot in frames[i]:
					# Check opaque sole pixels in the actual packed frame, independently of screen geometry.
					var x0=int(i)%int(spec.columns)*160;var y0=int(i)/int(spec.columns)*144
					var found=false
					for x in range(int(foot.x-foot.width*.5),int(ceil(foot.x+foot.width*.5))):
						if image.get_pixel(x0+x,y0+int(foot.y)-1).a>=.5:found=true
					valid=valid and found and foot.width>=3 and foot.width<40
				for c in g.contacts:valid=valid and c.point.is_finite() and c.strength>=0 and c.strength<=1
			check(valid,"packed sole landmarks and matching animation frames: "+actor+"/"+clip)
		unit.anim="idle";unit.anim_time=0
		var ground=shadows.geometry(v,unit);var shifted=unit.duplicate(true);shifted.pos+=Vector2(120,80)
		check(shadows.geometry(v,shifted).center.is_equal_approx(ground.center+Vector2(120,80)),"shadow follows actor movement: "+actor)
		check(shadows.geometry(v,unit,0).is_empty(),"invisible actor has no residual shadow: "+actor)
		unit.anim="die";unit.hp=0;unit.dead_time=.6;var fading=shadows.geometry(v,unit)
		check(is_equal_approx(fading.opacity,.5) and fading.contacts.all(func(c):return c.strength==0),"corpse fades without standing contact marks: "+actor)
		unit.dead_time=1.2;check(shadows.geometry(v,unit).is_empty(),"vanished corpse has no shadow: "+actor)
	check(total==510,"all 510 authored idle walk attack and hurt poses covered")
	for actor in ["fenfen","wang","oni"]:
		var u=m.units.filter(func(row):return row.id==actor)[0];u.anim="idle";u.anim_time=0;u.hit_time=0
		var g=shadows.geometry(v,u)
		check(g.center.x<u.pos.x-12 and g.radii.x>35,"asymmetric feet correct the right-shifted old blob: "+actor)
	var umbrella=m.units.filter(func(u):return u.id=="umbrella")[0].duplicate(true);umbrella.anim="walk";umbrella.hit_time=0
	var lifted=false
	for i in range(shadows.data.actors.umbrella.clips.walk.size()):
		umbrella.anim_time=(i+.1)/float(v.roster.umbrella.clips.walk.fps);var g=shadows.geometry(v,umbrella)
		if g.airborne>0 and g.contacts[0].strength==0:lifted=true
	check(lifted,"hopping umbrella loses foot contact while broad shadow remains on ground")
	var before=var_to_bytes(m.units)
	for u in m.units:shadows.geometry(v,u)
	check(before==var_to_bytes(m.units),"shadow sampling does not mutate battle state")
	var actor=m.units[0];actor.hit_time=.2;actor.anim="walk";m.action={}
	check(shadows.pose(v,actor).clip=="hurt","hit overlay and shadow select the same pose")
	m.action={"actor":actor.uid};check(shadows.pose(v,actor).clip=="walk","acting character keeps its action pose during hit overlay");m.action={};actor.hit_time=0
	v.paused=true;before=var_to_bytes(m.units);v._process(.1)
	check(before==var_to_bytes(m.units),"pause holds animation and shadow footprint")
	v.paused=false;v.open_equipment();before=var_to_bytes(m.units);v._process(.1)
	check(before==var_to_bytes(m.units),"equipment freezes animation and footprint");v.close_equipment()
	v.enemy_arrival.begin();var enemy=m.units[5]
	check(shadows.geometry(v,enemy,v.enemy_arrival.alpha(1)).is_empty(),"monster arrival starts without detached shadow")
	v.enemy_arrival.elapsed=.45;check(is_equal_approx(shadows.geometry(v,enemy,v.enemy_arrival.alpha(1)).opacity,v.enemy_arrival.alpha(1)),"arrival shadow fades with monster")
	v.enemy_arrival.active=false
	var palettes=[]
	for index in [14,0,13]:
		v.begin_level(index);v.set_process(false);v.enemy_arrival.active=false;v.travel.active=false;v.visual_clock=0
		palettes.append(shadows.palette(m.scene_info().image).color)
		for u in m.units:u.anim="idle";u.anim_time=0;u.pos=u.home;u.hit_time=0
		await shot("room-%02d-idle"%(index+1))
		if index==14:
			for clip in ["walk","attack","hurt"]:
				for u in m.units:u.anim=clip;u.anim_time=(4.0 if clip=="walk" else 10.0 if clip=="attack" else 2.0)/float(v.roster[u.id].clips[clip].fps)
				await shot("room-15-"+clip)
			for u in m.units:u.anim="die";u.anim_time=.4;u.hp=0;u.dead_time=.4
			await shot("room-15-die")
	check(palettes[0]!=palettes[2],"warm ground and cold ground use different shadow palettes")
	v.begin_level(14);v.set_process(false);v.enemy_arrival.active=false;v.speed=3
	var last=Time.get_ticks_usec()
	for i in range(180):
		v._process(1.0/60);await process_frame;await RenderingServer.frame_post_draw
		var now=Time.get_ticks_usec();trace.append((now-last)/1000.0);last=now
		if m.phase!="fight":v.begin_level(14);v.set_process(false);v.enemy_arrival.active=false
	check(m.time>0,"live combat advances with shadows at triple speed")
	trace.sort();var failures=checks.filter(func(row):return not row.pass)
	var report={"checks":checks,"failures":failures,"poses":total,"normal_profile_used":false,"render_trace":{"frames":trace.size(),"median_ms":trace[90],"p95_ms":trace[171],"maximum_ms":trace[-1],"scope":"short isolated native combat trace; not long-session performance validation"}}
	var f=FileAccess.open(out+"verification.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close()
	print("GROUND_SHADOWS ",checks.size()," checks ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
