extends SceneTree
const Gear=preload("res://scripts/pixel_home/gear.gd")
const Battle=preload("res://scripts/pixel_home/battle.gd")
const Data=preload("res://scripts/pixel_home/demo_data.gd")
var checks=[]
func check(ok:bool,label:String)->void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
func clear_room(m)->void:
	m.start()
	for wave in range(10):
		for enemy in m.units.slice(5):m.damage(-1,enemy.uid,enemy.max_hp+100,"boundary fixture")
		m.advance(.02)
		if wave<9:m.advance_stage()
func _initialize()->void:
	var source=JSON.parse_string(FileAccess.get_file_as_string("res://assets/pixel_campaign/first_two.json")).levels[0]
	var themes=[]
	for theme in [100,301,400]:
		var copy=source.duplicate(true);copy.id=theme;copy.campaign_id=theme;copy.world_key="L%03d"%theme;copy.test_only=true;themes.append(copy)
	var expanded=Gear.Campaign.Layout.expand(themes).levels
	var monotone=true
	for room in range(1,2001):
		var rating=Gear.Campaign.Layout.rating_base(room)
		monotone=monotone and rating>=Gear.Campaign.Layout.rating_base(room-1) and rating>=1
	check(monotone and Gear.Campaign.Layout.rating_base(1000)==1000 and Gear.Campaign.Layout.rating_base(2000)==1350,"rating remains monotone and space pacing matches shorter one-clear route")
	check(expanded.filter(func(level):return level.room_id==2000)[0].rating_base==1350,"actual expanded final room uses calibrated pressure")
	var selected=[]
	for id in [1000,1001,2000]:selected.append(expanded.filter(func(level):return level.room_id==id)[0])
	var g=Gear.new(415);g.open_profile("user://room-boundaries-%d.json"%Time.get_ticks_usec())
	Data.earth_fixture(g);g.campaign.pending_story="";g.campaign.levels.erase("R1000")
	for difficulty in range(1,10):g.record_level_result(1000,difficulty,10,0,50,true)
	check(not g.graduation_pending() and not g.can_enter_level(1001),"999 shimmer plus nine difficulties in room 1000 cannot unlock space")
	g.record_level_result(1000,9,10,0,50,true)
	check(not g.graduation_pending(),"repeat ninth difficulty cannot stand in for missing tenth")
	var m=Battle.new();m.configure_levels(selected);m.attach(g);m.depth=10;m.reset();clear_room(m)
	check(g.campaign.levels.R1000.mask==1023 and g.graduation_pending(),"actual tenth wave at room 1000 difficulty ten completes Earth shimmer")
	check(not m.advance_stage() and m.chapter_id()==1000,"auto advance stops for graduation story before space")
	check(g.finish_graduation() and g.can_enter_level(1001),"graduation saves and opens exact 1000/1001 boundary")
	Data.drain_story(g);m.depth=1;m.reset(1);clear_room(m)
	check(g.campaign.levels.has("R1001") and g.cosmos.mastery==1,"first space room records native id and mastery one")
	check(not m.advance_stage() and m.chapter_id()==1001,"missing intermediate content cannot jump from room 1001 to 2000")
	var specimen=g.campaign.levels.R1001.duplicate(true)
	for id in range(1002,2000):g.campaign.levels[Gear.Campaign.key(id)]=specimen.duplicate(true)
	g.cosmos.mastery=999;Data.drain_story(g)
	check(not g.finale_eligible(),"999 space rooms cannot unlock finale")
	m.reset(2);clear_room(m)
	check(g.campaign.levels.R2000.mask==1 and g.cosmos.mastery==1000,"room 2000 single difficulty completes the space route")
	check(not g.finale_eligible() and g.story_waiting(),"final main story remains required after last space room")
	Data.drain_story(g)
	check(g.finale_eligible(),"1000 space clears plus core story unlock four bosses without extra shimmer gate")
	var equipment=g.s.inventory.duplicate(true);var equipped=g.s.equipped.duplicate(true)
	var core_inventory=g.cosmos.inventory.duplicate(true);var learned=g.cosmos.skills.duplicate(true) if g.cosmos.has("skills") else {}
	for cycle in range(1,4):
		if cycle>1:
			Data.reach_finale(g)
		g.events.pending={};g.events.ticket={}
		check(g.begin_finale(),"native route can start finale in cycle "+str(cycle))
		var party=[]
		for i in range(5):party.append({"hp":.7 if i!=1 else 0.0,"shield":.12 if i!=1 else 0.0})
		for boss in range(4):
			check(g.save_finale_result(boss,true,party,50.0),"save ordered boss "+str(boss+1)+" cycle "+str(cycle))
			check(g.finale.checkpoint==party,"boss checkpoint retains downed member and shield")
		g.complete_trip();g.events.pending={}
		check(g.finish_ending(),"finish native ending cycle "+str(cycle))
		var receipt=g.cycles.history[-1]
		check(receipt.schema==2 and receipt.earth_shimmer==1000 and receipt.planet_clears==1000 and not receipt.legacy_earth,"new cycle receipt requires actual new totals")
		var before=g.snapshot();var restored=Gear.new(9);restored.open_profile(g.persistence.path)
		check(restored.persistence_enabled and restored.snapshot()==before,"native completed cycle reopens exactly")
		if cycle<3:
			check(g.start_next_cycle(),"transition to cycle "+str(cycle+1))
			check(Gear.Save.new(g.cycle_backup).load_primary()==before,"independent cycle archive contains completed route")
			check(g.s.level==1 and g.s.xp==0 and g.s.inventory==equipment and g.s.equipped==equipped,"cycle reset preserves every piece and slot at level one")
			check(g.cosmos.inventory==core_inventory and (learned.is_empty() or g.cosmos.skills==learned),"cycle reset preserves star cores and learned skills")
			check(g.campaign.levels.is_empty() and g.home.seen_rooms.is_empty() and not g.can_enter_level(1001),"new cycle clears room progress and closes space")
			check(g.finish_cycle_intro(),"finish next-cycle opening")
		else:check(g.cycles.game_complete and not g.can_start_cycle() and not g.can_enter_level(1),"third ending is final with no fourth journey")
	var failures=checks.filter(func(row):return not row.pass)
	var f=FileAccess.open("res://docs/room-campaign-2000-20261029/boundary-verification.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"normal_profile_used":false,"fixture_content_only":true,"cycles":3},"\t"));f.close()
	print("ROOM_BOUNDARIES ",checks.size()," checks ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
