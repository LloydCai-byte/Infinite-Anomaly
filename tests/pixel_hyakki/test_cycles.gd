extends SceneTree
const Gear=preload("res://scripts/pixel_home/gear.gd")
const Battle=preload("res://scripts/pixel_home/battle.gd")
const Home=preload("res://scripts/pixel_home/home.gd")
const Content=preload("res://scripts/pixel_home/content.gd")
class FailingGear extends Gear:
	var fail=false
	func persist() -> bool:
		if fail:last_error="isolated simulated disk failure";return false
		return super.persist()
var doc="res://docs/hub-cosmos-campaign-20261028/cycles-test/"
var checks=[]
var definitions=[]
var home
func check(ok:bool,label:String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
func write_json(path:String,value:Variant) -> void:
	var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(value,"  "));file.close()
func _initialize() -> void:
	if DisplayServer.get_name()=="headless":printerr("Run cycle UI verification with rendered GPU.");quit(2);return
	root.size=Vector2i(1600,900);root.content_scale_size=Vector2i(1600,900)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--home-test-output="):doc=arg.trim_prefix("--home-test-output=").trim_suffix("/")+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(doc));call_deferred("run")
func drain_story(g) -> void:
	while g.story_waiting():
		g.prepare_story()
		if not g.complete_story(g.narrative.pending.id):break
func complete_cycle_fixture(g,finish:bool=true) -> void:
	if g.cycles.pending_intro!=0:g.finish_cycle_intro()
	for id in range(1,301):g.record_level_result(id,3,10,0,90,true)
	g.finish_graduation();drain_story(g)
	for id in range(301,601):g.record_level_result(id,1,10,1,90,true)
	drain_story(g);g.events.pending={};g.events.ticket={};g.begin_finale()
	var party=[]
	for i in range(5):party.append({"hp":1.0,"shield":0.0})
	for i in range(4):g.save_finale_result(i,true,party,30.0)
	g.complete_trip();g.events.pending={}
	if finish:g.finish_ending()
func model_for(g):
	var model=Battle.new();model.configure_levels(definitions);model.attach(g);model.reset();model.start();return model
func capture(name:String) -> void:
	await process_frame;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(doc+name+".png")
func mouse_click(button:Button) -> void:
	await process_frame;await process_frame
	var point=button.get_global_rect().get_center();var motion=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;root.push_input(motion)
	var event=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;root.push_input(event)
	event=event.duplicate();event.pressed=false;root.push_input(event);await process_frame;await process_frame
func choice(prefix:String) -> Button:
	for button in home.choices.get_children():
		if button is Button and button.text.begins_with(prefix):return button
	return null
