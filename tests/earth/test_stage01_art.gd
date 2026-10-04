extends SceneTree
const Main=preload("res://scripts/earth/main.gd")
const Assets=preload("res://scripts/earth/assets.gd")
const Gait=preload("res://scripts/earth/gait.gd")
var n=0
var failures=0
func ck(ok: bool,label: String) -> void:
	n+=1
	if not ok: failures+=1;printerr("FAIL "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=Main.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.stage01_preview=true
	game.transient=true
	game.start_stage01_preview()
	var view=game.battlefield
	for role in range(5):
		for tier in range(1,4):
			ck(view.actor_path(role,tier).ends_with("temp-test/sprite_frames.tres"),"temporary fallback role %d tier %d"%[role,tier])
		var path=view.actor_path(role,1)
		var sprite=load(path) as SpriteFrames
		var metadata=JSON.parse_string(FileAccess.get_file_as_string(path.get_base_dir()+"/motion.json"))
		ck(metadata.temporary and metadata.keyframe_count==20,"honest temporary metadata")
		for action in {"idle":4,"move":8,"attack":4,"hit":2,"fall":3}:
			var count={"idle":4,"move":8,"attack":4,"hit":2,"fall":3}[action]
			ck(sprite.get_frame_count(action)==count,"complete "+action)
			ck(sprite.get_animation_loop(action)==(action in ["idle","move"]),"one-shot action semantics "+action)
			for frame in range(count):
				var tex=sprite.get_frame_texture(action,frame)
				ck(tex!=null and tex.get_size()==Vector2(432,320),"frame accessible and normalized")
		var stride=metadata.stride_pixels*215.0/metadata.native_height
		ck(Gait.frame(stride*.5,stride,8)==4 and Gait.frame(stride,stride,8)==0,"distance-paced cycle")
	for i in range(1,6):
		ck(Assets.path("battle.street.%d"%i)=="res://assets/earth/replacements/battle/street-%d.png"%i,"new street selected")
	ck(is_equal_approx(view.street_width(),10730.0*900/724),"panorama aspect preserved")
	for camera in [0.0,1800.0,2667.0,4900.0,8000.0,11738.4,20000.0]:
		var rects=view.street_rects(camera)
		ck(not rects.is_empty(),"street visible")
		ck(rects[0].rect.position.x<=0.01 and rects[-1].rect.end.x>=1599.99,"viewport covered")
		for i in range(rects.size()):
			ck(is_equal_approx(rects[i].rect.size.x/900,2146.0/724),"no background stretch")
			# Rect2 uses float32, so cancellation near x=0 can differ by 0.0002 px.
			if i>0:ck(absf(rects[i-1].rect.end.x-rects[i].rect.position.x)<.001,"no visible gap or overlap between tiles")
	var before=game.model.s.battle.units[0].x-game.model.s.battle.camera
	game.buttons.preview_segment_4.pressed.emit()
	ck(is_equal_approx(game.model.s.battle.camera,view.street_width()-1600),"jump to final street")
	ck(is_equal_approx(game.model.s.battle.units[0].x-game.model.s.battle.camera,before),"jump preserves party composition")
	game.buttons.pause.pressed.emit()
	var distance=game.model.s.battle.units[0].move_distance
	game._process(.1)
	ck(game.model.s.battle.units[0].move_distance==distance,"paused walking does not skate")
	game.model.recall()
	game.navigate("result")
	game.buttons.preview_restart.pressed.emit()
	ck(game.model.active() and game.view=="battle" and game.model.s.battle.stage==1,"test replay connected")
	ck(game.transient and not game.paused and game.model.s.battle.time==0,"replay is fresh and remains unsaved")
	print("STAGE01 ART ",n," checks / ",failures," failures")
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
