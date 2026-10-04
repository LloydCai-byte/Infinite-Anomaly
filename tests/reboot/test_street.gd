extends SceneTree
const StreetModel = preload("res://scripts/reboot/street_model.gd")
var checks = 0
var failures = 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("STREET FAIL: "+label)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var m = StreetModel.new()
	check(m.alive(0).size()==4 and m.remaining()==13,"fixed population, no wave spawner")
	check(m.units.back().boss and m.units.back().x>12000,"boss at end of full panorama")
	var old_camera = 0.0
	var monotonic = true
	for i in range(60*360):
		m.tick(1.0/60)
		m.events.clear()
		monotonic = monotonic and m.camera_x+0.001>=old_camera
		old_camera = m.camera_x
		if m.result!="": break
	print("STREET NATURAL RUN: ",m.result," time=",m.elapsed," remaining=",m.remaining()," living=",m.alive(0).size()," camera=",m.camera_x)
	check(m.result=="victory" and m.remaining()==0,"unassisted full street completes")
	check(monotonic and m.camera_x>11000 and m.camera_x<=StreetModel.LENGTH-1600,"camera travels full map without overshooting")
	for kind in ["male-heavy","pale-hair-katana","bull-spider"]:
		for state in ["idle","move","attack","hit"]:
			check(m.seen_states.has(kind+"/"+state),kind+" played "+state)
	for kind in ["pale-hair-katana","bull-spider"]:
		check(m.seen_states.has(kind+"/fall"),kind+" death animation")
	m.restart()
	var before = m.units[0].hp
	m.invincible = true
	m.hit(m.units[4],m.units[0])
	check(m.units[0].hp==before,"F1 all allies protected")
	m.invincible = false
	m.units[4].damage = 9999
	m.hit(m.units[4],m.units[0])
	check(m.units[0].hp==0 and m.units[0].anim=="fall","ally death uses fall")
	m.paused = true
	var time_before = m.elapsed
	m.tick(1)
	check(m.elapsed==time_before,"pause freezes simulation")
	m.jump_to_boss()
	check(m.remaining()==1 and m.alive(0).size()==4 and m.skipped==12,"boss shortcut skips prior enemies and resets allies")
	for i in range(60*120):
		m.tick(1.0/60)
		m.events.clear()
		if m.result!="": break
	check(m.result=="victory","boss shortcut can finish")
	var game = load("res://scenes/reboot/main.tscn").instantiate()
	root.add_child(game)
	game.transient = true
	game.model.s.intro_done = true
	game.model.depart("M01")
	game.view = "base"
	game.render()
	game.set_process(false)
	var saved = game.model.s.duplicate(true)
	game.start_street_preview()
	var preview = game.street_preview
	var deadline = Time.get_ticks_msec()+30000
	while not preview.ready_for_play and Time.get_ticks_msec()<deadline:
		await process_frame
	check(preview.ready_for_play,"all runtime resources load")
	if preview.ready_for_play:
		preview.set_process(false)
		check(preview.sheets.size()==3 and preview.tiles.size()==5,"three shared SpriteFrames and five panorama tiles")
		for frames in preview.sheets.values():
			for state in ["idle","move","attack","hit","fall"]:
				check(frames.has_animation(state) and frames.get_animation_speed(state)==60,"60fps animation available")
		game._process(1.0)
		check(game.model.s==saved and game.is_paused(),"trial leaves campaign state untouched")
		var key = InputEventKey.new()
		key.keycode = KEY_F1
		key.pressed = true
		game._input(key)
		check(preview.model.invincible and not game.model.invincible,"F1 applies locally to street trial")
		key.keycode = KEY_SPACE
		game._input(key)
		check(preview.model.paused,"space pauses trial")
		preview.controls.boss.pressed.emit()
		check(preview.model.remaining()==1,"boss button works")
		preview.controls.restart.pressed.emit()
		check(preview.model.remaining()==13 and preview.model.result=="","restart button works")
		preview.controls.speed.pressed.emit()
		check(preview.model.speed==2,"speed button works")
		preview.controls.exit.pressed.emit()
		check(game.street_preview==null and game.view=="base" and game.world.visible,"return restores game")
		check(game.model.s==saved,"return never changes save state")
	game.queue_free()
	await process_frame
	print("STREET TEST ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
