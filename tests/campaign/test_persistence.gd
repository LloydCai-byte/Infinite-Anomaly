extends SceneTree
const Model = preload("res://scripts/campaign/model.gd")
const Store = preload("res://scripts/home/checkpoints.gd")
const BASE = "res://.local/campaign-persistence/"
var checks = 0
var failures = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL PERSISTENCE: " + message)

func _initialize() -> void: call_deferred("run")

func write_fixture(m, name: String) -> void:
	check(Model.new().restore(m.s), "fixture is valid: " + name)
	check(Store.new(BASE + name + ".json").save(m.s), "write: " + name)

func run() -> void:
	var journey = root.get_node("Journey")
	journey.set_process(false)
	journey.transient = false
	journey.storehouse = Store.new(BASE + "timer.json")
	journey.started = true
	journey.model.new_game()
	journey.s.intro = true
	if "--write" in OS.get_cmdline_user_args():
		var m = Model.new()
		m.s.intro = true
		write_fixture(m,"HOME")
		m.depart(); m.observe(0); m.tick(4)
		write_fixture(m,"EXPLORE")
		m.observe(1); m.attempt("perception")
		write_fixture(m,"RESULT")
		m.return_home(); m.select_node(0); m.depart(true); m.tick(6)
		write_fixture(m,"AUTO")
		m.withdraw(); m.select_node(1); m.depart(true)
		write_fixture(m,"WAIT")
		m.new_game(); m.s.intro=true
		m.s.skills={"perception":6,"combat":6,"survival":6}
		for i in 9:
			m.select_node(i); m.depart(); m.observe(0); m.observe(1); m.tick(3); m.attempt("perception")
			if i<8: m.return_home()
		write_fixture(m,"ENDING")
		journey.since_save=1199.4
		journey._process(0.5)
		check(journey.since_save>1199,"does not save before 20 active minutes")
		journey._process(0.2)
		check(journey.since_save==0 and journey.storehouse.read_latest().mode=="HOME","autosave at 20 minutes")
		journey.paused=true
		var food=journey.s.food
		journey._process(7200)
		check(journey.s.food==food and journey.since_save==0,"pause consumes neither resources nor save interval")
		journey.paused=false
		check(journey.model.restore(Store.new(BASE+"WAIT.json").read_latest()),"session restores waiting checkpoint")
		food=journey.s.food
		journey._process(7200)
		check(journey.s.food==food and journey.since_save==0,"unknown scene wait consumes no resources or save interval")
	else:
		for name in ["HOME","EXPLORE","RESULT","AUTO","WAIT","ENDING"]:
			var state=Store.new(BASE+name+".json").read_latest()
			var m=Model.new()
			check(m.restore(state),"cross-process restore: "+name)
			check(m.s.mode==name,"preserves phase: "+name)
			check(m.s.food==state.food and m.s.xp==state.xp,"no offline consumption or reward: "+name)
			if name=="EXPLORE":
				check(m.s.observed==["0"] and m.s.timer==4,"preserves inspected clues and elapsed time")
				m.observe(1); check(m.attempt("perception").won,"restored exploration can settle")
			if name=="AUTO":
				check(m.tick(9)=="result" and m.s.result.won,"auto continues from remaining time")
				check(m.s.result.xp==3,"restored repeat rewards only once")
			if name=="WAIT":
				check(m.take_control() and m.s.selected==1,"waiting can resume manually")
			if name=="RESULT":
				var xp=m.s.xp
				check(m.settle("perception").is_empty() and xp==m.s.xp,"loading result never pays twice")
			if name=="ENDING": check(m.s.memories.size()==9,"complete memory collection survives restart")
		journey.storehouse=Store.new(BASE+"recovery.json")
		check(journey.persist(),"save valid recovery base")
		journey.s.xp=13
		check(journey.persist(),"save recent recovery base")
		var broken=journey.s.duplicate(true)
		broken.memories={"0":{"won":true,"route":"missing"}}
		check(journey.storehouse.save(broken),"create correctly checksummed but structurally invalid checkpoint")
		check(journey.reload_checkpoint() and journey.s.xp==13,"session rejects nested corruption and loads valid backup")
		var checksum=FileAccess.get_file_as_string(journey.storehouse.path).sha256_text()
		journey.s.food=0; journey.s.mode="GAMEOVER"
		check(not journey.persist(),"death cannot save")
		check(FileAccess.get_file_as_string(journey.storehouse.path).sha256_text()==checksum,"gameover preserves checkpoint bytes")
		check(journey.reload_checkpoint() and journey.s.food>0,"gameover can recover valid backup")
		journey.s.food=2; journey.s.xp=0; journey.s.mode="HOME"
		check(journey.persist() and journey.last_save_held,"unaffordable trip and resupply preserve a playable checkpoint")
		check(FileAccess.get_file_as_string(journey.storehouse.path).sha256_text()==checksum,"low-resource checkpoint protection leaves file unchanged")
		check(journey.reload_checkpoint() and journey.s.food>5,"resource dead end reloads a playable state")
		var blocker=FileAccess.open(BASE+"blocked",FileAccess.WRITE)
		blocker.store_string("not a directory"); blocker.close()
		journey.storehouse=Store.new(BASE+"blocked/checkpoint.json")
		check(not journey.persist() and journey.paused and journey.fault!="","storage failure pauses safely")
	print("CAMPAIGN_PERSISTENCE ",checks," checks; ",failures," failures; ","write" if "--write" in OS.get_cmdline_user_args() else "read")
	quit(1 if failures else 0)
