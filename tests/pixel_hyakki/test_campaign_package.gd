extends SceneTree
const View=preload("res://scripts/pixel_hyakki/view.gd")
class ActorsOnly extends View:
	func _draw()->void:
		if roster.is_empty():return
		var ordered=model.units.duplicate();ordered.sort_custom(func(a,b):return a.pos.y<b.pos.y)
		for unit in ordered:draw_actor(unit)

var v
var failures:Array=[]
var checks=0
var captures=[]
var actor_layer_hashes=[]
var capture_dir="res://art/pixel-first-two-levels-20261025/captures"
var report_path="res://docs/pixel-first-two-levels-20261025/visual-verification.json"

func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)

func _initialize()->void:call_deferred("run")

func click_at(point:Vector2)->void:
	var motion=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;root.push_input(motion)
	var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=point;event.global_position=point;event.pressed=true;root.push_input(event)
	event=event.duplicate();event.pressed=false;root.push_input(event)
	await process_frame;await process_frame

func press(id:String)->void:
	check(v.controls.has(id),"control "+id)
	if v.controls.has(id):await click_at(v.controls[id].get_global_rect().get_center())

func capture(name:String)->void:
	v.queue_redraw();await process_frame;await process_frame;await RenderingServer.frame_post_draw
	var path=capture_dir.path_join(name+".png")
	var image=root.get_texture().get_image()
	check(image.save_png(path)==OK,"capture "+name)
	captures.append({"name":name,"file":path,"size":[image.get_width(),image.get_height()]})

func clear_enemies()->void:
	for u in v.model.units.slice(5):v.model.damage(-1,u.uid,u.max_hp+100,"test")
	v.model.advance(.1);v.prev_phase="";v._process(.01)
	await process_frame;await process_frame

func verify_identical_actor_layers()->void:
	var viewport=SubViewport.new();viewport.size=Vector2i(1600,900);viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var probe=ActorsOnly.new();probe.save_disabled=true;probe.event_audio=false;viewport.add_child(probe)
	await process_frame;probe.set_process(false);probe.ui.hide()
	var reference_bytes=PackedByteArray()
	# Render the actual actor draw routine on a transparent viewport, without scenery/UI.
	# Every unit must occupy exactly the same pixels as it does in the approved theatre.
	for index in [1]+range(20):
		probe.model.reset(0 if index<10 else 1);probe.model.stage=index;probe.model.spawn_stage()
		probe.queue_redraw();await process_frame;await process_frame;await RenderingServer.frame_post_draw
		var image=viewport.get_texture().get_image();var pixels=image.get_data()
		if reference_bytes.is_empty():
			reference_bytes=pixels
			image.save_png(capture_dir.path_join("theatre-actor-layer.png"))
		else:
			check(pixels==reference_bytes,"rendered actor pixels identical to theatre, scene "+str(index+1))
			var hash=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(pixels)
			actor_layer_hashes.append({"scene":index+1,"sha256":hash.finish().hex_encode()})
	viewport.queue_free();await process_frame

func run()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):capture_dir=arg.trim_prefix("--capture-dir=")
		if arg.begins_with("--report="):report_path=arg.trim_prefix("--report=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture_dir))
	root.size=Vector2i(1600,900);root.content_scale_size=Vector2i(1600,900)
	v=View.new();v.save_disabled=true;v.event_audio=false;root.add_child(v);await process_frame;await process_frame;v.set_process(false)
	check(v.model.stage_count()==20 and v.model.level_count()==2,"runtime loads twenty scenes")
	check(v.roster.size()==10,"existing five heroes and five monsters")
	await capture("level-select")
	await press("start");check(v.model.stage==0 and v.model.phase=="fight","first level mouse start")
	await press("pause");var frozen=v.model.time;v._process(.08);check(v.paused and v.model.time==frozen,"pause freezes battle")
	await press("pause");v._process(.08);check(not v.paused and v.model.time>frozen,"resume advances battle")
	await press("speed");check(v.speed==2.0,"speed two")
	await press("speed");check(v.speed==3.0,"speed three")
	await press("speed");check(v.speed==1.0,"speed wraps")
	await press("equipment");check(v.screen=="equipment" and v.paused,"equipment remains accessible and pauses")
	frozen=v.model.time;v._process(.08);check(v.model.time==frozen,"equipment freezes battle")
	await click_at(Vector2(1469,51));check(v.screen=="battle" and not v.paused,"equipment return restores state")
	await press("auto_next");check(not v.auto_next,"manual progression switch")
	v.model.stage=9;v.model.spawn_stage();await clear_enemies()
	check(v.model.phase=="clear" and v.model.is_level_end(),"first level has transition instead of final victory")
	v._process(.1);check(v.model.stage==9,"manual clear waits")
	await capture("level-1-clear")
	await press("next");check(v.model.stage==10 and v.model.level_index()==1,"mouse transition into second level")
	v.model.stage=19;v.model.spawn_stage();await clear_enemies()
	check(v.model.phase=="victory" and v.model.stage==19,"second level final settlement")
	await capture("level-2-clear")
	await press("again");check(v.model.phase=="ready" and v.model.stage==10,"retry preserves selected level")
	await press("start_level_2");check(v.model.stage==10 and v.model.phase=="fight","direct second level mouse start")
	await press("auto_next");check(v.auto_next,"automatic progression enabled")
	v.model.stage=9;v.model.spawn_stage();v.paused=false;await clear_enemies()
	for i in range(34):v._process(.1)
	check(v.model.stage==10,"automatic level boundary transition")
	v.paused=true
	for index in range(20):
		v.model.reset(0 if index<10 else 1);v.model.stage=index;v.model.spawn_stage();v.build_controls()
		var info=v.model.scene_info()
		check(v.texture(info.image)!=null,"runtime texture "+info.id)
		for unit in v.model.units:check(unit.home.y>info.floor_y and unit.home.y<800,"feet on combat apron "+info.id+"/"+unit.id)
		await capture("scene-%02d"%(index+1))
	await verify_identical_actor_layers()
	var result={"checks":checks,"failures":failures,"renderer":RenderingServer.get_video_adapter_name(),"textures":v.textures.size(),"level_count":2,"scene_count":20,"mouse_interaction":true,"normal_save_disabled":v.save_disabled,"captures":captures,"actor_layer_hashes":actor_layer_hashes}
	var file=FileAccess.open(report_path,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify(result,"  "));file.close()
	print("FIRST TWO VISUAL ",JSON.stringify({"checks":checks,"failures":failures,"captures":captures.size(),"textures":v.textures.size(),"renderer":result.renderer}));quit(0 if failures.is_empty() else 1)
