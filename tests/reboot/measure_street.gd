extends SceneTree
var game: Control
var timings: Array = []
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1600,900)
	game=load("res://scenes/reboot/main.tscn").instantiate()
	root.add_child(game)
	game.transient=true
	game.start_street_preview()
	while not game.street_preview.ready_for_play: await process_frame
	await create_timer(3).timeout
	var previous=Time.get_ticks_usec()
	var end=previous+8000000
	while Time.get_ticks_usec()<end:
		await process_frame
		var now=Time.get_ticks_usec()
		timings.append((now-previous)/1000.0)
		previous=now
	timings.sort()
	var total=0.0
	for v in timings: total+=v
	var result={"gpu":RenderingServer.get_video_adapter_name(),"samples":timings.size(),"mean_ms":total/timings.size(),"p95_ms":timings[int(timings.size()*0.95)],"p99_ms":timings[int(timings.size()*0.99)],"max_ms":timings.back(),"texture_mib":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)/1048576.0,"resolution":"1600x900","scope":"8 seconds of live street scene after 3 second warmup, not minimum-spec certification"}
	var f=FileAccess.open("res://art/street-preview/live-performance.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(result,"  "))
	f.close()
	print("STREET LIVE ",JSON.stringify(result))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art/street-preview/captures/06-live.png")
	quit()
