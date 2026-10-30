extends SceneTree
const Content=preload("res://scripts/pixel_home/content.gd")
const Gear=preload("res://scripts/pixel_home/gear.gd")
const Battle=preload("res://scripts/pixel_home/battle.gd")
const View=preload("res://scripts/pixel_hyakki/view.gd")
const Home=preload("res://scripts/pixel_home/home.gd")
class FailingGear extends Gear:
	var fail=false
	func persist() -> bool:
		if fail:last_error="isolated simulated disk failure";return false
		return super.persist()
var doc="res://docs/hub-cosmos-campaign-20261028/cosmic-route-test/"
var checks=[]
var view
var home

func check(ok:bool,label:String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
func write_json(path:String,data:Variant) -> void:
	var f=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(data,"\t"));f.close()
func _initialize() -> void:
	if DisplayServer.get_name()=="headless":printerr("This suite captures actual runtime; omit --headless.");quit(2);return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--home-test-output="):doc=arg.trim_prefix("--home-test-output=").trim_suffix("/")+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(doc));call_deferred("run")
func graduate(g) -> void:
	for id in range(1,301):g.record_level_result(id,3,10,0,90,true)
	check(g.finish_graduation(),"isolated full-Earth fixture graduates")
func drain_story(g) -> Array:
	var consumed=[]
	while g.story_waiting():
		if not g.prepare_story():break
		var id=g.narrative.pending.id
		if not g.complete_story(id):break
		consumed.append(id)
	return consumed
func capture(name:String) -> void:
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(doc+name+".png")

func fixture() -> Dictionary:
	var baseline=JSON.parse_string(FileAccess.get_file_as_string(Content.BASE));var roster=JSON.parse_string(FileAccess.get_file_as_string(View.ART+"sprites/roster.json"))
	var result={"schema":1,"test_only":true,"level":{"id":301,"title":"接入验证 · 测试替身","world_key":"qa_planet","phase":"cosmos","rating_base":12,"scenes":[]},"enemies":{},"visuals":{}}
	var sources=["kappa","tengu","oni","umbrella","wheel"]
	for i in range(5):
		var old_id=sources[i];var visual_id="alien_qa_%d"%i;var species="qa_species_%d"%i
		var visual=roster[old_id].duplicate(true);visual.giant=visual.height>84;visual.portrait=View.ART+"sprites/"+old_id+"/portrait.png"
		for clip in Content.CLIPS:visual.clips[clip].path=View.ART+"sprites/"+old_id+"/"+clip+".png"
		result.visuals[visual_id]=visual
		result.enemies[species]={"name":"测试替身%d"%(i+1),"skill":"验证攻击%d"%(i+1),"role":["melee","ranged","heavy","flame","melee"][i],"visual":visual_id,"hp_base":180+20*i,"attack_base":12+i,"speed":20+i,"armor":15+i,"resist":10+i}
	for i in range(10):
		var scene=baseline.levels[0].scenes[i].duplicate(true);scene.id="QA301-%02d"%(i+1);scene.title="测试替身 · 第%d景"%(i+1)
		scene.enemies=result.enemies.keys();scene.boss_slots=[3] if i==9 else [];result.level.scenes.append(scene)
	return result

