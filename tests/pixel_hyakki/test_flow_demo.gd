extends SceneTree
const Demo=preload("res://scripts/pixel_home/flow_demo.gd")
const Data=preload("res://scripts/pixel_home/demo_data.gd")
var doc="res://docs/hub-cosmos-campaign-20261028/demo-test/"
var demo
var checks=[]
var profiles=[]
var natural_runs={}
func check(ok:bool,label:String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
func _initialize() -> void:
	if DisplayServer.get_name()=="headless":quit(2);return
	root.size=Vector2i(1600,900);root.content_scale_size=Vector2i(1600,900)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--home-test-output="):doc=arg.trim_prefix("--home-test-output=").trim_suffix("/")+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(doc));call_deferred("run")
func click(button:Button) -> void:
	await process_frame;await process_frame
	var point=button.get_global_rect().get_center();var motion=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;root.push_input(motion)
	var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=point;event.global_position=point;event.pressed=true;root.push_input(event)
	event=event.duplicate();event.pressed=false;root.push_input(event);await process_frame;await process_frame
func shot(name:String) -> void:
	await process_frame;await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(doc+name+".png")==OK,"capture "+name)
func dialogue() -> void:
	for line in range(200):
		if not demo.home.dialog.visible or demo.home.lines.is_empty():break
		demo.home.dialog_text.visible_characters=-1;demo.home.next_line()
	await process_frame
func choice(prefix:String) -> Button:
	for button in demo.home.choices.get_children():
		if button is Button and button.text.begins_with(prefix):return button
	return null
func back() -> void:
	var event=InputEventKey.new();event.keycode=KEY_F2;event.pressed=true;root.push_input(event);await process_frame;await process_frame
	check(demo.menu.visible and not demo.banner.visible and demo.home==null,"F2 removes active demo and returns to directory")
func select(kind:String) -> void:
	await click(demo.buttons[kind]);await process_frame
	check(demo.current==kind and demo.home!=null and not demo.menu.visible,"mouse opens "+kind)
	check(demo.active_profile.begins_with(ProjectSettings.globalize_path(doc)) and demo.home.battle.profile_locked and demo.home.battle.profile_path==demo.active_profile,"explicit isolated profile for "+kind)
	check(not profiles.has(demo.active_profile),"fresh independent profile for "+kind);profiles.append(demo.active_profile)
