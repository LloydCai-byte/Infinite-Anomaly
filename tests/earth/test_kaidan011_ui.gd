extends SceneTree
const Main=preload("res://scripts/earth/main.gd")
const C=preload("res://scripts/earth/catalog.gd")
const OUT="D:/无限异常/art/earth-production/kaidan-integration-011/captures/"
const DOC="D:/无限异常/docs/kaidan-integration-011/"
var game: Control
var checks=0
var failures=0
var shots=[]
var suffix="source"
func _initialize() -> void:call_deferred("run")
func ck(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL "+label)
func click(id: String) -> void:
	ck(game.buttons.has(id),"control "+id)
	var p=game.buttons[id].get_global_rect().get_center()
	var factor=Vector2(root.size)/Vector2(1600,900)
	p*=factor
	var motion=InputEventMouseMotion.new();motion.position=p;root.push_input(motion)
	var e=InputEventMouseButton.new();e.position=p;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true
	root.push_input(e);await process_frame
	e=e.duplicate();e.pressed=false;root.push_input(e);await process_frame
func shot(name: String) -> void:
	game.battlefield.sync_anomaly_units();game.battlefield.queue_redraw();game.refresh_battle()
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	var im=root.get_texture().get_image();im.save_png(OUT+suffix+"-"+name+".png")
	shots.append({"name":name,"size":[im.get_width(),im.get_height()]})
func run() -> void:
	if "--packaged" in OS.get_cmdline_user_args():suffix="package"
	if "--earth-kaidan-preview" in OS.get_cmdline_user_args():suffix="preview-entry"
	root.size=Vector2i(1600,900)
	game=Main.new();root.add_child(game);game.transient=true
	await process_frame;await process_frame
	game.set_process(false)
	if suffix=="preview-entry":ck(game.kaidan_preview and game.model.active() and game.model.s.battle.stage==301,"actual CMD preview flag reaches new battle")
	game.kaidan_preview=false;game.model.reset();game.model.s.intro_done=true;game.navigate("base")
	await click("depart");await click("kaidan_missions")
	ck(game.view=="missions" and game.selected_stage==301,"black door has real new missions")
	ck(not game.buttons.open_portal.disabled and game.model.s.max_stage==1,"new entries do not require completing old campaign")
	await shot("portal-hasshaku")
	await click("mission302");await shot("portal-kuchisake")
	await click("open_portal");await create_timer(1.1).timeout
	ck(game.view=="battle" and game.model.s.battle.stage==302,"door transition enters selected anomaly")
	for stage in [301,302]:
		game.kaidan_preview=true;game.start_kaidan_preview(stage)
		var info=C.Anomalies.info(stage)
		for i in range(5):
			game.preview_anomaly_segment(i)
			ck(game.battle_labels.scene.text==info.scenes[i].name,"section title follows actual encounter")
			var tiles=game.battlefield.anomaly_rects(stage,game.model.s.battle.camera)
			ck(not tiles.is_empty() and tiles[0].rect.position.x<=.01 and tiles[-1].rect.end.x>=1599.99,"viewport fully covered")
			for n in range(tiles.size()):
				var tex=tiles[n].texture
				ck(absf(tiles[n].rect.size.x/900.0-float(tex.get_width())/tex.get_height())<.0001,"native aspect retained")
				if n>0:ck(absf(tiles[n-1].rect.end.x-tiles[n].rect.position.x)<.002,"tiles have no gap")
			await shot("%d-section-%d"%[stage,i+1])
		# Native engine render of all designs and both authored poses at game scale.
		game.preview_anomaly_segment(1)
		var b=game.model.s.battle
		for i in range(5):
			var u=b.units[i+5];u.x=b.camera+800+i*155;u.lane=680+(i%2)*60;u.variant=i;u.facing=-1.0
			for action in ["idle","attack"]:
				var pose=info.enemies[i].poses[action];ck(ResourceLoader.exists(pose.path),"pose in runtime pack")
		for action in ["idle","attack"]:
			for u in b.units.slice(5):u.state=action;u.anim=.18
			await shot("%d-all-%s"%[stage,action])
			for node in game.battlefield.unit_nodes.values():
				if node.unit.side==1:ck(node.sprite.material!=null and node.body.scale.x<0,"chroma shader and leftward combat facing")
		game.start_kaidan_preview(stage)
		for i in range(60*10):
			game.model.tick(1.0/60)
			if game.model.s.battle.time>4 and not game.model.alive(1).is_empty() and game.model.alive(0).any(func(u):return u.state=="attack"):break
		await shot("%d-natural-combat"%stage)
		ck(game.model.active(),"natural battle still progressing")
		await click("pause");var t=game.model.s.battle.time;game._process(.2)
		ck(game.paused and game.model.s.battle.time==t,"pause freezes simulation")
		await click("pause")
		for i in range(60*600):
			game.model.tick(1.0/60)
			if not game.model.active():break
		game.navigate("result");await shot("%d-victory"%stage)
		ck(game.model.s.result.reason=="victory" and game.model.s.result.killed==25,"UI route completes all five sections")
		ck(game.buttons.continue_next.disabled==(stage==302),"correct next anomaly availability")
		if stage==301:
			await click("continue_next");ck(game.model.s.battle.stage==302,"next anomaly actual click")
		else:
			await click("repeat");ck(game.model.s.battle.stage==302,"repeat actual click")
			await click("recall");await click("return");ck(game.view=="base","return home actual click")
	game.kaidan_preview=true;game.start_kaidan_preview(301);game.preview_anomaly_segment(2)
	for resolution in [Vector2i(2560,1440),Vector2i(3840,2160)]:
		root.size=resolution;await process_frame;await shot("viewport-%dx%d"%[resolution.x,resolution.y])
		# ViewportTexture reports the logical content size under canvas scaling;
		# the GPU readback above records the actual rendered pixel dimensions.
		ck(shots[-1].size==[resolution.x,resolution.y],"actual GPU render resolution")
		for button in game.buttons.values():ck(Rect2(0,0,1600,900).encloses(button.get_global_rect()),"UI inside logical viewport")
	var f=FileAccess.open(DOC+suffix+"-ui-test.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures,"version":ProjectSettings.get_setting("application/config/version"),"screenshots":shots,"capture_note":"section/pose images use preview positioning; natural-combat images use unmodified simulation; no claim of native HD artwork"},"  "));f.close()
	print("KAIDAN 011 UI ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
