extends SceneTree
const Campaign=preload("res://scripts/pixel_home/campaign.gd")
const Legacy=preload("res://scripts/pixel_home/campaign_legacy.gd")
const Gear=preload("res://scripts/pixel_home/gear.gd")
const Narrative=preload("res://scripts/pixel_home/narrative.gd")
const Finale=preload("res://scripts/pixel_home/finale.gd")
const Cycles=preload("res://scripts/pixel_home/cycles.gd")
var checks=[]
func check(ok:bool,label:String)->void:
	checks.append({"pass":ok,"name":label})
	if not ok:push_error(label)

func old_progress(cycle:int,planets:int=0,graduated:bool=true)->Dictionary:
	var c=Legacy.initial();c.cycle=cycle
	if not graduated:return c
	for id in range(1,301):Legacy.apply_result(c,id,3,10,0,50.0,true)
	c.phase="cosmos";c.graduation_seen=true;c.pending_story="";c.story_seen=["graduation"]
	for id in range(301,301+planets):Legacy.apply_result(c,id,3,10,0,50.0,true)
	return c

func old_save(cycle:int=1,planets:int=0,status:String="idle",graduated:bool=true)->Dictionary:
	var g=Gear.new(445);var data=g.snapshot()
	data.campaign=old_progress(cycle,planets,graduated)
	data.home.erase("seen_rooms");data.home.seen_levels=[1,2] if graduated else [1]
	data.cosmos=Gear.Cosmos.from_campaign(data.campaign)
	if cycle>1:Gear.Cosmos.unlock(data.cosmos)
	data.narrative=Narrative.initial()
	for chapter in Narrative.catalog().chapters:
		if graduated and chapter.clears<=planets:data.narrative.seen.append({"id":chapter.id,"cycle":cycle})
	data.finale=Finale.initial(cycle)
	if status!="idle":
		data.finale.status=status;data.finale.attempts=1
		data.finale.next=1 if status=="active" else 4
		for i in range(5):data.finale.checkpoint.append({"hp":0.75,"shield":0.1})
		for i in range(data.finale.next):data.finale.battles.append({"id":Finale.catalog().battles[i].id,"seconds":60.0,"downs":0})
		data.finale.ending_seen=status=="complete"
	data.cycles=Cycles.initial()
	for i in range(1,cycle+(1 if status=="complete" else 0)):data.cycles.history.append(Cycles.receipt(i,50))
	if cycle==3:data.cycles.resonance=1
	data.cycles.game_complete=cycle==3 and status=="complete"
	return data

func fill_earth(c:Dictionary,mask:int)->void:
	var r=Campaign.empty_record()
	r.mask=mask;r.clears=Campaign.difficulty_count(r);r.best_depth=Campaign.difficulties(r).back()
	r.gold=r.clears>=5;r.gold_depth=r.best_depth if r.gold else 0;r.best_seconds=5.0
	for id in range(1,1001):c.levels[Campaign.key(id)]=r.duplicate(true)

