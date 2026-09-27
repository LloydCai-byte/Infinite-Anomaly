extends SceneTree
var game: Control
func _initialize() -> void: call_deferred("run")
func shot(name: String) -> void:
	game.render()
	await process_frame
	await game.capture(name+("-720p" if "--small" in OS.get_cmdline_user_args() else ""))
func run() -> void:
	root.size=Vector2i(1280,720) if "--small" in OS.get_cmdline_user_args() else Vector2i(1600,900)
	game=load("res://scenes/reboot/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	await shot("00-title")
	game.open("slots")
	await shot("01-slots")
	game.model.reset("第 07 号基地")
	game.view="base"
	game.page="intro"
	await shot("02-intro")
	game.model.s.intro_done=true
	game.page=""
	await shot("03-base")
	for p in ["missions","ready","profile","equipment","skills","training","printer","facility","cards","dialogue"]:
		game.page=p
		await shot("04-"+p)
	game.model.s.wins.M01=1
	game.model.s.wins.M02=1
	game.model.s.credits=3500
	game.model.s.alloy=30
	game.model.s.settings.large=true
	for p in ["profile","printer","settings"]:
		game.open(p)
		await shot("05-large-"+p)
	game.model.s.settings.large=false
	game.page=""
	game.perform("depart","M01")
	for i in range(130): game.model.tick(.05)
	game.model.events.clear()
	await shot("06-battle")
	game.page="stats"
	await shot("07-stats")
	game.page="recall"
	await shot("08-recall")
	game.page=""
	for i in range(5000):
		if not game.model.active(): break
		game.model.tick(.05)
		game.model.events.clear()
	game.page="result"
	await shot("09-result")
	game.view="base"
	game.page="pause"
	await shot("10-pause")
	game.page=""
	game.model.s.tier=2
	await shot("11-base-t2")
	game.model.depart("M02")
	game.view="battle"
	for i in range(220): game.model.tick(.05)
	game.model.events.clear()
	await shot("12-apartment")
	game.model.recall()
	game.model.depart("M03")
	for i in range(220): game.model.tick(.05)
	game.model.events.clear()
	await shot("13-overpass")
	print("REBOOT_CAPTURE complete")
	quit()