func run() -> void:
	var sentinel=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--profile="):sentinel=arg.trim_prefix("--profile=")
	check(sentinel!="","test supplies conflicting profile override")
	if sentinel=="":quit(2);return
	var file=FileAccess.open(sentinel,FileAccess.WRITE);file.store_string("TEST SENTINEL: demo must never touch command-line profile");file.close()
	var hash=FileAccess.get_sha256(sentinel);var registry_hash=FileAccess.get_sha256(Data.Content.REGISTRY);var finale_hash=FileAccess.get_sha256(Data.Content.FINALE_REGISTRY)
	for entry in Data.ENTRIES:
		var g=Data.Gear.new(9);check(g.restore(Data.profile(entry[0])),"valid persistent fixture: "+entry[0])
	check(Data.Content.validate_pack(Data.pack()).ok and Data.Content.validate_pack(Data.pack(true),true).ok,"both explicit surrogate content packs validate")
	demo=Demo.new();demo.data_root=ProjectSettings.globalize_path(doc)+"profiles/";root.add_child(demo);await process_frame
	check(demo.buttons.size()==8 and demo.menu.visible,"directory exposes eight distinct stages");await shot("01-directory")
	await select("opening");check(demo.home.cinematic and demo.home.NPCS.size()==5,"opening has Xuan and five stationary companions")
	demo.home.finish_intro();demo.home.close_dialog();demo.home.arrival=0;await shot("02-xuan-room");await back()
	await select("graduation");check(demo.home.graduation_open,"graduation starts critical story");await dialogue()
	check(demo.home.gear.campaign.phase=="cosmos" and demo.home.gear.cosmos.inventory.size()==5,"graduation unlocks real star gear");await back()
	await select("cosmos");var materials=demo.home.gear.events.materials;await dialogue()
	check(demo.home.gear.events.materials==materials+12 and demo.home.gear.events.pending.is_empty(),"return story grants materials exactly once")
	demo.home.open_cosmos();await process_frame;check(demo.home.mode=="cosmos","cosmic equipment opens in demo");await back()
	await select("planet");demo.home.battle.paused=true;var model=demo.home.battle.model
	check(demo.home.mode=="battle" and model.level_defs[model.level_index()].id==301,"planet demo uses stable campaign 301")
	await shot("03-planet-surrogates")
	while model.phase in ["fight","clear"] and model.time<2000:
		if model.phase=="clear":model.advance_stage()
		else:model.advance(.25)
	check(model.phase=="victory" and model.kills==50,"natural planet demo completes all ten scenes and fifty enemies")
	natural_runs.planet={"phase":model.phase,"kills":model.kills,"seconds":model.time};await back()
	await select("finale");var launch=choice("出发");check(launch!=null,"demo offers actual four-boss launch")
	if launch!=null:await click(launch)
	demo.home.battle.paused=true;model=demo.home.battle.model;check(demo.home.battle.is_finale(),"demo launches real finale model");await shot("04-boss-surrogates")
	while model.phase in ["fight","clear"] and model.time<2000:
		if model.phase=="clear":model.advance_stage()
		else:model.advance(.25)
	check(model.phase=="victory" and model.kills==20,"natural demo defeats four bosses and escorts")
	natural_runs.finale={"phase":model.phase,"kills":model.kills,"seconds":model.time};await process_frame;await process_frame
	check(demo.home.mode=="home" and demo.home.ending_open,"finale automatically returns to Xuan with ending");await dialogue()
	check(demo.home.gear.finale.status=="complete","demo ending persists completion");await back()
	await select("second");var original=demo.home.gear.s.inventory.duplicate(true)
	check(demo.home.mode=="home" and demo.home.dialog.visible,"second-cycle demo opens the ending's next-journey confirmation")
	var confirm=choice("确认开启");check(confirm!=null,"demo uses real next-cycle confirmation")
	if confirm!=null:await click(confirm)
	check(demo.home.gear.campaign.cycle==2 and demo.home.gear.s.level==1 and demo.home.gear.s.inventory==original,"actual second-cycle demo retains every original item at level one");await dialogue();await back()
	await select("third");check(demo.home.cycle_intro_open,"third-cycle demo starts distinct introduction");await dialogue()
	demo.home.open_cycles();await process_frame
	var resonance=choice(demo.home.gear.Cycles.catalog().resonances[2].name)
	if resonance!=null:await click(resonance)
	check(demo.home.gear.cycles.resonance==2 and demo.home.gear.cycles.secondary_support=="anchor","third-cycle demo supports inherited dual devices and chosen resonance");await shot("05-third-cycle");await back()
	await select("ending");check(demo.home.ending_open and demo.home.lines[-1][0]=="无限异常 · 完","true ending demo uses third-cycle final story");await dialogue()
	check(demo.home.gear.cycles.game_complete and not demo.home.gear.can_start_cycle(),"demo true ending leaves complete game and no fourth cycle");await back()
	check(FileAccess.get_sha256(sentinel)==hash,"all demos ignore conflicting normal-profile command argument")
	check(FileAccess.get_sha256(Data.Content.REGISTRY)==registry_hash and FileAccess.get_sha256(Data.Content.FINALE_REGISTRY)==finale_hash,"demos never mutate formal content registries")
	var failures=checks.filter(func(entry):return not entry.pass)
	file=FileAccess.open(doc+"verification.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"natural_runs":natural_runs,"normal_player_save_used":false,"test_surrogates":true},"  "));file.close()
	print("FLOW DEMO %d checks %d failures"%[checks.size(),failures.size()]);demo.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