func run() -> void:
	var registry_hash=FileAccess.get_sha256(Content.REGISTRY);var original=Content.load_campaign()
	check(original.levels.size()==2 and original.visuals.is_empty() and original.errors.is_empty(),"normal registry contains only the two real chapters")
	var pack=fixture();var validation=Content.validate_pack(pack);check(validation.ok,"complete isolated fixture passes content validation")
	if not validation.ok:printerr(validation.error);quit(1);return
	var cases=[]
	var bad=pack.duplicate(true);bad.level.id=2;cases.append([bad,"cannot overwrite existing chapter"])
	bad=pack.duplicate(true);bad.level.phase="earth";cases.append([bad,"planet IDs require cosmos phase"])
	bad=pack.duplicate(true);bad.level.scenes.pop_back();cases.append([bad,"nine scenes rejected"])
	bad=pack.duplicate(true);bad.level.scenes[1].id=bad.level.scenes[0].id;cases.append([bad,"duplicate scene IDs rejected"])
	bad=pack.duplicate(true);bad.level.scenes[0].image="res://missing.png";cases.append([bad,"missing background rejected"])
	bad=pack.duplicate(true);bad.level.scenes[0].enemies.pop_back();cases.append([bad,"four enemy positions rejected"])
	bad=pack.duplicate(true);bad.level.scenes[0].enemies[0]="unknown";cases.append([bad,"unknown species rejected"])
	bad=pack.duplicate(true);bad.level.scenes[0].boss_slots=[2,2];cases.append([bad,"duplicate boss positions rejected"])
	bad=pack.duplicate(true);bad.enemies.qa_species_0.role="missing";cases.append([bad,"unsupported attack role rejected"])
	bad=pack.duplicate(true);bad.enemies.qa_species_0.visual="absent";cases.append([bad,"unregistered visual rejected"])
	bad=pack.duplicate(true);bad.enemies.qa_species_0.hp_base=-1;cases.append([bad,"negative health rejected"])
	bad=pack.duplicate(true);bad.visuals.alien_qa_0.foot=[0,0];cases.append([bad,"inconsistent foot anchor rejected"])
	bad=pack.duplicate(true);bad.visuals.alien_qa_0.height=100;bad.visuals.alien_qa_0.giant=false;cases.append([bad,"ordinary creature cannot silently use giant proportions"])
	bad=pack.duplicate(true);bad.visuals.alien_qa_0.clips.erase("attack");cases.append([bad,"missing attack animation rejected"])
	bad=pack.duplicate(true);bad.visuals.alien_qa_0.clips.idle.frames=999;cases.append([bad,"sheet dimensions checked against frame count"])
	bad=pack.duplicate(true);bad.visuals.alien_qa_0.portrait="res://missing.png";cases.append([bad,"missing portrait rejected"])
	for entry in cases:check(not Content.validate_pack(entry[0]).ok,entry[1])
	write_json(doc+"fixture-pack.json",pack);write_json(doc+"fixture-registry.json",{"schema":1,"packs":[doc+"fixture-pack.json"]})
	var blocked=Content.load_campaign(doc+"fixture-registry.json")
	check(blocked.levels.size()==2 and blocked.errors.size()==1,"test-only content is rejected by normal runtime")
	var loaded=Content.load_campaign(doc+"fixture-registry.json",true)
	check(loaded.levels.size()==3 and loaded.levels[2].id==301 and loaded.errors.is_empty(),"explicit test loader preserves stable planet ID")
	check(loaded.visuals.size()==5 and loaded.files.has(pack.visuals.alien_qa_0.clips.attack.path),"content loader exposes five separate visuals and packaging dependencies")
	write_json(doc+"duplicate-registry.json",{"schema":1,"packs":[doc+"fixture-pack.json",doc+"fixture-pack.json"]})
	var duplicate=Content.load_campaign(doc+"duplicate-registry.json",true)
	check(duplicate.levels.size()==3 and duplicate.errors.size()==1,"duplicate content rejected without discarding valid chapters")
	var g=Gear.new(41);graduate(g);drain_story(g);g.s.level=100;g.open_profile(doc+"planet-combat.json")
	view=View.new();view.model=Battle.new();view.model.registry_path=doc+"fixture-registry.json";view.model.allow_test_content=true
	view.equipment=g;view.save_disabled=true;root.add_child(view);await process_frame;await process_frame
	view.begin_level(2);view.paused=true
	check(view.model.chapter_id()==301 and view.model.encounter_rating()==12,"battle uses authored chapter and strength, independent of list index")
	check(view.model.units[5].species=="qa_species_0" and view.model.units[5].visual_id=="alien_qa_0" and view.model.units[5].name=="测试替身1","species, appearance and name remain independent of attack controller")
	check(view.model.units[8].id=="wang" and view.model.units[8].visual_id=="alien_qa_3","flame controller does not turn alien appearance into the human mage")
	check(view.model.stats_live[5].armor==15 and view.model.stats_live[5].resist==10 and view.model.units[5].agility==20,"authored enemy combat parameters reach live units")
	check(view.battle_actor_scale(view.model.units[0])==2.35 and view.battle_actor_scale(view.model.units[5])==2.25,"original approved hero and rear actor scales remain fixed")
	check(view.portrait_path("alien_qa_3")==pack.visuals.alien_qa_3.portrait and view.clip_path("alien_qa_3","attack")==pack.visuals.alien_qa_3.clips.attack.path,"renderer resolves independent portrait and frame assets")
	view.model.begin_action(8)
	check(view.model.action.ranged and view.model.last_skill=="测试替身4 · 验证攻击4","authored ranged behavior and attack name are active")
	view.model.update_action(.5)
	check(view.model.projectiles.any(func(p):return p.kind=="fire" and p.actor==8),"alien flame attack actually launches original combat projectile")
	view.model.reset(2);view.model.start();view.queue_redraw();await capture("01-content-adapter-test-surrogates")
	while view.model.phase in ["fight","clear"] and view.model.time<2000:
		if view.model.phase=="clear":view.model.advance_stage()
		else:view.model.advance(.25)
	check(view.model.phase=="victory" and view.model.kills==50,"actual independent chapter completes ten scenes and fifty enemies")
	check(g.campaign.levels.has("L301") and g.campaign.levels.L301.clears==1 and g.growth.worlds.has("qa_planet"),"planet win persists to its own campaign and growth records")
	check(g.cosmos.mastery==1 and g.cosmos.stardust>10 and g.cosmos.inventory.size()>5,"planet win drives mastery, real star resources and equipment")
	check(view.model.units[8].boss and not view.model.units[7].boss,"authored boss location overrides old fixed oni slot")
	check(view.model.is_boss_target(8) and not view.model.is_boss_target(7),"existing anti-boss skill targets the actual authored boss")
	view.model.bridge();check(g.b.units[8].boss and g.b.units[5].species=="qa_species_0","reward bridge preserves authored boss and species")
	g.b={};g.persist();var disk=Gear.new(7);disk.open_profile(doc+"planet-combat.json")
	check(disk.snapshot()==g.snapshot(),"real planet combat results survive exact disk reload")
	view.restart();check(view.controls.start.text.contains("接入验证"),"retry selection offers the actual planet instead of resetting to Earth")
	view.model.apply_loadout();check(view.model.stats_live[5].armor==15 and view.model.stats_live[5].resist==10,"equipment reapplication retains authored enemy defenses")
	view.queue_free();await process_frame
	# All main story gates and restart-safe consumption.
	var story=Gear.new(66);check(not story.story_waiting(),"Earth training cannot reveal cosmic main story")
	graduate(story);check(story.narrative.pending.id=="star_gate","graduation reserves the first main story")
	check(drain_story(story)==["star_gate"],"zero planet clears reveals only the opening chapter")
	story.record_level_result(301,1,10,0,90,true);check(drain_story(story)==["first_world"],"first unique planet reveals next chapter")
	for i in range(30):story.record_level_result(301,1,10,0,90,true)
	check(not story.story_waiting(),"repeat clears cannot unlock later lore")
	for id in range(302,600):story.record_level_result(id,1,10,0,90,true)
	var chapters=drain_story(story)
	check(chapters==["nursery_list","hollow_armies","earth_archive","harvest_engine","last_corridor"],"large progress jump queues every earned chapter in order")
	check(not Gear.Narrative.seen(story.narrative,"core_approach",1),"final approach stays locked at 299 planets")
	story.record_level_result(600,1,10,1,90,true);check(drain_story(story)==["core_approach"],"300 planet clears unlock final approach without requiring planet gold")
	check(story.narrative.seen.size()==8 and Gear.Narrative.valid(story.narrative,story.campaign),"all eight main chapters have distinct persistent receipts")
	var failed=FailingGear.new(17);graduate(failed);var before=failed.snapshot();failed.fail=true
	check(not failed.complete_story("star_gate") and failed.snapshot()==before,"failed save preserves pending main story and all equipment")
	failed.fail=false;check(failed.complete_story("star_gate") and not failed.complete_story("star_gate"),"retry consumes story exactly once")
	var legacy=story.snapshot();legacy.erase("narrative");var save=Gear.Save.new(doc+"pre-narrative.json");save.save(legacy);var hash=FileAccess.get_sha256(save.path)
	var migrated=Gear.new(81);migrated.open_profile(doc+"pre-narrative.json")
	check(migrated.home_migration_backup.contains(".before-narrative-") and FileAccess.get_sha256(migrated.home_migration_backup)==hash,"migration keeps exact independent pre-story backup")
	check(migrated.s==story.s and migrated.cosmos==story.cosmos and migrated.campaign==story.campaign and migrated.narrative.pending.id=="star_gate","old progressed saves keep equipment and receive missing story from the start")
	var bad_state=migrated.snapshot();bad_state.narrative.pending={"id":"invented","cycle":1};before=migrated.snapshot()
	check(not migrated.restore(bad_state) and migrated.snapshot()==before,"invalid main-story state rejected without partial mutation")
	home=Home.new();root.add_child(home);await process_frame;await process_frame
	home.finish_intro();home.close_dialog();home.gear.events=Gear.Events.initial(9);home.gear.campaign=g.campaign.duplicate(true);home.gear.cosmos=g.cosmos.duplicate(true);home.gear.narrative=Gear.Narrative.from_campaign(home.gear.campaign)
	home.gear.events.serial=1;home.gear.events.pending={"id":"orbital_dust","ticket":1};home.gear.persist()
	home.queue_free();await process_frame;home=Home.new();root.add_child(home);await process_frame;await process_frame
	check(home.story_open and home.dialog_title.text.contains("星门背面"),"actual restart automatically presents pending cosmic story")
	var pending_event=home.gear.events.pending.duplicate(true);var dust=home.gear.events.materials
	home.depart(0);check(home.mode=="home" and home.story_open,"departure cannot bypass unread critical story")
	home.dialog_text.visible_characters=-1;home.arrival=0;home.queue_redraw();await capture("02-cosmic-main-story")
	home.finish_story("star_gate");check(home.story_open and home.dialog_title.text.contains("没有猎人的星球"),"earned second chapter follows first in actual UI")
	home.finish_story("first_world");check(home.event_open and home.dialog_title.text.contains("归来事件") and home.gear.events.pending==pending_event,"random return story resumes unchanged after main-story queue")
	home.finish_pending_event();check(home.gear.events.materials==dust+12,"queued random reward is still granted once")
	home.close_dialog();before=home.gear.snapshot();home.story_journal();home.dialog_text.visible_characters=-1;await capture("03-world-journal")
	check(home.dialog_title.text.contains("星门背面") and home.gear.snapshot()==before,"world journal replays history without changing rewards or flags")
	check(FileAccess.get_sha256(Content.REGISTRY)==registry_hash and Content.load_campaign().levels.size()==2,"test fixtures never enter or modify normal published content")
	var failures=checks.filter(func(c):return not c.pass)
	write_json(doc+"verification.json",{"checks":checks,"failures":failures,"normal_player_save_used":false,"test_visuals_are_reused_surrogates":true,"real_planet_content_created":false,"main_story_chapters":8})
	print("COSMIC_ROUTE %d checks %d failures"%[checks.size(),failures.size()]);home.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
