extends SceneTree
const Home=preload("res://scripts/pixel_home/home.gd")
var out="res://docs/feedback-revision-20261028/verification/idle-vfx/"
var checks=[]
var home
func check(ok:bool,label:String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--feedback-test-output="):out=arg.trim_prefix("--feedback-test-output=").trim_suffix("/")+"/"
	root.size=Vector2i(1600,900);root.content_scale_size=Vector2i(1600,900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out));call_deferred("run")
func shot(name:String) -> void:
	home.battle.queue_redraw();await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out+name+".png")
func fresh():
	var b=home.battle.model;b.reset();b.start()
	for i in range(10):
		b.units[i].hp=10000;b.units[i].max_hp=10000;b.shields[i]=0
		for key in home.gear.G.AFFIX:b.stats_live[i][key]=0.0
		b.stats_live[i].powers=[]
	return b
func elements(b,target:int=-1) -> Array:
	return b.effects.filter(func(e):return e.kind=="element" and (target<0 or e.target==target)).map(func(e):return e.element)
func run() -> void:
	home=Home.new();root.add_child(home);await process_frame;await process_frame
	home.finish_intro();home.close_dialog();home.depart(0);home.battle.set_process(false)
	var view=home.battle
	for id in view.roster:
		if id not in view.Model.HERO_IDS and id not in view.Model.ENEMY_IDS:continue
		check(view.clip_path(id,"idle").ends_with("/base.png") and view.texture(view.clip_path(id,"idle")).get_size()==Vector2(160,144),id+" uses intact original plate for idle")
	var maximum_motion=0.0
	for n in range(120):maximum_motion=maxf(maximum_motion,(view.idle_stretch(n/120.0*2.8)-1)*88*view.BATTLE_ACTOR_SCALE)
	check(maximum_motion<2.1 and is_equal_approx(view.idle_stretch(0),view.idle_stretch(2.8)),"breathing is a continuous loop under 2.1 screen pixels at fixed foot")
	for n in range(12):
		for unit in view.model.units:unit.anim="idle";unit.anim_time=n*2.8/12
		await shot("idle-%02d"%n)
	for element in ["fire","cold","lightning"]:
		var b=fresh();b.stats_live[0][element]=24;b.damage(0,5,100,"melee")
		check(b.units[5].hp==9876 and elements(b,5).has(element),element+" affix: real 124 damage and matching effect")
	var b=fresh();b.stats_live[0].fire=24;b.stats_live[5].dodge=100;b.damage(0,5,100,"melee")
	check(b.units[5].hp==10000 and elements(b,5).is_empty(),"dodge has no false elemental hit effect")
	b=fresh();b.stats_live[0].fire=24;b.stats_live[5].resist=100;b.damage(0,5,100,"melee")
	check(b.units[5].hp==9900 and elements(b,5).is_empty(),"fully resisted affix has no false fire effect")
	b=fresh();b.stats_live[0].lightning=24;b.shields[5]=200;b.damage(0,5,100,"melee")
	check(b.units[5].hp==10000 and b.shields[5]==76 and elements(b,5).has("lightning"),"shield absorption still shows actual lightning contact")
	b=fresh();b.stats_live[0].fire=24;b.stats_live[5].thorns=12;b.damage(0,5,100,"melee")
	check(elements(b,0).is_empty(),"reflected thorns is not mislabeled as source fire")
	b=fresh();b.stats_live[0].poison=10;b.damage(0,5,100,"melee")
	check(b.dots[5]==10 and elements(b,5).has("poison"),"actual poison application is visible")
	b.effects=[];var before=b.units[5].hp;b.begin_action(5)
	check(b.units[5].hp<before and elements(b,5).has("poison"),"actual poison tick is visible")
	b=fresh();b.stats_live[4].lightning=24;b.damage(4,5,100,"burn")
	check(elements(b,5)==["fire"],"burn tick shows fire without falsely reapplying lightning")
	b=fresh()
	for n in range(5):
		var element=["fire","lightning","cold","poison","fire"][n]
		b.stats_live[n][element]=24;b.damage(n,n+5,100,"melee")
	for e in b.effects:e.age=.12
	await shot("confirmed-elements")
	var counts=b.effects.filter(func(e):return e.kind=="element").size();view.paused=true;view._process(.2)
	check(b.effects.filter(func(e):return e.kind=="element").size()==counts and b.effects.all(func(e):return e.age==.12),"pause freezes elemental animation")
	home.finish_return();home.close_dialog();home.queue_free();await process_frame
	var failed=checks.filter(func(c):return not c.pass)
	var file=FileAccess.open(out+"verification.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failed":failed.size()},"  "));file.close()
	print("FEEDBACK_EFFECTS ",checks.size()," checks, ",failed.size()," failures");quit(0 if failed.is_empty() else 1)
