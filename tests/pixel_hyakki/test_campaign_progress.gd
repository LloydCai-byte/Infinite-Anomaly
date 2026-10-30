extends SceneTree
const Gear=preload("res://scripts/pixel_home/gear.gd")
const Battle=preload("res://scripts/pixel_home/battle.gd")
const Campaign=preload("res://scripts/pixel_home/campaign.gd")
const Home=preload("res://scripts/pixel_home/home.gd")
class FailingGear extends Gear:
	var fail=false
	func persist() -> bool:
		if fail:last_error="isolated simulated disk failure";return false
		return super.persist()
var checks=[]
var doc="res://docs/hub-cosmos-campaign-20261028/campaign-test/"
var home
var definitions:Array

func check(ok:bool,label:String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)

func _initialize() -> void:
	if DisplayServer.get_name()=="headless":
		printerr("This suite requires a rendered window for real mouse-input verification; omit --headless.");quit(2);return
	root.size=Vector2i(1600,900);root.content_scale_size=Vector2i(1600,900)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--home-test-output="):doc=arg.trim_prefix("--home-test-output=").trim_suffix("/")+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(doc));call_deferred("run")

func model_for(g,depth:int=1,index:int=0):
	var m=Battle.new();m.configure_levels(definitions);m.attach(g);m.depth=depth;m.reset(index);m.start();return m

func complete_level(m) -> void:
	var limit=m.time+3000
	while m.phase in ["fight","clear"] and m.time<limit:
		if m.phase=="clear":
			if m.is_level_end():break
			m.advance_stage()
		else:m.advance(.25)

func fill_gold(state:Dictionary,last:int=300) -> void:
	for id in range(1,last+1):Campaign.apply_result(state,id,3,10,0,90.0,true)

func capture(name:String) -> void:
	if DisplayServer.get_name()=="headless":return
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(doc+name+".png")

func click(button:Button) -> void:
	await process_frame;await process_frame
	var point=button.get_global_rect().get_center()
	var motion=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;root.push_input(motion)
	var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=point;event.global_position=point;event.pressed=true;root.push_input(event)
	event=event.duplicate();event.pressed=false;root.push_input(event);await process_frame;await process_frame