func _initialize()->void:
	var c=Campaign.initial();check(Campaign.valid(c),"new campaign validates")
	check(c.gate=="shimmer","confirmed default gate requires all earth rooms shimmering")
	var before=c.duplicate(true)
	for args in [[0,1,10,true],[2001,1,10,true],[1,0,10,true],[1,11,10,true],[1,1,9,true],[1,1,10,false],[1001,1,10,true]]:
		check(Campaign.apply_result(c,args[0],args[1],args[2],0,1.0,args[3]).is_empty(),"reject invalid run "+str(args))
	check(c==before,"rejected results do not mutate the ledger")
	for depth in [10,10,10,7,2,4,9,1,3,5,6,8]:
		var r=Campaign.apply_result(c,1,depth,10,2,10.0,true)
		check(Campaign.valid(c),"valid record after difficulty "+str(depth))
		if c.levels.R0001.clears==3:check(r.difficulty_count==1 and r.badge=="clear","repeats do not count as different difficulties")
		if c.levels.R0001.clears==5:check(r.difficulty_count==3 and r.badge=="silver","three nonconsecutive difficulties earn silver despite a death")
		if c.levels.R0001.clears==7:check(r.difficulty_count==5 and r.badge=="gold","five actual difficulties earn gold")
	check(c.levels.R0001.mask==1023 and Campaign.badge(c.levels.R0001)=="shimmer","all ten actual difficulties earn shimmer")
	var bad=c.duplicate(true);bad.levels.R0001.mask=1
	check(not Campaign.valid(bad),"inconsistent badge mask rejected")
	for gate in Campaign.GATES:
		var boundary=Campaign.initial(gate);fill_earth(boundary,1 if gate=="clear" else 31 if gate=="gold" else 1023)
		boundary.levels.erase("R1000")
		check(not Campaign.eligible(boundary),"999 rooms cannot unlock "+gate)
		boundary.levels["R1000"]=boundary.levels.R0001.duplicate(true)
		check(Campaign.eligible(boundary) and Campaign.valid(boundary),"1000 rooms satisfy "+gate)
		if gate!="clear":
			boundary.levels.erase("R1000");Campaign.apply_result(boundary,1000,10,10,0,1.0,true)
			check(not Campaign.eligible(boundary),"high difficulty alone cannot bypass "+gate)
	var silver_only=Campaign.initial();fill_earth(silver_only,7)
	check(not Campaign.eligible(silver_only),"1000 silver rooms cannot unlock space")
	var gold_only=Campaign.initial();fill_earth(gold_only,31)
	check(not Campaign.eligible(gold_only),"1000 gold rooms cannot unlock space")
	var nine=Campaign.initial();fill_earth(nine,1023);nine.levels.erase("R1000")
	for d in range(1,10):Campaign.apply_result(nine,1000,d,10,0,1.0,true)
	check(not Campaign.eligible(nine),"999 shimmering rooms and nine difficulties on last room cannot unlock")
	Campaign.apply_result(nine,1000,10,10,0,1.0,true)
	check(Campaign.eligible(nine) and nine.pending_story=="graduation","last missing tenth difficulty triggers graduation exactly")
	for cycle in [1,2,3]:
		for status in ["idle","active","won","complete"]:
			var data=old_save(cycle,300,status);var original=data.duplicate(true);var g=Gear.new(1)
			check(g.restore(data),"restore old cycle %d status %s"%[cycle,status])
			check(data==original,"migration does not mutate input")
			check(g.campaign.schema==2 and g.campaign.levels.is_empty() and g.campaign.legacy==data.campaign,"old scores archived without new room badges")
			check(g.snapshot().state==data.state and g.cosmos==data.cosmos and g.growth==data.growth,"equipment resources skills and growth preserved")
			check(g.finale.status==status and g.finale_eligible(),"old finale access and checkpoint preserved")
			var restored=Gear.new(2)
			check(restored.restore(g.snapshot()) and restored.snapshot()==g.snapshot(),"migrated snapshot round trip")
			check(restored.cycles.game_complete==(cycle==3 and status=="complete"),"third ending remains final")
	for planets in [0,1,29,30,59,60,119,120,199,200,279,280,299,300]:
		var data=old_save(1,planets);data.narrative=Narrative.initial();Narrative.reserve(data.narrative,data.campaign)
		var g=Gear.new(1)
		check(g.restore(data) and g.narrative.pending==data.narrative.pending,"pending story survives migration at "+str(planets))
	var corrupted=old_save();corrupted.campaign.levels.L001.gold_depth=2
	var stable=Gear.new(123);var snapshot=stable.snapshot()
	check(not stable.restore(corrupted) and stable.snapshot()==snapshot,"bad old ledger rejected without partial restore")
	corrupted=old_save();corrupted.cosmos.mastery=301
	check(not stable.restore(corrupted),"old mastery cannot exceed old ceiling")
	var migrated=Gear.new(7)
	check(migrated.restore(old_save(1,0,"idle",false)) and not migrated.graduation_pending(),"unfinished old earth remains unfinished")
	check(migrated.unlocked_depth()==10 and migrated.can_enter_level(1000) and not migrated.can_enter_level(1001),"ten difficulties and phase boundary")
	var layout=Campaign.Layout.expand(JSON.parse_string(FileAccess.get_file_as_string("res://assets/pixel_campaign/first_two.json")).levels).levels
	migrated.growth.scenes["hyakki:R02-S03"]={"clears":1,"best_depth":1}
	check(migrated.encountered_levels(layout)==[1,3],"only reveal entered picture and real picture clear evidence")
	var path="user://room-migration-"+str(Time.get_ticks_usec())+".json"
	var writer=Gear.Save.new(path);var source=old_save(1,300,"active")
	check(writer.save(source),"write isolated old fixture")
	var hash=FileAccess.get_sha256(path);var loaded=Gear.new(8);loaded.open_profile(path)
	check(loaded.persistence_enabled and loaded.home_migration_backup.contains(".before-room-campaign-"),"migration creates named backup before any new write")
	check(FileAccess.get_sha256(path)==hash and FileAccess.get_sha256(loaded.home_migration_backup)==hash,"original and migration backup bytes identical")
	check(loaded.persist(),"persist new room schema")
	var reread=Gear.new(9);reread.open_profile(path)
	check(reread.campaign.schema==2 and reread.finale.status=="active" and reread.persistence_enabled,"disk migration round trip")
	check(FileAccess.get_sha256(loaded.home_migration_backup)==hash,"new save cannot overwrite migration backup")
	var recovery_path=path+"-recovery.json";var recovery_writer=Gear.Save.new(recovery_path)
	check(recovery_writer.save(source) and recovery_writer.save(source),"prepare recovery backup")
	var broken=FileAccess.open(recovery_path,FileAccess.WRITE);broken.store_string("{invalid");broken.close()
	var recovering=Gear.new(9);recovering.open_profile(recovery_path)
	check(recovering.persistence_enabled and not recovering.recovery_backup.is_empty(),"recover backup when primary corrupt")
	check(FileAccess.get_sha256(recovering.recovery_backup)==FileAccess.get_sha256(recovering.home_migration_backup),"migration retains exact recovered source")
	var failed=checks.filter(func(entry):return not entry.pass)
	var out=FileAccess.open("res://docs/room-campaign-2000-20261029/migration-verification.json",FileAccess.WRITE)
	out.store_string(JSON.stringify({"checks":checks,"failures":failed,"normal_profile_used":false,"scope":"production campaign/save migration; battle and UI integration pending"},"\t"));out.close()
	print("ROOM_MIGRATION %d checks %d failures"%[checks.size(),failed.size()]);quit(0 if failed.is_empty() else 1)
