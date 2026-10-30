extends SceneTree
const Gear=preload("res://scripts/pixel_home/gear.gd")
const Battle=preload("res://scripts/pixel_home/finale_battle.gd")
const Content=preload("res://scripts/pixel_home/content.gd")
const View=preload("res://scripts/pixel_hyakki/view.gd")
const Home=preload("res://scripts/pixel_home/home.gd")
class FailingGear extends Gear:
	var fail=false
	func persist() -> bool:
		if fail:last_error="isolated simulated disk failure";return false
		return super.persist()
var doc="res://docs/hub-cosmos-campaign-20261028/finale-test/"
var checks=[]
var completed:Dictionary={}
func check(ok:bool,label:String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
func write_json(path:String,value:Variant) -> void:
	var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(value,"  "));file.close()
func _initialize() -> void:
	if DisplayServer.get_name()=="headless":printerr("Run this suite with actual GPU rendering.");quit(2);return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--home-test-output="):doc=arg.trim_prefix("--home-test-output=").trim_suffix("/")+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(doc));call_deferred("run")
func drain_story(g) -> void:
	while g.story_waiting():
		g.prepare_story()
		if not g.complete_story(g.narrative.pending.id):break
func new_gear():
	var g=Gear.new(11);g.restore(completed);return g
func make_battle(g,content):
	var model=Battle.new();model.configure_levels([content.level]);model.attach(g);model.reset();model.start();return model
func clear_scene(model) -> void:
	for i in range(5,10):model.damage(-1,i,999999,"test")
	model.action={};model.projectiles=[];model.advance(.03)
func capture(name:String) -> void:
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(doc+name+".png")
func fixture() -> Dictionary:
	var base=JSON.parse_string(FileAccess.get_file_as_string(Content.BASE));var roster=JSON.parse_string(FileAccess.get_file_as_string(View.ART+"sprites/roster.json"))
	var pack={"schema":1,"test_only":true,"level":{"id":601,"title":"测试替身 · 四战","phase":"finale","world_key":"qa_finale","rating_base":12,"scenes":[]},"enemies":{},"visuals":{}}
	for i in range(5):
		var source=["kappa","tengu","oni","umbrella","wheel"][i];var visual=roster[source].duplicate(true)
		visual.giant=visual.height>84;visual.portrait=View.ART+"sprites/"+source+"/portrait.png"
		for clip in Content.CLIPS:visual.clips[clip].path=View.ART+"sprites/"+source+"/"+clip+".png"
		pack.visuals["alien_finale_qa_%d"%i]=visual
		pack.enemies["finale_qa_%d"%i]={"name":"功能测试替身%d"%i,"skill":"验证攻击","role":["melee","ranged","heavy","flame","melee"][i],"visual":"alien_finale_qa_%d"%i,"hp_base":120+i*20,"attack_base":12+i,"speed":20+i,"armor":15,"resist":10}
	for i in range(4):
		var scene=base.levels[0].scenes[i].duplicate(true);scene.id="QA-FINALE-%d"%i;scene.title=Gear.Finale.catalog().battles[i].title+" · 测试替身";scene.enemies=pack.enemies.keys();scene.boss_slots=[2];pack.level.scenes.append(scene)
	return pack
