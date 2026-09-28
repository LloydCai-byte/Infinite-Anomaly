extends SceneTree
const Model=preload("res://scripts/reboot/model.gd")
const C=preload("res://scripts/reboot/catalog.gd")
var checks=0
var failures=0
var game: Control

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("INVINCIBILITY FAIL: "+label)

func models() -> void:
	var m=Model.new()
	check(not m.invincible,"off by default")
	m.depart("M01")
	m.spawn_wave()
	m.invincible=true
	var enemy=m.alive(1)[0]
	for ally in m.alive(0):
		ally.shield=25
		ally.hp-=10
		var before=ally.duplicate(true)
		m.hit(enemy,ally,1e12,.5)
		check(ally==before and m.s.battle.stats[ally.role].taken==0,"all roles immune, shield and health preserved")
	var enemy_hp=enemy.hp
	m.hit(m.alive(0)[1],enemy,30)
	check(enemy.hp<enemy_hp,"enemies still take damage")
	m.invincible=false
	var target=m.alive(0)[0]
	var hp=target.hp
	m.hit(enemy,target,100)
	check(target.hp<hp,"turning off restores ordinary damage")
	m.hit(enemy,target,1e12)
	m.invincible=true
	check(target.hp==0,"enabling is not resurrection")
	for i in range(100): m.tick(.05)
	check(target.hp==0,"already fallen teammate stays fallen")
	var loaded=Model.new()
	check(loaded.import_state(m.s) and not loaded.invincible,"session flag never enters save data")
	# The shared model creates a new war wrapper every tick, so the toggle must
	# follow each wrapper, including after handoff and subsequent room deliveries.
	m=Model.new()
	for mission in C.MISSIONS: m.s.wins[mission.id]=8
	m.s.reveal_read=true
	m.invincible=true
	check(m.graduate() and m.war_model().invincible,"handoff keeps session switch")
	for i in range(125): m.tick(.1);m.events.clear()
	var war=m.war_model()
	check(war.soldiers()==4,"original four land")
	var original_army=war.s.army.duplicate(true)
	war.damage_army(1e12,war.s.army)
	check(war.s.army==original_army and war.s.dead==0,"all original warriors immune")
	for i in range(250): m.tick(.1);m.events.clear()
	war=m.war_model()
	check(war.soldiers()>4 and war.s.dead==0,"new deliveries also immune across ticks")
	var army=war.s.army.duplicate(true)
	war.damage_army(1e18,war.s.army)
	check(war.s.army==army and war.conservation(),"entire aggregate army immune, population conserved")
	m.invincible=false
	war=m.war_model()
	var original=war.s.army.filter(func(a): return a.named and a.count>0)[0]
	war.damage_army(1e12,[original])
	war.update_originals()
	check(original.count==0 and war.s.dead==1 and war.s.memorial.size()==1,"off restores permanent casualty accounting")
	m.invincible=true
	war=m.war_model()
	war.damage_army(1e18,war.s.army)
	war.update_originals()
	check(original.count==0 and war.s.dead==1 and war.conservation(),"reenabling preserves prior permanent death")

func key(pressed: bool, echo=false) -> void:
	var event=InputEventKey.new()
	event.keycode=KEY_F1
	event.pressed=pressed
	event.echo=echo
	root.push_input(event,true)
	await process_frame

func shot(name: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	await process_frame
	await RenderingServer.frame_post_draw
	var dir="res://art/reboot-fixes/invincibility/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	check(root.get_texture().get_image().save_png(dir+name+".png")==OK,"capture "+name)

func _initialize() -> void: call_deferred("run")
func run() -> void:
	models()
	root.size=Vector2i(1280,720)
	game=load("res://scenes/reboot/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.world.set_process(false)
	game.transient=true
	await process_frame
	game.open("newsave",{"slot":1})
	game.ui.form.text="正在编辑的基地名"
	game.ui.form.grab_focus()
	await key(true)
	check(game.model.invincible and game.overlay.has_node("invincibility_indicator"),"F1 works even with focused text input")
	check(game.ui.form.text=="正在编辑的基地名" and game.ui.form.has_focus(),"F1 preserves input draft and keyboard focus")
	await key(true,true)
	check(game.model.invincible,"key repeat does not toggle repeatedly")
	await key(false)
	check(game.model.invincible,"key release does not toggle")
	await key(true)
	check(not game.model.invincible and not game.overlay.has_node("invincibility_indicator"),"second press disables and removes indicator")
	await key(false)
	game.model.s.intro_done=true
	game.model.s.settings.large=true
	game.view="base"
	game.page=""
	game.render()
	game.perform("depart","M01")
	await key(true)
	await key(false)
	for i in range(60): game.model.tick(.05)
	game.render()
	check(game.model.invincible and game.view=="battle","F1 enables mid-battle")
	await shot("training-720p-large")
	game.open("pause")
	await key(true)
	await key(false)
	check(not game.model.invincible and game.page=="pause","toggle while paused preserves menu")
	game.model.recall()
	for mission in C.MISSIONS: game.model.s.wins[mission.id]=8
	game.model.s.reveal_read=true
	game.perform("graduate")
	await key(true)
	await key(false)
	for i in range(125): game.model.tick(.1)
	game.render()
	check(game.view=="war" and game.model.war_model().invincible and game.overlay.has_node("invincibility_indicator"),"war hotkey and persistent indicator")
	await shot("war-720p-large")
	await key(true)
	await key(false)
	check(not game.model.war_model().invincible,"war off propagates to next simulation wrapper")
	print("INVINCIBILITY: ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
