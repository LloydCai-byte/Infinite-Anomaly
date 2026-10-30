extends SceneTree
const Battle=preload("res://scripts/pixel_home/battle.gd")
const Gear=preload("res://scripts/pixel_home/gear.gd")
const Travel=preload("res://scripts/pixel_hyakki/travel.gd")
const FinaleBattle=preload("res://scripts/pixel_home/finale_battle.gd")
class FailedSave extends RefCounted:
	var error="injected write failure"
	func save(_data:Dictionary)->bool:return false
var checks=[]
func check(ok:bool,label:String)->void:
	checks.append({"pass":ok,"name":label})
	if not ok:push_error(label)
func clear_wave(m)->void:
	for enemy in m.units.slice(5):m.damage(-1,enemy.uid,enemy.max_hp+100,"test")
	m.advance(.02)
func _initialize()->void:
	var m=Battle.new();var content=m.load_content();var levels=content.levels;var g=Gear.new(71)
	check(levels.size()==20 and content.errors.is_empty(),"real content expands to twenty rooms without new images")
	m.configure_levels(levels);m.attach(g);m.reset();m.start()
	var image=m.scene_info().image;var positions=m.units.slice(0,5).map(func(u):return u.home)
	for wave in range(10):
		check(m.scene_index()==wave and m.scene_info().image==image,"same image for wave "+str(wave+1))
		clear_wave(m)
		if wave<9:
			check(g.campaign.levels.is_empty() and g.growth.scenes.is_empty(),"no room award at wave "+str(wave+1))
			check(not Travel.new().begin(m),"no teleport inside room")
			m.units[0].hp=123;m.units[1].hp=0;m.shields[0]=35;m.cosmic_actions[0]=2;m.cycle_total_actions=4
			m.dots[0]=4.0;m.dot_turns[0]=2;m.slows[0]=3.0;m.units[0].charge=.73;m.units[0].burn=1.5;m.burn_power[0]=7
			check(m.advance_stage(),"advance to wave "+str(wave+2))
			check(m.units[0].hp==123 and m.units[1].hp==0 and m.shields[0]==35,"health death shield continuity")
			check(m.cosmic_actions[0]==2 and m.cycle_total_actions==4,"skill counters continue")
			check(m.units[0].charge==.73 and m.dots[0]==4 and m.dot_turns[0]==2 and m.slows[0]==3 and m.units[0].burn==1.5 and m.burn_power[0]==7,"ATB and debuffs continue")
			check(m.units.slice(0,5).map(func(u):return u.pos)==positions,"hero anchors stay fixed")
	check(m.kills==50 and g.campaign.levels.has("R0001"),"ten waves fifty kills earn room completion")
	check(g.growth.scenes.size()==1 and g.growth.scenes.has("hyakki:R02-S01"),"one authored picture record per complete room")
	check(g.campaign.levels.R0001.mask==1 and g.campaign.levels.R0001.clears==1,"first difficulty saved once")
	var saved=g.snapshot();m.finish("clear");m.save_room_outcome()
	check(g.snapshot()==saved,"repeated finish or retry cannot duplicate credit")
	var transit=Travel.new();check(transit.begin(m),"teleport allowed after tenth wave")
	transit.tick(transit.duration*.5);check(m.level_index()==1 and m.scene_index()==0 and m.scene_info().image!=image,"next picture appears at black-screen midpoint")
	transit.tick(1.0);check(not transit.active,"room transition completes")
	# Atomic completion: rewards earned during battle stay, room receipts retry once.
	m=Battle.new();g=Gear.new(72);m.configure_levels(levels);m.attach(g);m.reset();m.start()
	for wave in range(10):
		if wave==9:g.persistence=FailedSave.new()
		clear_wave(m)
		if wave<9:m.advance_stage()
	check(m.phase=="checkpoint" and not m.pending_room_outcome.is_empty(),"failed save blocks room exit")
	check(g.campaign.levels.is_empty() and g.growth.scenes.is_empty(),"failed completion rolls back both score ledgers")
	var inventory=g.s.inventory.duplicate(true);var gold=g.s.gold;var kills=g.total_kills()
	check(not m.advance_stage() and not Travel.new().begin(m),"failed save cannot advance or teleport")
	check(not m.save_room_outcome() and g.campaign.levels.is_empty(),"repeated failed retry leaves no duplicate receipt")
	g.persistence=null
	check(m.save_room_outcome() and m.phase=="clear","successful retry resumes room completion")
	check(g.campaign.levels.R0001.clears==1 and g.s.inventory==inventory and g.s.gold==gold and g.total_kills()==kills,"retry preserves loot and credits room exactly once")
	check(g.restore(g.snapshot()),"battle outcome satisfies full production save validation")
	# Partial defeat keeps loot but does not count a completed room.
	m=Battle.new();g=Gear.new(73);m.configure_levels(levels);m.attach(g);m.reset();m.start();clear_wave(m);m.advance_stage()
	var partial=g.s.inventory.duplicate(true);m.finish("defeat")
	check(m.phase=="defeat" and g.campaign.levels.is_empty() and g.s.inventory==partial,"partial defeat retains loot without completion")
	var final_model=FinaleBattle.new()
	check(not final_model.room_mode() and final_model.is_finale(),"four-boss model remains a separate encounter")
	# Natural combat, independent seed; no fake victory/gear/stat boosts.
	m=Battle.new();g=Gear.new(71);m.configure_levels(levels);m.attach(g);m.reset();m.start()
	while m.time<2000 and m.phase in ["fight","clear"]:
		if m.phase=="clear":
			if m.is_level_end():break
			m.advance_stage()
		else:m.advance(.25)
	var natural={"phase":m.phase,"wave":m.scene_index()+1,"seconds":m.time,"kills":m.kills,"level":g.s.level,"inventory":g.s.inventory.size(),"cleared":g.campaign.levels.has("R0001")}
	check(m.phase in ["clear","defeat"],"natural run reaches terminal result")
	check(natural.cleared==(m.phase=="clear" and m.scene_index()==9),"natural outcome matches room receipt")
	var failures=checks.filter(func(entry):return not entry.pass)
	var file=FileAccess.open("res://docs/feedback-room-campaign-20261029/waves-runtime-verification.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"natural_first_room":natural,"normal_profile_used":false,"scope":"production battle model; full UI/package testing still pending"},"\t"));file.close()
	print("ROOM_RUNTIME %d checks %d failures; natural="%[checks.size(),failures.size()],JSON.stringify(natural));quit(0 if failures.is_empty() else 1)