func run() -> void:
	var normal_hash=FileAccess.get_sha256(Content.FINALE_REGISTRY)
	check(not Content.load_finale().available and Content.load_finale().errors.is_empty(),"normal finale stays unavailable without approved assets")
	var pack=fixture();check(Content.validate_pack(pack,true).ok,"explicit four-battle test fixture validates")
	check(not Content.validate_pack(pack).ok,"finale cannot masquerade as one of six hundred numbered chapters")
	var bad=pack.duplicate(true);bad.level.scenes.pop_back();check(not Content.validate_pack(bad,true).ok,"missing fourth boss encounter rejected")
	bad=pack.duplicate(true);bad.level.scenes[0].boss_slots=[];check(not Content.validate_pack(bad,true).ok,"boss-less finale encounter rejected")
	bad=pack.duplicate(true);bad.level.scenes[0].boss_slots=[1,2];check(not Content.validate_pack(bad,true).ok,"ambiguous multiple lead bosses rejected")
	write_json(doc+"fixture-pack.json",pack);write_json(doc+"fixture-registry.json",{"schema":1,"pack":doc+"fixture-pack.json"})
	check(not Content.load_finale(doc+"fixture-registry.json").available,"normal loader refuses reused test visuals")
	var content=Content.load_finale(doc+"fixture-registry.json",true)
	check(content.available and content.level.scenes.size()==4 and content.visuals.size()==5,"explicit test loader exposes four battles and five independent visuals")
	var g=Gear.new(11)
	check(not g.finale_eligible() and not g.begin_finale(),"fresh Earth team cannot enter finale")
	for id in range(1,301):g.record_level_result(id,3,10,0,90,true)
	g.finish_graduation();drain_story(g)
	for id in range(301,600):g.record_level_result(id,1,10,0,90,true)
	drain_story(g);check(not g.finale_eligible(),"299 planets cannot unlock the finale")
	g.record_level_result(600,1,10,0,90,true)
	check(not g.finale_eligible(),"full planet clears still require final approach story")
	drain_story(g);g.s.level=100;completed=g.snapshot()
	check(g.finale_eligible() and Gear.Finale.valid(g.finale,g.campaign,g.narrative),"all planets and final approach unlock a valid idle finale")
	g.open_profile(doc+"four-battles.json");var original_campaign=g.campaign.duplicate(true)
	check(g.begin_finale() and g.finale.status=="active" and g.finale.attempts==1 and not g.events.ticket.is_empty(),"beginning finale atomically opens attempt and return ticket")
	check(not g.begin_finale(),"double departure cannot create another attempt")
	var model=make_battle(g,content)
	model.units[0].hp=0;model.units[1].hp=roundi(model.units[1].max_hp*.4);model.shields[1]=30
	clear_scene(model);var party=g.finale.checkpoint.duplicate(true)
	check(model.phase=="clear" and g.finale.next==1 and g.finale.battles.size()==1,"real first encounter stores exactly one checkpoint")
	check(g.campaign==original_campaign and not g.growth.worlds.has("qa_finale"),"finale victory cannot manufacture a numbered level or normal growth clear")
	check(not g.save_finale_result(0,true,party,5),"duplicate or reordered checkpoint cannot advance progress")
	check(model.advance_stage() and model.stage==1 and model.units[0].hp==0,"next boss retains dead teammate without automatic revival")
	check(absf(float(model.units[1].hp)/model.units[1].max_hp-party[1].hp)<.001 and is_equal_approx(model.shields[1],model.units[1].max_hp*party[1].shield),"health and shield carry over without between-boss healing")
	var reload=Gear.new(22);reload.open_profile(doc+"four-battles.json");var resumed=make_battle(reload,content)
	check(resumed.stage==1 and resumed.units[0].hp==0 and reload.finale==g.finale,"actual disk reload resumes next boss with same dead teammate and checkpoint")
	check(not resumed.advance_stage(),"cannot skip a living boss by advancing")
	for u in resumed.units.slice(0,5):u.hp=0
	resumed.advance(.03)
	check(resumed.phase=="defeat" and reload.finale.status=="failed" and reload.finale.next==1,"squad wipe stores failed attempt without falsely winning current boss")
	reload.complete_trip();reload.events.pending={}
	check(reload.begin_finale() and reload.finale.next==0 and reload.finale.attempts==2 and reload.finale.checkpoint.is_empty(),"retry after defeat resets to first boss and counts a new attempt")
	var retry=make_battle(reload,content);check(retry.stage==0 and retry.units.slice(0,5).all(func(u):return u.hp==u.max_hp),"new attempt starts entire team at full health")
	# Distinct automatic boss mechanics measured against actual combat state.
	for stage in range(4):
		var ability_gear=new_gear();ability_gear.begin_finale();var ability=make_battle(ability_gear,content);ability.stage=stage;ability.spawn_stage()
		ability.units[7].hp=roundi(ability.units[7].max_hp*.4)
		var hp=ability.units.slice(0,5).reduce(func(total,u):return total+u.hp,0);var boss_hp=ability.units[7].hp;var base_attack=ability.units[7].power
		for action_index in range(2 if stage==3 else 3):
			ability.action={};ability.begin_action(7)
		check(ability.boss_triggers==1,"boss %d triggers its own automatic mechanic"%stage)
		match stage:
			0:check(ability.shields.slice(5).all(func(value):return value>0),"first defense shields every living enemy")
			1:check(ability.units.slice(0,5).reduce(func(total,u):return total+u.hp,0)<hp,"second defense actually damages squad with extra volley")
			2:
				check(ability.units[7].hp>boss_hp,"third defense heals while escorts survive")
				for index in [5,6,8,9]:ability.units[index].hp=0
				boss_hp=ability.units[7].hp
				for action_index in range(3):ability.action={};ability.begin_action(7)
				check(ability.units[7].hp==boss_hp,"defeating escorts prevents parasitic boss healing")
			3:
				check(ability.units[7].power>base_attack,"core overcharge increases actual attack power")
				for action_index in range(20):ability.action={};ability.begin_action(7)
				check(ability.enrage_stacks==6 and ability.units[7].power<=ceili(base_attack*1.36),"core overcharge caps at six stacks")
	var fail=FailingGear.new(44);fail.restore(completed);fail.fail=true;var before=fail.snapshot()
	check(not fail.begin_finale() and fail.snapshot()==before,"failed departure save rolls back attempt and event ticket")
	fail.fail=false;fail.begin_finale();var fmodel=make_battle(fail,content);fail.fail=true;clear_scene(fmodel)
	check(fmodel.phase=="checkpoint" and fail.finale.next==0 and not fmodel.pending_outcome.is_empty(),"checkpoint disk failure blocks advancement and keeps pending victory")
	check(not fmodel.advance_stage(),"failed checkpoint cannot be skipped")
	fail.fail=false
	check(fmodel.save_outcome() and fail.finale.next==1 and fmodel.phase=="clear","retry saves the same victory once without refighting")
	check(fmodel.save_outcome() and fail.finale.next==1,"repeated save retry does not duplicate progress")
	# Complete all four through natural ATB combat; no instant-kill helper.
	var natural=new_gear();natural.open_profile(doc+"natural-run.json");natural.begin_finale();var auto=make_battle(natural,content)
	while auto.phase in ["fight","clear"] and auto.time<1500:
		if auto.phase=="clear":auto.advance_stage()
		else:auto.advance(.25)
	check(auto.phase=="victory" and auto.kills==20 and natural.finale.next==4,"natural ATB defeats all four bosses and their escorts")
	check(natural.ending_pending() and natural.finale.battles.size()==4 and natural.campaign==original_campaign,"last boss reserves ending and retains all six hundred campaign records")
	check(Gear.Finale.valid(natural.finale,natural.campaign,natural.narrative),"completed run is valid for persistent recovery")
	check(not natural.begin_finale() and not natural.can_enter_level(1),"pending ending blocks replay and regular departure")
	var ending_fail=FailingGear.new(55);ending_fail.restore(natural.snapshot());before=ending_fail.snapshot();ending_fail.fail=true
	check(not ending_fail.finish_ending() and ending_fail.snapshot()==before,"failed ending save retains pending ending and equipment")
	ending_fail.fail=false;check(ending_fail.finish_ending() and not ending_fail.finish_ending(),"ending records exactly once after successful retry")
	var legacy=completed.duplicate(true);legacy.erase("finale");var save=Gear.Save.new(doc+"before-finale.json");save.save(legacy);var hash=FileAccess.get_sha256(save.path)
	var migrated=Gear.new(66);migrated.open_profile(save.path)
	check(migrated.home_migration_backup.contains(".before-finale-") and FileAccess.get_sha256(migrated.home_migration_backup)==hash,"migration creates exact independent pre-finale backup")
	check(migrated.s==completed.state and migrated.cosmos==completed.cosmos and migrated.finale.status=="idle","migration retains all gear and initializes only finale state")
	bad=natural.snapshot();bad.finale.next=3;before=migrated.snapshot();check(not migrated.restore(bad) and migrated.snapshot()==before,"inconsistent victory rejected before mutating old player state")
	bad=natural.snapshot();bad.finale.checkpoint[0].hp=2;check(not migrated.restore(bad),"invalid checkpoint health rejected")
	# Actual home, battle controls, checkpoint return and ending playback.
	var home=Home.new();root.add_child(home);await process_frame;await process_frame;home.finish_intro();home.close_dialog()
	home.gear.restore(completed);home.gear.home.intro_done=true;home.gear.home.intro_version=2;home.gear.persist()
	home.finale_registry_path=doc+"fixture-registry.json";home.allow_test_finale=true;home.finale_menu();await process_frame
	var launch=home.choices.get_children().filter(func(control):return control is Button and control.text.begins_with("出发"))
	check(launch.size()==1,"eligible home offers actual four-battle departure")
	if not launch.is_empty():launch[0].pressed.emit()
	home.battle.paused=true;check(home.mode=="battle" and home.battle.is_finale() and not home.battle.repeat_run,"real departure uses finale model and disables repeat farming")
	check(home.battle.controls.has("home") and not home.battle.controls.has("restart") and home.battle.controls.equipment.disabled,"finale retains home return and forbids mid-battle equipment or reset")
	home.battle.queue_redraw();await capture("01-finale-test-surrogates")
	clear_scene(home.battle.model);home.return_home();await process_frame
	check(home.mode=="home" and not home.battle.is_finale() and home.gear.finale.next==1,"return restores regular campaign model and preserves boss checkpoint")
	if not home.gear.events.pending.is_empty():home.finish_pending_event()
	home.close_dialog();home.depart_finale();home.battle.paused=true
	check(home.battle.model.stage==1 and home.gear.finale.attempts==1,"home continuation resumes second boss in same attempt")
	while home.battle.model.phase in ["fight","clear"]:
		if home.battle.model.phase=="clear":home.battle.model.advance_stage()
		else:clear_scene(home.battle.model)
	await process_frame;await process_frame
	check(home.mode=="home" and home.ending_open and home.gear.ending_pending(),"final victory automatically returns to Xuan and starts ending")
	home.dialog_text.visible_characters=-1;home.arrival=0;home.queue_redraw();await capture("02-first-cycle-ending")
	home.depart(0);check(home.mode=="home" and home.ending_open,"ending cannot be bypassed with normal departure")
	var ending_snapshot=home.gear.snapshot();home.gear.persist();home.queue_free();await process_frame
	home=Home.new();root.add_child(home);await process_frame;await process_frame
	check(home.ending_open and home.gear.finale==ending_snapshot.finale,"actual restart resumes pending ending without replaying the bosses")
	home.finish_ending();check(home.gear.finale.status=="complete" and home.gear.finale.ending_seen and not home.ending_open,"actual ending completes and persists")
	check(FileAccess.get_sha256(Content.FINALE_REGISTRY)==normal_hash and not Content.load_finale().available,"test finale assets never enter normal registry")
	var failures=checks.filter(func(entry):return not entry.pass)
	write_json(doc+"verification.json",{"checks":checks,"failures":failures,"normal_player_save_used":false,"test_visuals_are_reused_surrogates":true,"natural_run_seconds":auto.time,"natural_run_kills":auto.kills})
	print("FINALE %d checks %d failures"%[checks.size(),failures.size()]);home.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
