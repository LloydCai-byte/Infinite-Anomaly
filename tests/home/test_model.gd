extends SceneTree
const Model = preload("res://scripts/home/model.gd")
const Store = preload("res://scripts/home/checkpoints.gd")
var checks: int = 0
var failures: Array[String] = []
var completion: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

func verify(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL: "+message)

func finish_attempt(m) -> void:
	m.tick(float(m.s.remaining)+0.001)

func run() -> void:
	var m=Model.new()
	verify(m.s.food==100 and m.s.xp==0 and m.s.generation==1,"initial resources and one protagonist")
	verify(not m.upgrade("perception") and not m.supply(),"no money: operations rejected")
	verify(m.depart(),"first departure starts")
	verify(m.s.generation==2 and m.s.mode=="MEMORY","latest self appears immediately")
	verify(not m.depart(),"cannot have parallel expeditions")
	finish_attempt(m)
	verify(not m.s.result.success and m.s.stage==0,"first memory is a death, not stage advancement")
	verify(m.s.cards.R01==1 and m.s.xp==5,"death grants a memory and first experience")
	verify(m.absorb("R01")==0 and m.s.cards.R01==1,"last copy cannot be absorbed")
	var xp: int=m.s.xp
	verify(not m.settle() and m.s.xp==xp,"settlement is idempotent")
	m.depart()
	finish_attempt(m)
	verify(m.s.stage==1 and m.s.cards.R01==2,"success progresses and retains duplicate memory")
	verify(m.absorb("R01",true)==1 and m.s.cards.R01==1,"duplicates convert while one remains")
	verify(m.s.xp==xp+2+3,"absorption adds exact experience")
	m.depart()
	m.s.xp=100
	m.upgrade("perception")
	finish_attempt(m)
	verify(not m.s.result.success,"upgrading mid-memory does not rewrite past ability")
	m.depart()
	finish_attempt(m)
	verify(m.s.result.success and m.s.result.route=="perception","next self uses the upgraded route")
	m.s.food=95
	xp=m.s.xp
	verify(m.supply() and m.s.food==100 and m.s.xp==xp-3,"supply clips to cap and charges once")
	verify(not m.supply(),"full supply cannot be purchased")
	var exported: Dictionary=m.export_state()
	var recovered=Model.new()
	verify(recovered.restore(exported),"valid home state restores")
	exported.room="balcony"
	verify(recovered.restore(exported),"balcony viewpoint restores")
	exported.version=1
	verify(not recovered.restore(exported),"legacy save rejected without mutating state")
	var partial=Model.new()
	partial.depart()
	partial.tick(4.25)
	var rebuilt=Model.new()
	verify(rebuilt.restore(partial.export_state()),"in-flight memory restores")
	verify(is_equal_approx(rebuilt.s.remaining,17.75),"partial duration preserved")
	finish_attempt(rebuilt)
	verify(rebuilt.s.cards.R01==1,"restored attempt settles exactly once")
	var dead=Model.new()
	dead.s.food=1.0
	dead.depart()
	dead.tick(100)
	verify(dead.s.mode=="GAMEOVER" and dead.s.food==0 and dead.s.cards.is_empty(),"resource death precedes unresolved reward")
	dead.s.xp=99
	verify(not dead.depart() and not dead.supply() and not dead.upgrade("combat"),"gameover blocks mutations")
	verify(not Model.new().restore(dead.export_state()),"gameover cannot be loaded as checkpoint")
	var auto=Model.new()
	auto.set_auto(true)
	auto.tick(4)
	verify(auto.s.mode=="MEMORY","auto departure fires once from home")
	auto.set_auto(false)
	finish_attempt(auto)
	auto.tick(5)
	verify(auto.s.mode=="HOME","turning auto off preserves current attempt and stops next")
	for branch in ["combat","perception","survival"]:
		test_route(branch)
	test_store()
	await test_session()
	var report={"checks":checks,"failures":failures,"routes":completion}
	var f=FileAccess.open("res://.local/home_test_report.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(report,"  "))
	f.close()
	print("HOME RULES: %d checks, %d failures"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func test_route(branch: String) -> void:
	var m=Model.new()
	m.set_focus(branch)
	var runs: int=0
	while m.s.mode!="ENDING" and runs<50:
		for card in m.s.cards.keys():
			m.absorb(card,true)
		if m.s.food<30:
			m.supply()
		var requirement: int=m.db.stages[m.s.stage].thresholds[branch]
		while m.stats()[branch]<requirement and m.upgrade(branch):
			pass
		if not m.depart():
			break
		finish_attempt(m)
		runs+=1
		verify(m.s.food>0 and m.s.xp>=0,branch+" has sustainable resources")
	verify(m.s.mode=="ENDING" and m.s.cleared.size()==6,branch+" can clear all six stages")
	verify(m.s.result.route==branch,branch+" has distinct concluding route")
	verify(m.s.cards.size()==6,branch+" collects complete memories")
	var food: float=m.s.food
	m.tick(5000)
	verify(m.s.food==food and not m.depart(),"positive ending is terminal and stops resource drain")
	completion[branch]={"attempts":runs,"food":m.s.food,"experience":m.s.xp,"route":m.s.result.route}

func test_store() -> void:
	var path: String="res://.local/home-test-"+str(Time.get_ticks_usec())+"/checkpoint.json"
	var store=Store.new(path)
	var m=Model.new()
	for i in range(5):
		m.s.xp=i
		verify(store.save(m.export_state()),"checkpoint write "+str(i))
	verify(store.read_latest().xp==4,"current checkpoint is most recent")
	verify(store.read_path(store.path+".bak1").xp==3,"backup 1")
	verify(store.read_path(store.path+".bak2").xp==2,"backup 2")
	verify(store.read_path(store.path+".bak3").xp==1,"backup 3")
	m.s.mode="GAMEOVER"
	m.s.food=0
	verify(not store.save(m.export_state()) and store.read_latest().xp==4,"death cannot overwrite a good checkpoint")
	var f=FileAccess.open(store.path,FileAccess.WRITE)
	f.store_string("{broken")
	f.close()
	verify(store.read_latest().is_empty() and store.backups().size()==3,"corruption is detected and backups remain")
	# Only exact test-owned files are cleaned; player state never uses this path.
	for suffix in ["",".bak1",".bak2",".bak3",".tmp"]:
		if FileAccess.file_exists(store.path+suffix):
			DirAccess.remove_absolute(store.path+suffix)

func test_session() -> void:
	var home=root.get_node("Home")
	home.set_process(false)
	home.model.new_game()
	home.model.s.intro=true
	home.store=Store.new("res://.local/session-home-"+str(Time.get_ticks_usec())+"/checkpoint.json")
	home.transient=false
	home.fault=""
	home.invalid_checkpoint=false
	home.paused=false
	verify(home.persist(),"session initial checkpoint")
	home.save_elapsed=1199.0
	home.model.s.xp=7
	home._process(0.5)
	verify(home.store.read_latest().xp==0,"does not autosave before 20 minutes")
	home._process(0.6)
	verify(home.store.read_latest().xp==7,"autosaves at 20 minute interval")
	home.model.s.food=0.001
	home._process(1)
	verify(home.model.s.mode=="GAMEOVER","session triggers gameover")
	verify(not home.persist() and home.store.read_latest().food>0,"session never saves exhausted state")
	verify(home.reload_checkpoint() and home.model.s.mode=="HOME" and home.model.s.xp==7,"gameover resumes saved resources")
	home.paused=true
	var food: float=home.model.s.food
	home._process(30)
	verify(home.model.s.food==food,"pause suspends consumption")
	for suffix in ["",".bak1",".bak2",".bak3",".tmp"]:
		if FileAccess.file_exists(home.store.path+suffix):
			DirAccess.remove_absolute(home.store.path+suffix)
	home.transient=true
	home.set_process(false)
	await process_frame
