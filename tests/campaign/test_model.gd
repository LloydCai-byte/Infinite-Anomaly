extends SceneTree
const Model = preload("res://scripts/campaign/model.gd")
const Store = preload("res://scripts/home/checkpoints.gd")
var checks=0
var failures=0

func check(value: bool, message: String) -> void:
	checks+=1
	if not value:
		failures+=1
		printerr("FAIL: "+message)

func _initialize() -> void: call_deferred("run")

func walk(m, skill: String) -> Dictionary:
	check(m.depart(false),"manual departure")
	for i in 3: m.observe(i)
	m.tick(90)
	return m.attempt(skill)

func farm(m, skill: String) -> void:
	m.s.auto=false
	m.s.mode="HOME"
	m.select_node(0)
	m.s.focus=skill
	m.s.chain=false
	check(m.depart(true),"known route can auto explore")
	check(m.tick(15)=="result","auto settles after route duration")
	check(m.s.result.won,"farming learned route succeeds")
	m.s.auto=false
	m.return_home()
	if m.s.food<=65 and m.s.xp>=3: m.supply()

func run() -> void:
	var m=Model.new()
	m.s.intro=true
	check(m.nodes.size()==9,"nine complete nodes")
	check(not m.select_node(1),"cannot bypass frontier")
	check(m.depart(),"first manual departure")
	check(m.attempt("combat").is_empty(),"must observe before action")
	check(m.observe(0).first,"first discovery")
	var xp=m.s.xp
	check(not m.observe(0).first and m.s.xp==xp,"same clue cannot farm xp")
	m.observe(1)
	check(m.attempt("perception").is_empty(),"no instant outcome before entrance completes")
	m.tick(3)
	var result=m.attempt("perception")
	check(result.won and m.s.frontier==1,"first success unlocks next scene")
	xp=m.s.xp
	check(m.settle("perception").is_empty() and xp==m.s.xp,"settles at most once")
	m.return_home()
	check(m.s.selected==1,"selects newly discovered frontier")
	check(m.depart(true) and m.s.mode=="WAIT","automatic run stops before unknown content")
	var food=m.s.food
	m.tick(3600)
	check(m.s.food==food and m.s.mode=="WAIT","unknown-content waiting pauses food")
	check(m.take_control() and m.s.mode=="EXPLORE","manual takeover")
	m.observe(0); m.observe(1); m.tick(3)
	result=m.attempt("perception")
	check(not result.won and result.hint.contains("感知 1 / 2"),"failure explains precise deficiency")
	check(m.s.memories.has("1") and not m.s.memories["1"].won,"failure records unfinished page")
	m.return_home()
	result=walk(m,"perception")
	check(not result.won and result.xp==0,"repeat intentional failure gives no death-farming xp")
	check(m.s.memories.size()==2,"repeats never duplicate memory pages")
	m.return_home()
	var state=m.s.duplicate(true)
	check(Model.new().restore(state),"state roundtrip")
	state.food=-1
	check(not Model.new().restore(state),"negative food rejected")
	state=m.s.duplicate(true); state.skills.combat=999
	check(not Model.new().restore(state),"invalid stat rejected")
	state=m.s.duplicate(true); state.mode="GAMEOVER"
	check(not Model.new().restore(state),"dead checkpoint rejected")
	state=m.s.duplicate(true); state.timer=NAN
	check(not Model.new().restore(state),"nonfinite time rejected")
	state=m.s.duplicate(true); state.xp=INF
	check(not Model.new().restore(state),"nonfinite integer field rejected")
	state=m.s.duplicate(true); state.memories["1"].route="invalid"
	check(not Model.new().restore(state),"invalid nested memory rejected")
	state=m.s.duplicate(true); state.result={"stage":0}
	check(not Model.new().restore(state),"incomplete result rejected")
	m.s.food=0.01
	check(m.tick(3)=="gameover","resource depletion ends game")
	check(not m.depart() and not m.upgrade("combat"),"no gameplay after gameover")
	for skill in ["perception","combat","survival"]:
		var sim=Model.new()
		sim.s.intro=true
		var repeats=0
		for index in 9:
			sim.s.auto=false
			sim.s.mode="HOME"
			while sim.stat(skill)<int(sim.nodes[index].requirements[skill]):
				if not sim.upgrade(skill):
					farm(sim,skill)
					repeats+=1
					if repeats>100: check(false,"economy must reach ending"); break
			sim.select_node(index)
			result=walk(sim,skill)
			check(result.get("won",false),"%s route clears stage %d"%[skill,index])
			if index<8: sim.return_home()
			if sim.s.food<=65: sim.supply()
		check(sim.s.mode=="ENDING" and sim.s.frontier==9,"%s reaches only narrative ending"%skill)
		check(sim.s.memories.size()==9,"entire memory collection")
		check(sim.s.food>0,"viable resource balance")
		check(repeats>0 and repeats<40,"repeated exploration is useful without extreme grind")
		print("BALANCE ",skill,": ",repeats," repeat expeditions, food ",snapped(sim.s.food,0.1),", XP ",sim.s.xp)
		check(Model.new().restore(sim.s),"completed campaign restores")
	var storage=Store.new("res://.local/campaign-tests/checkpoint.json")
	m.new_game();m.s.intro=true
	check(storage.save(m.s),"atomic initial checkpoint")
	m.s.xp=13
	check(storage.save(m.s),"checkpoint rotates")
	check(storage.read_latest().xp==13,"primary roundtrip")
	check(storage.read_path(storage.path+".bak1").xp==0,"backup contains previous snapshot")
	var f=FileAccess.open(storage.path,FileAccess.WRITE)
	f.store_string("corrupted");f.close()
	check(storage.read_latest().is_empty(),"corrupt primary rejected")
	check(not storage.backups().is_empty(),"valid backups remain recoverable")
	m.s.mode="GAMEOVER";m.s.food=0
	check(not storage.save(m.s),"gameover never overwrites checkpoint")
	print("CAMPAIGN_MODEL ",checks," checks; ",failures," failures")
	quit(1 if failures else 0)
