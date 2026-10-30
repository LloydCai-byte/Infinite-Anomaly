extends SceneTree
const Gear=preload("res://scripts/pixel_home/gear.gd")
const Battle=preload("res://scripts/pixel_home/battle.gd")
const BaseBattle=preload("res://scripts/pixel_hyakki/progression/battle.gd")
const Events=preload("res://scripts/pixel_home/events.gd")
const Home=preload("res://scripts/pixel_home/home.gd")
class FailingGear extends Gear:
	var fail=false
	func persist() -> bool:
		if fail:last_error="isolated simulated disk failure";return false
		return super.persist()
var checks=[]
var doc="res://docs/hub-cosmos-campaign-20261028/events-test/"
var home

func check(ok:bool,label:String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--home-test-output="):doc=arg.trim_prefix("--home-test-output=").trim_suffix("/")+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(doc));call_deferred("run")

func capture(name:String) -> void:
	if DisplayServer.get_name()=="headless":return
	home._process(.001)
	home.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(doc+name+".png")

func seed_pending(g,id:String) -> void:
	g.events.serial+=1;g.events.ticket={};g.events.pending={"id":id,"ticket":g.events.serial}

func click_button(prefix:String) -> void:
	await process_frame;await process_frame
	for button in home.choices.get_children():
		if button is Button and button.text.begins_with(prefix):
			var point=button.get_global_rect().get_center()
			var motion=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;root.push_input(motion)
			var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=point;event.global_position=point;event.pressed=true;root.push_input(event)
			event=event.duplicate();event.pressed=false;root.push_input(event)
			await process_frame;await process_frame;return
	check(false,"button exists: "+prefix)

func run() -> void:
	var cfg=Events.catalog();var ids={}
	for event in cfg.events:ids[event.id]=true
	check(ids.size()==cfg.events.size() and ids.size()==17,"seventeen distinct authored return events")
	var state=Events.initial(123);var ctx={"phase":"earth","cleared":0,"cycle":1}
	check(Events.valid(state),"fresh event state validates")
	var pool=Events.available(state,ctx,true)
	check(pool.all(func(e):return e.min==0 and e.phase=="earth"),"early Earth cannot draw late/cosmos/replay reveals")
	check(Events.available(state,ctx,false).all(func(e):return e.reward.is_empty()),"empty expeditions can tell stories but never award resources")
	var cosmos=Events.available(state,{"phase":"cosmos","cleared":120,"cycle":1},true)
	check(cosmos.any(func(e):return e.id=="two_earths") and cosmos.all(func(e):return e.phase=="cosmos"),"planet-stage pool excludes Earth stories")
	check(Events.available(state,{"phase":"earth","cleared":0,"cycle":2},true).any(func(e):return e.id=="cycle_memory"),"second-cycle story unlock is gated")
	check(not Events.available(state,ctx,true).any(func(e):return e.id=="last_window"),"third-cycle reveal absent in first run")
	var g=Gear.new(14);g.open_profile(doc+"atomic-event-save.json")
	g.events=Events.initial(14);g.home.visits=0
	var original_items=g.s.inventory.duplicate(true);var original_level=g.s.level
	check(g.begin_trip(),"departure reserves one persistent return ticket")
	check(not g.begin_trip(),"cannot reserve a second ticket while away")
	g.s.kills["qa:events"]=g.s.kills.get("qa:events",0)+1
	check(g.complete_trip() and g.home.visits==1 and g.events.eligible_returns==1,"real combat return consumes one ticket")
	var once=g.snapshot();g.complete_trip()
	check(g.snapshot()==once,"duplicate returns do not reroll or increment counters")
	seed_pending(g,"pulse_parcel");g.persist()
	var restored=Gear.new(88);restored.open_profile(doc+"atomic-event-save.json")
	check(restored.events.pending==g.events.pending,"pending rolled event survives reload unchanged")
	check(not restored.begin_trip(),"pending event cannot be overwritten by another departure")
	var receipt=restored.claim_event()
	check(not receipt.is_empty() and restored.events.supports.pulse==1 and restored.events.materials==3,"event awards a real support device plus materials")
	check(restored.events.equipped=="pulse","first support device is equipped")
	var claimed=restored.snapshot();check(restored.claim_event().is_empty() and restored.snapshot()==claimed,"event rewards cannot be claimed twice")
	var reloaded=Gear.new(71);reloaded.open_profile(doc+"atomic-event-save.json")
	check(reloaded.snapshot()==claimed,"reward, story record and consumption share one save transaction")
	var pre_event=reloaded.snapshot();pre_event.erase("home_events")
	var upgrade_save=Gear.Save.new(doc+"pre-events-upgrade.json");upgrade_save.save(pre_event)
	var upgrade_hash=FileAccess.get_sha256(upgrade_save.path)
	var upgraded=Gear.new(2);upgraded.open_profile(doc+"pre-events-upgrade.json")
	check(upgraded.home_migration_backup.contains(".before-events-") and FileAccess.get_sha256(upgraded.home_migration_backup)==upgrade_hash,"0.23 home saves receive an independent pre-events backup")
	check(not Events.available(reloaded.events,ctx,true).any(func(e):return e.id=="pulse_parcel"),"one-off parcel remains consumed after restart")
	check(reloaded.s.inventory==original_items and reloaded.s.level==original_level,"return events preserve normal inventory and level")
	check(not reloaded.upgrade_support("pulse"),"insufficient materials cannot upgrade")
	seed_pending(reloaded,"blue_grain");reloaded.claim_event()
	check(reloaded.events.materials==7,"materials combine across distinct events")
	check(reloaded.upgrade_support("pulse") and reloaded.events.materials==2 and reloaded.events.supports.pulse==2,"support strengthening consumes correct materials")
	check(not reloaded.equip_support("unowned"),"cannot equip an unowned support")
	reloaded.events.materials=30;reloaded.upgrade_support("pulse")
	var capped=reloaded.snapshot()
	check(not reloaded.upgrade_support("pulse") and reloaded.snapshot()==capped,"support level three cap spends nothing")
	var bad=reloaded.snapshot();bad.home_events.supports.pulse=999
	check(not reloaded.restore(bad) and reloaded.snapshot()==capped,"invalid support rank rejected without mutation")
	bad=reloaded.snapshot();bad.card_rng="bad"
	check(not reloaded.restore(bad),"invalid legacy RNG rejected before event default derivation")
	var failed=FailingGear.new(39);seed_pending(failed,"pulse_parcel");var before=failed.snapshot();failed.fail=true
	check(failed.claim_event().is_empty() and failed.snapshot()==before,"failed save rolls back reward and preserves pending event")
	failed.fail=false;check(not failed.claim_event().is_empty(),"failed claim can be retried exactly once")
	failed=FailingGear.new(27);failed.begin_trip();failed.s.kills["qa"]=1;before=failed.snapshot();failed.fail=true
	check(not failed.complete_trip() and failed.snapshot()==before,"failed return restores ticket and random state")
	var farmer=Gear.new(50)
	for i in range(20):
		farmer.begin_trip();farmer.complete_trip()
		if not farmer.events.pending.is_empty():farmer.claim_event()
	check(farmer.events.materials==0 and farmer.events.supports.is_empty(),"twenty immediate exits cannot farm rewards")
	check(farmer.home.visits==20 and not farmer.events.history.is_empty(),"ordinary home returns still have story opportunities")
	var productive=Gear.new(93);var rewards=0
	for i in range(30):
		productive.begin_trip();productive.s.kills["qa"]=i+1;productive.complete_trip()
		if not productive.events.pending.is_empty():productive.claim_event();rewards+=1
	check(rewards>3 and productive.events.materials>0,"productive expeditions draw and award multiple events")
	check(productive.events.seen.get("pulse_parcel",0)<=1,"one-off support is never duplicated by random draw")
	var campaign=JSON.parse_string(FileAccess.get_file_as_string("res://assets/pixel_campaign/first_two.json")).levels
	var combat_gear=Gear.new(73);var base=BaseBattle.new();base.configure_levels(campaign);base.attach(combat_gear);base.reset()
	var base_stats=base.preview_stats(0);var model=Battle.new();model.configure_levels(campaign);model.attach(combat_gear)
	combat_gear.events.supports={"pulse":3,"sight":2,"anchor":1};combat_gear.events.equipped="pulse";model.reset();model.start()
	check(model.shields[0]>base_stats.shield and model.shields[0]<=model.units[0].max_hp*.35,"equipped pulse supplies actual battle shield with existing cap")
	combat_gear.events.equipped="sight";model.reset()
	check(is_equal_approx(model.stats_live[0].crit,base_stats.crit+4),"sight device changes actual combat critical chance")
	combat_gear.events.equipped="anchor";model.reset()
	check(model.units[0].max_hp>base_stats.hp,"anchor device changes actual combat health")
	combat_gear.events.equipped="";model.reset()
	check(is_equal_approx(model.stats_live[0].crit,base_stats.crit),"unequipping support removes its effect")
	home=Home.new();root.add_child(home);await process_frame;await process_frame
	home.gear.events=Events.initial(69);home.finish_intro();home.close_dialog();home.set_process(false)
	var npc_positions=home.NPCS.map(func(n):return n.foot);var baseline=home.gear.s.duplicate(true)
	home.start_intro();home._process(.1)
	check(home.cinematic and not home.dialog.visible,"opening begins with staged room silence rather than text dump")
	for i in range(18):home._process(.1)
	check(home.intro.knocks==1 and home.intro.door_pulse>0,"first knock drives visible door cue")
	await capture("01-opening-knock")
	for i in range(27):home._process(.1)
	check(home.intro.knocks==3 and home.intro.light_dip>0,"three timed knocks precede light change")
	await capture("02-opening-light")
	for i in range(12):home._process(.1)
	check(home.dialog.visible and home.intro.stage=="dialogue","room staging transitions into dialogue")
	check(home.dialog_text.visible_characters<home.dialog_text.get_total_character_count(),"dialogue reveals text over time")
	home.next_line();check(home.line_index==0 and home.dialog_text.visible_characters==-1,"first advance completes current text without skipping it")
	home.next_line();home.dialog_text.visible_characters=-1;home.next_line();var xuan_start=home.player
	for i in range(100):home._process(.1)
	check(home.player.distance_to(xuan_start)>100,"opening moves Xuan within the room")
	check(home.NPCS.map(func(n):return n.foot)==npc_positions,"all five fighters stay fixed throughout staging")
	await capture("03-opening-dialogue")
	home.finish_intro();home._process(.1)
	check(not home.intro.active and home.intro.shake==Vector2.ZERO and home.path.is_empty(),"skip clears camera, effects, audio timeline and scripted path")
	check(home.gear.home.intro_version==2 and home.gear.s==baseline,"replaying/skipping opening never rewards or resets progress")
	home.start_intro();check(home.intro.knocks==0 and home.intro.elapsed==0,"replay starts with fresh cue timing")
	home.finish_intro();home.player=Vector2(535,290);seed_pending(home.gear,"pulse_parcel");home.present_pending_event()
	check(home.event_open and home.dialog.visible,"actual returned event is presented in home")
	home.finish_pending_event();check(home.gear.events.supports.has("pulse") and home.gear.events.pending.is_empty(),"UI completion grants and consumes support event")
	home.close_dialog();home.support_menu();await process_frame
	check(home.dialog_title.text.begins_with("支援整备"),"support device reachable from home UI")
	home.manage_support("pulse");await capture("04-support-device")
	await click_button("卸下");check(home.gear.events.equipped=="","mouse click unequips the actual support")
	await click_button("装配");check(home.gear.events.equipped=="pulse","mouse click equips the actual support")
	home.gear.events.materials=20
	await click_button("强化");check(home.gear.events.supports.pulse==2 and home.gear.events.materials==15,"mouse strengthening spends materials and raises the real device")
	home.close_dialog();home.event_journal();await capture("05-return-journal")
	check(home.dialog_text.text.contains("脉冲护盾"),"journal retains actual reward receipt")
	var failures=checks.filter(func(c):return not c.pass)
	var file=FileAccess.open(doc+"verification.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"events":17,"supports":3,"future_phase_context_integration":"pending_campaign_tasks","normal_player_save_used":false},"\t"));file.close()
	print("HOME_EVENTS %d checks %d failures"%[checks.size(),failures.size()]);home.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