func run() -> void:
	definitions=Content.load_campaign().levels
	var g=Gear.new(17);check(not g.can_start_cycle() and not g.start_next_cycle(),"fresh team cannot skip into next cycle")
	check(not g.equip_support("",1) and not g.choose_resonance(0),"future support and resonance unlocks are gated")
	complete_cycle_fixture(g);g.s.level=88;g.s.xp=117;g.s.training=[4,5,6,7,8]
	var legendary=g.award(350,2,5,0);g.equip(legendary.id,0,"weapon");legendary.locked=true
	g.s.sets[1]=Gear.G.SET_TYPES.duplicate();g.set_look(2,1)
	g.discover("oni",true);g.growth.cards.oni.copies=20;g.record_clear("hyakki","10",3,true)
	g.events.supports={"pulse":3,"anchor":2,"sight":1};g.events.equipped="pulse";g.events.materials=55;g.events.seen.pulse_parcel=1
	g.cosmos.inventory[0].locked=true;g.cosmos.skills=[2,2,2,2,2];g.cosmos.stardust=123
	g.open_profile(doc+"progress.json");g.persist();var completed=g.snapshot()
	check(g.cycles.history.size()==1 and g.cycles.history[0].cycle==1 and g.can_start_cycle(),"first completed ending records a cycle and permits second journey")
	check(g.start_next_cycle(),"second cycle transition succeeds")
	var second_pending=g.snapshot()
	check(g.campaign.cycle==2 and g.s.level==1 and g.s.xp==0,"new cycle resets only level and experience to one and zero")
	var unchanged=true
	for key in completed.state:
		if key not in ["level","xp"] and g.s[key]!=completed.state[key]:unchanged=false
	check(unchanged,"all item records, affixes, locked flags, equipment, currencies, training and looks survive byte-for-byte")
	check(g.item_by_id(legendary.id).level==350 and g.s.equipped[0].weapon==legendary.id,"level-one team still wears unchanged inherited level-350 equipment")
	check(g.cosmos==completed.cosmos and g.growth==completed.growth and g.events==completed.home_events,"star cores, skills, mastery, cards, support devices, materials and event RNG all survive unchanged")
	check(g.narrative.seen==completed.narrative.seen and g.narrative.pending.is_empty(),"world-story history is inherited without a stale pending chapter")
	check(g.campaign.phase=="earth" and g.campaign.levels.is_empty() and not g.graduation_pending() and g.finale.status=="idle","new campaign and boss progress reset instead of inheriting old gold gate")
	check(g.rank()==5 and g.mode(0)>=0,"learned skill rank remains available at level one")
	check(g.cycles.pending_intro==2 and not g.can_enter_level(1) and not g.begin_trip(),"new-cycle opening blocks departure until read")
	check(Gear.Save.new(g.cycle_backup).read_path(g.cycle_backup)==completed,"independent transition backup contains the entire exact prior journey")
	var disk=Gear.new(23);disk.open_profile(doc+"progress.json");check(disk.snapshot()==second_pending,"new cycle and pending opening survive exact disk reload")
	check(g.finish_cycle_intro() and not g.finish_cycle_intro() and g.can_enter_level(1) and not g.can_enter_level(301),"opening is consumed once and Earth route reopens before planets")
	var second=g.snapshot();var base=model_for(Gear.new(9));var m=model_for(g)
	check(m.units[5].max_hp==roundi(base.units[5].max_hp*1.65) and m.units[5].power==roundi(base.units[5].power*1.35),"second-cycle difficulty changes actual enemy HP and attack")
	var enemy_stats=[m.units[5].max_hp,m.units[5].power]
	for repeat in range(3):m.apply_loadout()
	check([m.units[5].max_hp,m.units[5].power]==enemy_stats,"reapplying equipment never compounds the cycle difficulty multiplier")
	check(g.equip_support("anchor",1) and g.cycles.secondary_support=="anchor","second support slot equips an owned different device")
	var with_two=m.preview_stats(0);g.equip_support("",1);var with_one=m.preview_stats(0)
	check(with_two.hp>with_one.hp and with_two.shield>with_one.shield,"both support devices contribute real stats together")
	g.equip_support("anchor",1);var before=g.snapshot()
	check(not g.equip_support("pulse",1) and not g.equip_support("anchor",0) and g.snapshot()==before,"same support cannot be duplicated across slots")
	var pool=Gear.Events.available(g.events,g.event_context(),true)
	check(pool.any(func(e):return e.id=="cycle_memory") and not pool.any(func(e):return e.id=="last_window"),"real second-cycle return context unlocks only its new event")
	check(not pool.any(func(e):return e.id=="pulse_parcel"),"once-only reward remains consumed across cycles")
	g.events.serial+=1;g.events.pending={"id":"cycle_memory","ticket":g.events.serial};var materials=g.events.materials
	check(not g.claim_event().is_empty() and g.events.materials==materials+10 and g.events.seen.cycle_memory==1,"second-cycle exclusive event grants real materials and records consumption")
	# Failure paths preserve all progress; no player data is used.
	var fail=FailingGear.new(99);fail.restore(completed);fail.fail=true;before=fail.snapshot()
	check(not fail.start_next_cycle() and fail.snapshot()==before,"failed next-cycle save restores completed campaign, gear and level")
	fail.fail=false;fail.start_next_cycle();before=fail.snapshot();fail.fail=true
	check(not fail.finish_cycle_intro() and fail.snapshot()==before,"failed opening save retains pending opening")
	fail.fail=false;fail.finish_cycle_intro();before=fail.snapshot();fail.fail=true
	check(not fail.equip_support("anchor",1) and fail.snapshot()==before,"failed secondary support save rolls back both slots")
	var backup_fail=Gear.new(55);backup_fail.restore(completed)
	var collision=FileAccess.open(doc+"not-a-directory",FileAccess.WRITE);collision.store_string("isolated backup-failure fixture");collision.close()
	backup_fail.persistence=Gear.Save.new(doc+"not-a-directory/profile.json");before=backup_fail.snapshot()
	check(not backup_fail.start_next_cycle() and backup_fail.snapshot()==before and backup_fail.last_error.contains("备份失败"),"unwritable transition archive prevents cycle reset")
	# Finish second journey, then a distinct third unlock and a definitive ending.
	complete_cycle_fixture(g);check(g.cycles.history.size()==2 and g.can_start_cycle(),"second ending unlocks third journey after its own complete campaign")
	var second_complete=g.snapshot();check(g.start_next_cycle() and g.campaign.cycle==3 and g.cycles.resonance==0,"third journey unlocks offensive resonance by default")
	check(g.cycles.secondary_support=="anchor" and g.s.inventory==completed.state.inventory and g.cosmos==completed.cosmos,"third journey still preserves old items, star cores and two supports")
	g.finish_cycle_intro();var third=g.snapshot();var third_model=model_for(g)
	check(third_model.units[5].max_hp==roundi(base.units[5].max_hp*2.6) and third_model.units[5].power==roundi(base.units[5].power*1.8),"third-cycle enemies have the next real difficulty increase")
	check(Gear.Events.available(g.events,g.event_context(),true).any(func(e):return e.id=="last_window"),"third-cycle return context unlocks final-window event")
	check(not Gear.Events.available(g.events,g.event_context(),true).any(func(e):return e.id=="cycle_memory"),"consumed second-cycle story does not repeat in third cycle")
	g.events.serial+=1;g.events.pending={"id":"last_window","ticket":g.events.serial};materials=g.events.materials
	check(not g.claim_event().is_empty() and g.events.materials==materials and g.events.seen.last_window==1,"third-cycle pure story persists without inventing a material reward")
	check(g.choose_resonance(1),"third cycle can choose defensive resonance")
	var shelter=third_model.preview_stats(0);g.choose_resonance(0);var offense=third_model.preview_stats(0)
	check(is_equal_approx(shelter.shield,minf(shelter.hp*.35,offense.shield+shelter.hp*.08)),"defensive resonance respects existing fully-equipped shield cap")
	var shield_probe=Gear.new(8);shield_probe.restore(third);shield_probe.s.equipped[0]={};shield_probe.cosmos.slots[0]=0;shield_probe.events.equipped="";shield_probe.cycles.secondary_support="";shield_probe.growth.slots=[]
	shield_probe.choose_resonance(1);var shield_model=model_for(shield_probe);var added_shield=shield_model.preview_stats(0)
	check(is_equal_approx(added_shield.shield,added_shield.hp*.08),"uncapped defensive resonance grants the full eight-percent starting shield")
	var offense_model=model_for(g);var damage_before=offense_model.total_damage
	offense_model.stats_live[0].powers=[]
	for i in range(4):offense_model.action={};offense_model.cosmic_actions=[0,0,0,0,0];offense_model.begin_action(0)
	check(offense_model.total_damage==damage_before and offense_model.cycle_triggers==0,"offensive resonance remains dormant before fifth action")
	offense_model.action={};offense_model.cosmic_actions=[0,0,0,0,0];offense_model.begin_action(0)
	check(offense_model.cycle_triggers==1 and offense_model.total_damage>damage_before,"fifth personal action executes real offensive resonance damage")
	g.choose_resonance(2);var heal_model=model_for(g);heal_model.units[1].hp=roundi(heal_model.units[1].max_hp*.2);var hp=heal_model.units[1].hp
	heal_model.stats_live[0].powers=[]
	for i in range(4):heal_model.action={};heal_model.cosmic_actions=[0,0,0,0,0];heal_model.begin_action(0)
	check(heal_model.units[1].hp==hp and heal_model.cycle_triggers==0,"healing resonance remains dormant before fifth team action")
	heal_model.action={};heal_model.cosmic_actions=[0,0,0,0,0];heal_model.begin_action(0)
	check(heal_model.cycle_triggers==1 and heal_model.units[1].hp>hp,"fifth team action heals the weakest surviving ally")
	heal_model.units[1].hp=0
	for i in range(5):heal_model.action={};heal_model.begin_action(0)
	check(heal_model.units[1].hp==0,"resonance does not bypass no-revival combat rule")
	heal_model.spawn_stage();check(heal_model.cycle_total_actions==0 and heal_model.cycle_triggers==0,"resonance counters reset between scenes")
	var resonance_fail=FailingGear.new(7);resonance_fail.restore(third);before=resonance_fail.snapshot();resonance_fail.fail=true
	check(not resonance_fail.choose_resonance(2) and resonance_fail.snapshot()==before,"failed resonance selection restores original build")
	# Independent difficulty on authored planet data, not only legacy monsters.
	var authored=definitions[0].duplicate(true);authored.enemy_catalog={};authored.world_key="qa_cycle_planet";authored.id=301;authored.campaign_id=301;authored.rating_base=1
	for i in range(5):authored.enemy_catalog["qa%d"%i]={"name":"测试","skill":"验证","role":"melee","visual":"unused_test_visual","hp_base":100,"attack_base":20,"speed":20,"armor":10,"resist":5}
	for scene in authored.scenes:scene.enemies=authored.enemy_catalog.keys();scene.boss_slots=[]
	var planet=Battle.new();planet.configure_levels([authored]);planet.attach(g);planet.reset()
	check(planet.units[5].max_hp==260 and planet.units[5].power==36,"authored alien base attributes receive cycle-three multipliers")
	planet.apply_loadout();planet.apply_loadout();check(planet.units[5].max_hp==260 and planet.units[5].power==36,"authored alien difficulty remains stable after equipment refresh")
	complete_cycle_fixture(g,false);check(g.ending_pending() and not g.cycles.game_complete,"last boss reserves true ending before declaring entire game complete")
	var last_pending=g.snapshot();g.events.serial+=1;g.events.pending={"id":"orbital_dust","ticket":g.events.serial}
	check(not g.finish_ending(),"true ending waits for already-earned return reward instead of discarding it")
	g.claim_event();check(g.finish_ending() and g.cycles.game_complete and g.cycles.history.size()==3,"third ending atomically records all three journeys and complete game")
	before=g.snapshot();check(not g.start_next_cycle() and not g.begin_trip() and not g.can_enter_level(1) and not g.begin_finale() and g.snapshot()==before,"complete game exposes no fourth cycle, new expedition, or extra finale")
	check(g.record_level_result(1,3,10,0,9,true).is_empty(),"post-ending callback cannot restart campaign progression")
	g.persist();disk=Gear.new(78);disk.open_profile(doc+"progress.json");check(disk.snapshot()==g.snapshot() and disk.cycles.game_complete,"definitive completion and all retained possessions survive disk reload")
	var legacy=completed.duplicate(true);legacy.erase("cycles");var save=Gear.Save.new(doc+"pre-cycles.json");save.save(legacy);var hash=FileAccess.get_sha256(save.path)
	var migrated=Gear.new(4);migrated.open_profile(save.path)
	check(migrated.home_migration_backup.contains(".before-cycles-") and FileAccess.get_sha256(migrated.home_migration_backup)==hash,"upgrade creates independent exact pre-cycles backup")
	check(migrated.can_start_cycle() and migrated.s==completed.state and migrated.cycles.history.size()==1,"old completed first-cycle save gains history without changing equipment")
	var invalid=third.duplicate(true);invalid.campaign.cycle=4;before=migrated.snapshot();check(not migrated.restore(invalid) and migrated.snapshot()==before,"fourth-cycle save rejected without mutation")
	invalid=third.duplicate(true);invalid.cycles.history=[];check(not migrated.restore(invalid),"missing previous journey receipts rejected")
	invalid=second.duplicate(true);invalid.cycles.resonance=0;check(not migrated.restore(invalid),"premature resonance in second cycle rejected")
	invalid=third.duplicate(true);invalid.cycles.game_complete=true;check(not migrated.restore(invalid),"premature final completion rejected")
	# Actual mouse UI, restart of cycle opening, support selection and true ending.
	home=Home.new();root.add_child(home);await process_frame;await process_frame;home.finish_intro();home.close_dialog()
	home.gear.restore(completed);home.gear.home.intro_done=true;home.gear.home.intro_version=2;home.gear.persist();home.open_cycles();await process_frame
	check(home.mode=="home" and home.dialog.visible and home.gear.can_start_cycle(),"completed ending offers next journey confirmation without spoiler archive")
	var cancel=choice("保留当前");check(cancel!=null,"cycle transition has an explicit in-game confirmation")
	if cancel!=null:await mouse_click(cancel)
	check(home.gear.campaign.cycle==1 and home.gear.s.level==88,"cancel preserves old journey and level")
	home.confirm_next_cycle();await process_frame;var confirm=choice("确认开启")
	if confirm!=null:await mouse_click(confirm)
	check(home.cycle_intro_open and home.gear.campaign.cycle==2 and home.gear.s.level==1,"actual mouse confirmation opens second-cycle story")
	home.depart(0);check(home.mode=="home" and home.cycle_intro_open,"pending cycle story cannot be bypassed through departure")
	home.gear.persist();home.queue_free();await process_frame;home=Home.new();root.add_child(home);await process_frame;await process_frame
	check(home.cycle_intro_open and home.dialog_title.text.contains("第二周目"),"actual restart resumes pending cycle introduction")
	home.finish_cycle_intro();home.close_dialog();home.open_cycles();await process_frame;await capture("01-second-cycle-journal")
	home.close_cycles();home.close_dialog();home.manage_support("anchor");await process_frame;var secondary=choice("装入副支援")
	if secondary!=null:await mouse_click(secondary)
	check(home.gear.cycles.secondary_support=="anchor","actual support menu equips second device by mouse")
	home.close_dialog();home.gear.restore(third);home.gear.home.intro_done=true;home.gear.home.intro_version=2;home.open_cycles();await process_frame
	var resonance=choice(home.gear.Cycles.catalog().resonances[2].name)
	if resonance!=null:await mouse_click(resonance)
	check(home.gear.cycles.resonance==2,"actual archive selects healing resonance by mouse")
	await capture("02-third-cycle-resonance");home.close_cycles()
	home.gear.restore(last_pending);home.gear.home.intro_done=true;home.gear.home.intro_version=2
	home.gear.events.serial+=1;home.gear.events.pending={"id":"orbital_dust","ticket":home.gear.events.serial};materials=home.gear.events.materials
	home.gear.persist();home.present_pending_event()
	check(not home.ending_open and home.dialog_title.text.contains("归来事件"),"last return first resolves already-earned random event before definitive ending")
	home.finish_pending_event();home.dialog_text.visible_characters=-1;home.next_line()
	check(home.gear.events.materials==materials+12 and home.gear.events.pending.is_empty(),"last return reward survives intact before final credits")
	check(home.ending_open and home.lines[-1][0]=="无限异常 · 完","third victory plays distinct final ending rather than first-cycle text")
	home.line_index=home.lines.size()-1;home.render_line();home.dialog_text.visible_characters=-1;home.arrival=0;home.queue_redraw();await capture("03-definitive-ending")
	home.finish_ending();home.close_dialog();home.open_cycles();await process_frame
	check(not home.gear.can_start_cycle() and home.cycles_ui==null,"final UI offers no fourth-cycle button or public cycle archive")
	await capture("04-completed-three-journeys");home.close_cycles();home.gear.persist();home.queue_free();await process_frame
	home=Home.new();root.add_child(home);await process_frame;await process_frame
	check(home.gear.cycles.game_complete and not home.ending_open and home.gear.cycles.history.size()==3,"actual restart keeps definitive completion without replaying ending")
	var failures=checks.filter(func(entry):return not entry.pass)
	write_json(doc+"verification.json",{"checks":checks,"failures":failures,"normal_player_save_used":false,"cycles":3,"normal_campaign_assets_created":false})
	print("CYCLES %d checks %d failures"%[checks.size(),failures.size()]);home.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