func run() -> void:
	definitions=JSON.parse_string(FileAccess.get_file_as_string("res://assets/pixel_campaign/first_two.json")).levels
	var g=Gear.new(71);var m=model_for(g);complete_level(m)
	check(m.phase=="clear" and m.kills==50,"natural first level completes all ten scenes and fifty enemies")
	check(g.campaign.levels.L001.clears==1 and not g.campaign.levels.L001.gold,"strength one counts clear without gold")
	check(g.growth.scenes.size()==10 and g.growth.worlds.hyakki.clears==1,"new ledger does not duplicate existing growth rewards")
	check(g.unlocked_depth()==4,"natural clear unlocks strength three for gold challenge")
	var duplicate=g.snapshot();m.finish("clear")
	check(g.snapshot()==duplicate,"duplicate finish cannot grant a second clear or reward")
	g.s.level=100;m=model_for(g,3);complete_level(m)
	check(m.phase=="clear" and g.campaign.levels.L001.gold,"natural strength three full run awards gold")
	check(m.chapter_result.first_gold and m.chapter_run.downs.is_empty(),"first gold records a death-free complete run")
	check(m.campaign_result_text().contains("首次获得金标"),"battle result exposes first-gold feedback")
	var gold_record=g.campaign.levels.L001.duplicate(true);m=model_for(g,1);complete_level(m)
	check(g.campaign.levels.L001.gold and g.campaign.levels.L001.gold_depth==gold_record.gold_depth,"later low-strength clear preserves earned gold")
	var mortal=Gear.new(11);mortal.s.level=100;var death=model_for(mortal,3)
	death.damage(-1,0,100000000,"test");death.observe_downs();complete_level(death)
	check(death.phase=="clear" and mortal.campaign.levels.L001.clears==1,"a recovered teammate still allows ordinary chapter completion")
	check(not mortal.campaign.levels.L001.gold and mortal.campaign.levels.L001.last_downs==1,"early death followed by revival prevents gold")
	var skip=Gear.new(41);skip.s.level=100;var jump=model_for(skip,3)
	jump.stage=9;jump.spawn_stage();jump.phase="fight";complete_level(jump)
	check(skip.campaign.levels.is_empty(),"boss-only scene jump cannot count as a complete chapter")
	var partial=Gear.new(29);var abort=model_for(partial);abort.advance(2);abort.reset()
	check(partial.campaign.levels.is_empty(),"partial expedition and restart cannot grant a clear")
	var second=model_for(g,3,1);complete_level(second)
	check(second.phase=="victory" and g.campaign.levels.L002.gold,"second actual ten-scene level uses its own stable ledger entry")
	check(g.event_context().cleared==2,"return event stage reads unique campaign clears, not repeat count")
	var state=Campaign.initial();fill_gold(state,299)
	check(not Campaign.eligible(state),"299 cleared and gold chapters never graduate")
	Campaign.apply_result(state,300,1,10,0,90,true)
	check(Campaign.count(state,"earth")==300 and not Campaign.eligible(state),"300 clears but 299 gold remains locked")
	check(Campaign.apply_result(state,300,3,9,0,90,true).is_empty(),"nine scenes cannot award chapter or gold")
	check(Campaign.apply_result(state,300,3,10,0,90,false).is_empty(),"invalid run cannot award chapter or gold")
	check(Campaign.apply_result(state,601,3,10,0,90,true).is_empty(),"out of range chapter cannot enter ledger")
	check(Campaign.apply_result(state,301,3,10,0,90,true).is_empty(),"planet results are locked before graduation")
	Campaign.apply_result(state,300,3,10,0,90,true)
	check(Campaign.eligible(state) and state.pending_story=="graduation" and Campaign.valid(state),"both exact thresholds reserve mandatory graduation story")
	var malformed=state.duplicate(true);malformed.levels.L300.clears=0
	check(not Campaign.valid(malformed),"gold without a chapter clear is invalid")
	malformed=state.duplicate(true);malformed.levels.L601=Campaign.empty_record()
	check(not Campaign.valid(malformed),"save validation rejects unknown chapter keys")
	var legacy=g.snapshot();legacy.erase("campaign");var save=Gear.Save.new(doc+"pre-campaign.json");save.save(legacy)
	var original_hash=FileAccess.get_sha256(save.path);var migrated=Gear.new(9);migrated.open_profile(doc+"pre-campaign.json")
	check(migrated.home_migration_backup.contains(".before-campaign-") and FileAccess.get_sha256(migrated.home_migration_backup)==original_hash,"0.24 save gets exact independent campaign migration backup")
	check(FileAccess.get_sha256(save.path)==original_hash,"opening old profile does not overwrite it")
	check(migrated.s==g.s and migrated.growth==g.growth and migrated.events==g.events and migrated.home==g.home,"migration preserves gear, growth, support, rewards and home")
	check(Campaign.count(migrated.campaign,"earth")==2 and Campaign.count(migrated.campaign,"earth",true)==0,"legacy clears retained while no unrecorded gold is invented")
	check(migrated.persist(),"migrated ledger persists")
	var restored=Gear.new(10);restored.open_profile(doc+"pre-campaign.json")
	check(restored.snapshot()==migrated.snapshot(),"ledger and full inventory survive exact disk round trip")
	var before=restored.snapshot();var bad=before.duplicate(true);bad.campaign.levels.L001.gold=true
	check(not restored.restore(bad) and restored.snapshot()==before,"invalid ledger rejection leaves all current data untouched")
	var graduate=FailingGear.new(8);graduate.campaign=state.duplicate(true);graduate.fail=true;before=graduate.snapshot()
	check(not graduate.finish_graduation() and graduate.snapshot()==before,"failed graduation save rolls back phase and story receipt")
	graduate.fail=false;check(graduate.finish_graduation() and graduate.campaign.phase=="cosmos","retry atomically opens cosmos")
	before=graduate.snapshot();check(not graduate.finish_graduation() and graduate.snapshot()==before,"graduation can only be consumed once")
	check(graduate.can_enter_level(301) and not graduate.can_enter_level(601),"completed graduation opens only valid planet IDs")
	graduate.record_level_result(301,3,10,0,90,true)
	check(graduate.event_context()=={"phase":"cosmos","cleared":1,"cycle":1},"planet events receive actual planet progress")
	var planet_defs=definitions.duplicate(true);planet_defs[0].id=301;planet_defs[0].world_key="qa_planet"
	var future=Battle.new();future.configure_levels(planet_defs);future.attach(graduate);future.reset();future.bridge()
	check(future.world_key()=="qa_planet" and graduate.b.world=="qa_planet","future world keys do not collapse into second Earth world")
	home=Home.new();root.add_child(home);await process_frame;await process_frame
	home.finish_intro();home.close_dialog();home.gear.events=Gear.Events.initial(72);home.gear.campaign=g.campaign.duplicate(true);home.gear.growth=g.growth.duplicate(true)
	home.open_campaign();await process_frame
	check(home.mode=="campaign" and home.campaign_ui.entries==[1,2],"archive only lists both previously played chapters")
	check(home.campaign_ui.content_index(1)==0 and home.campaign_ui.content_index(2)==1 and home.campaign_ui.content_index(3)==-1,"only authored chapters resolve to playable content")
	await capture("01-visited-archive")
	check(home.campaign_ui.scroll!=null and home.campaign_ui.grid.columns==2,"native vertical scrolling replaces numbered pagination")
	home.campaign_ui.choose(1);home.campaign_ui.set_depth(3)
	await click(home.campaign_ui.start)
	check(home.mode=="battle" and home.battle.model.depth==3 and home.battle.model.level_index()==0,"archive mouse action launches actual chosen chapter and strength")
	home.finish_return();home.gear.events=Gear.Events.initial(79);home.event_open=false;home.close_dialog()
	home.gear.campaign=Campaign.initial();home.gear.s.level=100
	for id in range(1,301):
		if id!=2:Campaign.apply_result(home.gear.campaign,id,3,10,0,90,true)
	home.depart(1);home.battle.set_process(false);complete_level(home.battle.model)
	check(home.gear.graduation_pending(),"last missing gold can be earned through the actual battle model")
	check(not home.battle.model.advance_stage(),"battle advancement cannot bypass mandatory graduation")
	home._process(.01)
	check(home.mode=="home" and home.graduation_open,"last gold automatically returns party home and starts graduation")
	home.finish_graduation();home.gear.events=Gear.Events.initial(79);home.event_open=false;home.close_dialog()
	# Explicit isolated completion fixture. Normal saves and real content remain untouched.
	home.gear.campaign=state.duplicate(true);home.gear.cosmos=Gear.Cosmos.initial();home.gear.narrative=Gear.Narrative.initial();home.gear.events.serial=1;home.gear.events.pending={"id":"pulse_parcel","ticket":1}
	check(home.gear.persist(),"complete isolated graduation fixture saves")
	var pending=home.gear.events.pending.duplicate(true);var original_items=home.gear.s.inventory.duplicate(true)
	home.queue_free();await process_frame
	home=Home.new();root.add_child(home);await process_frame;await process_frame
	check(home.graduation_open,"restart before story consumption resumes pending graduation automatically")
	check(home.graduation_open and home.dialog_title.text=="书柜里的档案","mandatory graduation takes precedence over random event")
	check(home.gear.events.pending==pending,"graduation presentation preserves queued random event")
	home.line_index=2;home.render_line();home.dialog_text.visible_characters=-1;home.arrival=0;home.queue_redraw();await capture("03-graduation")
	home.finish_graduation()
	check(home.gear.campaign.phase=="cosmos" and home.gear.events.pending==pending,"graduation opens cosmos without consuming random rewards")
	check(home.gear.s.inventory==original_items,"graduation never replaces or clears gear")
	var disk=Gear.new(4);disk.open_profile(home.gear.persistence.path)
	check(disk.campaign==home.gear.campaign and not disk.graduation_pending(),"restarting after graduation cannot replay or duplicate unlock")
	home.dialog_text.visible_characters=-1;home.next_line()
	check(home.story_open and home.dialog_title.text.contains("宇宙主线"),"mandatory cosmos introduction precedes queued random story")
	home.finish_story("star_gate")
	check(home.event_open and home.dialog_title.text.contains("归来事件"),"queued random story resumes after critical story receipt")
	home.finish_pending_event();home.close_dialog();home.open_campaign();await capture("04-after-story-reveal")
	check(home.campaign_ui.frontier==0 and not home.campaign_ui.new_mission.visible,"revealed planet route does not pretend unfinished content is playable")
	var failures=checks.filter(func(c):return not c.pass)
	var file=FileAccess.open(doc+"verification.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"normal_player_save_used":false,"real_playable_levels":2,"planned_levels":600,"gold_rule":Campaign.GOLD_RULE},"\t"));file.close()
	print("CAMPAIGN_PROGRESS %d checks %d failures"%[checks.size(),failures.size()]);home.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
