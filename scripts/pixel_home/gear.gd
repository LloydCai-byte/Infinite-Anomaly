extends "res://scripts/pixel_hyakki/progression/gear.gd"
const Events=preload("res://scripts/pixel_home/events.gd")
const Campaign=preload("res://scripts/pixel_home/campaign.gd")
const Cosmos=preload("res://scripts/pixel_home/cosmos.gd")
const Narrative=preload("res://scripts/pixel_home/narrative.gd")
const Finale=preload("res://scripts/pixel_home/finale.gd")
const Cycles=preload("res://scripts/pixel_home/cycles.gd")
const Rooms=preload("res://scripts/pixel_home/rooms.gd")
const RoomSave=preload("res://scripts/pixel_home/room_save.gd")
const Salvage=preload("res://scripts/pixel_home/salvage_rules.gd")
var salvage_rules:Dictionary=Salvage.initial()

var home:Dictionary = initial_home()
var home_migration_backup = ""
var events:Dictionary=Events.initial(1)
var campaign:Dictionary=Campaign.initial()
var cosmos:Dictionary=Cosmos.initial()
var narrative:Dictionary=Narrative.initial()
var finale:Dictionary=Finale.initial()
var cycles:Dictionary=Cycles.initial()
var cycle_backup=""
var item_index:Dictionary={}
var indexed_items=0
var indexed_inventory:Array=[]

func _init(seed_value:int=0) -> void:
	super(seed_value);events=Events.initial(card_rng.seed ^ 0x31558)

static func initial_home() -> Dictionary:
	return {"schema":1,"intro_done":false,"intro_version":0,"visits":0,"interactions":{},"position":[800.0,740.0],"room":"living","seen_rooms":[]}

static func valid_home(value:Variant) -> bool:
	if not value is Dictionary or value.get("schema") != 1:return false
	if not value.get("intro_done") is bool:return false
	if not value.get("intro_version",0) is int or value.get("intro_version",0)<0:return false
	if not value.get("visits") is int or value.visits < 0:return false
	if not value.get("interactions") is Dictionary:return false
	if value.has("seen_levels"):
		if not value.seen_levels is Array:return false
		var seen={}
		for id in value.seen_levels:
			if not (id is int or id is float) or id!=int(id) or id<1 or id>600 or seen.has(int(id)):return false
			seen[int(id)]=true
	if value.has("seen_rooms"):
		if not value.seen_rooms is Array:return false
		var seen={}
		for id in value.seen_rooms:
			if not (id is int or id is float) or id!=int(id) or id<1 or id>Campaign.LAST_LEVEL or seen.has(int(id)):return false
			seen[int(id)]=true
	for key in value.interactions:
		if not key is String or not value.interactions[key] is int or value.interactions[key] < 0:return false
	if not value.get("position") is Array or value.position.size() != 2:return false
	if value.get("room","living") not in Rooms.IDS:return false
	for coordinate in value.position:
		if not (coordinate is float or coordinate is int) or not is_finite(float(coordinate)):return false
	return true

func snapshot() -> Dictionary:
	var data = super.snapshot()
	data["home"] = home.duplicate(true)
	data["home_events"] = events.duplicate(true)
	data["campaign"] = campaign.duplicate(true)
	data["cosmos"] = cosmos.duplicate(true)
	data["narrative"] = narrative.duplicate(true)
	data["finale"] = finale.duplicate(true)
	data["cycles"] = cycles.duplicate(true)
	data["salvage_rules"] = salvage_rules.duplicate(true)
	return data

func make_save_store(path:String):return RoomSave.new(path)

func item_by_id(id:int)->Dictionary:
	if id<=0:return {}
	if not is_same(indexed_inventory,s.inventory):
		item_index.clear();indexed_items=0;indexed_inventory=s.inventory
	if indexed_items>s.inventory.size():item_index.clear();indexed_items=0
	# Monster loot only appends. Index the tail once instead of scanning the bag
	# for every equipped stat and every attack. Restore invalidates all references.
	for i in range(indexed_items,s.inventory.size()):item_index[s.inventory[i].id]=s.inventory[i]
	indexed_items=s.inventory.size()
	return item_index.get(id,{})

func salvage(id:int)->bool:
	if not super.salvage(id):return false
	item_index.erase(id);indexed_items=s.inventory.size();return true

func persist()->bool:
	if not persistence_enabled:return false
	if persistence==null:return true
	# Saving is synchronous: no gameplay mutation can interleave with encoding.
	# Rollback/transaction snapshot() still makes independent deep copies.
	growth.gear_misses=misses
	var data={"state":s,"battle":b,"rng":rng.state,"growth":growth,"card_rng":card_rng.state,"home":home,"home_events":events,"campaign":campaign,"cosmos":cosmos,"narrative":narrative,"finale":finale,"cycles":cycles}
	data["salvage_rules"]=salvage_rules
	var ok=persistence.save(data)
	last_error="" if ok else persistence.error
	return ok

func restore(data:Dictionary) -> bool:
	var candidate_salvage=data.get("salvage_rules",Salvage.initial())
	if not Salvage.valid(candidate_salvage):return false
	var candidate = data.get("home",initial_home())
	if not valid_home(candidate):return false
	if data.has("card_rng") and not data.card_rng is int:return false
	var candidate_events=data.get("home_events",Events.initial(data.get("card_rng",1)^0x31558))
	if not Events.valid(candidate_events):return false
	if data.has("growth") and not Builds.valid(data.growth):return false
	var candidate_campaign=data.get("campaign",Campaign.from_growth(data.get("growth",{})))
	if not Campaign.valid(candidate_campaign):return false
	var candidate_cosmos=data.get("cosmos",Cosmos.from_campaign(candidate_campaign))
	if not Cosmos.valid(candidate_cosmos):return false
	if candidate_campaign.schema==1 and candidate_cosmos.mastery>300:return false
	if candidate_campaign.graduation_seen and not candidate_cosmos.unlocked:return false
	if candidate_campaign.cycle==1 and candidate_cosmos.unlocked and not candidate_campaign.graduation_seen:return false
	if candidate_cosmos.mastery<Campaign.count(candidate_campaign,"cosmos"):return false
	var candidate_narrative=data.get("narrative",Narrative.from_campaign(candidate_campaign))
	if not Narrative.valid(candidate_narrative,candidate_campaign):return false
	var candidate_finale=data.get("finale",Finale.initial(candidate_campaign.cycle))
	if not Finale.valid(candidate_finale,candidate_campaign,candidate_narrative):return false
	var candidate_cycles=data.get("cycles",Cycles.from_progress(candidate_campaign,candidate_finale,int(data.get("state",{}).get("level",1))))
	if not Cycles.valid(candidate_cycles,candidate_campaign,candidate_finale,candidate_events):return false
	var migrated_campaign=Campaign.migrate(candidate_campaign)
	if not Campaign.valid(migrated_campaign) or not Narrative.valid(candidate_narrative,migrated_campaign) or not Finale.valid(candidate_finale,migrated_campaign,candidate_narrative):return false
	if not super.restore(data):return false
	item_index.clear();indexed_items=0
	home = candidate.duplicate(true)
	if not home.has("room"):home.room="living"
	if not home.has("intro_version"):home.intro_version=1 if home.intro_done else 0
	events=candidate_events.duplicate(true)
	campaign=migrated_campaign
	cosmos=candidate_cosmos.duplicate(true)
	narrative=candidate_narrative.duplicate(true)
	finale=candidate_finale.duplicate(true)
	cycles=candidate_cycles.duplicate(true)
	salvage_rules=candidate_salvage.duplicate(true)
	return true

func salvage_plan(quality:int,quantity:int=-1)->Dictionary:return Salvage.plan(self,quality,quantity)

func salvage_one(id:int)->Dictionary:
	last_error="";var item=item_by_id(id)
	if item.is_empty() or item.get("locked",false) or owner(id)>=0:return {"count":0,"gold":0}
	var before=snapshot();var gold=Salvage.remove(self,[id])
	return {"count":1,"gold":gold} if commit_home(before) else {"count":0,"gold":0}

func salvage_batch(quality:int,quantity:int=-1)->Dictionary:
	last_error="";var plan=salvage_plan(quality,quantity)
	if plan.ids.is_empty():return {"count":0,"gold":0}
	var before=snapshot();Salvage.remove(self,plan.ids)
	if not commit_home(before):return {"count":0,"gold":0}
	return {"count":plan.ids.size(),"gold":plan.gold}

func salvage_selection(ids:Array,expected_gold:int)->Dictionary:
	# Confirm exactly the previewed identities, never silently substitute other gear.
	last_error="";var unique={};var gold=0
	for id in ids:
		var item=item_by_id(int(id))
		if unique.has(id) or item.is_empty() or item.get("locked",false) or owner(int(id))>=0:
			last_error="装备状态已改变，请重新选择";return {"count":0,"gold":0}
		unique[id]=true;gold+=salvage_gold(item)
	if ids.is_empty() or gold!=expected_gold:
		last_error="分解数量或收益已改变，请重新确认";return {"count":0,"gold":0}
	var before=snapshot();Salvage.remove(self,ids)
	if not commit_home(before):return {"count":0,"gold":0}
	return {"count":ids.size(),"gold":gold}

func set_auto_salvage(quality:int)->bool:
	if quality < -1 or quality > 5:return false
	var before=snapshot();salvage_rules.auto_max_quality=quality
	return commit_home(before)

func salvage_new_drops(ids:Array)->void:
	if salvage_rules.auto_max_quality<0 or ids.is_empty():return
	var removed=[]
	for id in ids:
		var item=item_by_id(id)
		if not item.is_empty() and item.quality<=salvage_rules.auto_max_quality and not item.get("locked",false) and owner(id)<0:removed.append(id)
	if removed.is_empty():return
	var gold=Salvage.remove(self,removed)
	salvage_rules.auto_count+=removed.size();salvage_rules.auto_gold+=gold
	b.gold=b.get("gold",0)+gold
	b["auto_salvage_gold"]=b.get("auto_salvage_gold",0)+gold
	b["auto_salvage_count"]=b.get("auto_salvage_count",0)+removed.size()
	b.loot=b.loot.filter(func(id):return id not in removed)
	b["drop_events"]=b.get("drop_events",[]).filter(func(drop):return drop.id not in removed)
	for entry in s.loot_log:
		if entry.id in removed:entry["salvaged"]=true

func open_profile(path:String="user://pixel-equipment.json") -> void:
	super.open_profile(path)
	if not persistence_enabled:return
	# Back up the exact snapshot the parent actually restored, including recovery.
	var restored_source=recovery_backup if not recovery_backup.is_empty() else persistence.path
	for source in [restored_source]:
		var data = persistence.read_path(source)
		if data.is_empty():continue
		if data.has("home") and data.home.has("room") and data.has("home_events") and data.has("campaign") and data.campaign.get("schema")==2 and data.has("cosmos") and data.has("narrative") and data.has("finale") and data.has("cycles"):return
		var prefix=".before-home-" if not data.has("home") else ".before-events-" if not data.has("home_events") else ".before-campaign-" if not data.has("campaign") else ".before-cosmos-" if not data.has("cosmos") else ".before-narrative-" if not data.has("narrative") else ".before-finale-" if not data.has("finale") else ".before-cycles-"
		if data.has("cycles") and not data.home.has("room"):prefix=".before-rooms-"
		if data.has("campaign") and data.campaign.get("schema")==1:prefix=".before-room-campaign-"
		home_migration_backup = persistence.path+prefix+FileAccess.get_sha256(source).substr(0,16)+".json"
		if not FileAccess.file_exists(home_migration_backup) and DirAccess.copy_absolute(source,home_migration_backup) != OK:
			last_error="主神空间升级前备份失败，原档保留，停止写入。";persistence_enabled=false;return
		if persistence.read_path(home_migration_backup) != data:
			last_error="主神空间升级前备份核验失败，原档保留，停止写入。";persistence_enabled=false
		return

func remember_interaction(id:String) -> void:
	home.interactions[id] = home.interactions.get(id,0)+1

func encountered_levels(levels:Array) -> Array:
	var result=[]
	if home.has("seen_rooms"):
		for id in home.seen_rooms:result.append(int(id))
	else:
		# Migrate only evidence of play, never the full available catalogue.
		for level in levels:
			var id=int(level.get("campaign_id",level.get("id",0)))
			var theme=int(level.get("source_theme",0))
			var played=campaign.levels.has(Campaign.key(id))
			var old_seen=not home.has("seen_levels") or theme in home.seen_levels
			if old_seen and level.has("source_scene_id"):
				var evidence=level.source_world_key+":"+level.source_scene_id
				played=played or growth.scenes.has(evidence) or (theme in home.get("seen_levels",[]) and level.source_image_index==0)
			if played and id>=1 and id<=Campaign.LAST_LEVEL and id not in result:result.append(id)
	result.sort();return result

func mark_encounter(id:int,levels:Array) -> bool:
	if id<1 or id>Campaign.LAST_LEVEL:return false
	var seen=encountered_levels(levels)
	if home.has("seen_rooms") and id in seen:return true
	var before=snapshot()
	if id not in seen:seen.append(id)
	seen.sort();home.seen_rooms=seen
	return commit_home(before)

func unlocked_depth() -> int:return 10

func total_kills() -> int:
	var total=0
	for value in s.kills.values():total+=int(value)
	return total

func total_clears() -> int:
	var total=0
	for value in growth.scenes.values():total+=int(value.clears)
	return total

func event_context() -> Dictionary:
	return {"phase":campaign.phase,"cleared":Campaign.count(campaign,campaign.phase),"cycle":campaign.cycle}

func record_level_result(id:int,depth:int,scene_total:int,downs:int,seconds:float,complete_run:bool) -> Dictionary:
	if cycles.game_complete or cycles.pending_intro!=0:return {}
	var result=Campaign.apply_result(campaign,id,depth,scene_total,downs,seconds,complete_run)
	if not result.is_empty() and id>Campaign.EARTH_COUNT:cosmos.mastery=maxi(cosmos.mastery,Campaign.count(campaign,"cosmos"))
	if not result.is_empty():Narrative.reserve(narrative,campaign)
	return result

func graduation_pending() -> bool:return Campaign.eligible(campaign)

func record_room_result(level:Dictionary,depth:int,waves:Array,downs:int,seconds:float,complete_run:bool) -> Dictionary:
	if not level.get("room_mode",false) or waves!=range(1,11):return {}
	var id=int(level.get("room_id",0))
	if Campaign.Layout.room_id(int(level.get("source_theme",0)),int(level.get("source_image_index",-1)))!=id:return {}
	var before=snapshot()
	var result=record_level_result(id,depth,waves.size(),downs,seconds,complete_run)
	if result.is_empty():return {}
	record_clear(level.source_world_key,level.source_scene_id,depth,level.source_image_index==9)
	return result if commit_home(before) else {}

func finish_graduation() -> bool:
	if not graduation_pending():return false
	var before=snapshot();campaign.phase="cosmos";campaign.graduation_seen=true;campaign.pending_story=""
	if "graduation" not in campaign.story_seen:campaign.story_seen.append("graduation")
	Cosmos.unlock(cosmos)
	Narrative.reserve(narrative,campaign)
	return commit_home(before)

func story_waiting() -> bool:return not narrative.pending.is_empty() or not Narrative.next_entry(narrative,campaign).is_empty()

func prepare_story() -> bool:
	var before=snapshot()
	if not Narrative.reserve(narrative,campaign):return true
	return commit_home(before)

func complete_story(id:String) -> bool:
	if narrative.pending.is_empty() or narrative.pending.id!=id:return false
	var before=snapshot();narrative.seen.append(narrative.pending.duplicate(true));narrative.pending={}
	Narrative.reserve(narrative,campaign)
	return commit_home(before)

func can_enter_level(id:int) -> bool:
	return id>=1 and id<=Campaign.LAST_LEVEL and (id<=Campaign.EARTH_COUNT or campaign.phase=="cosmos") and not graduation_pending() and not ending_pending() and not cycles.game_complete and cycles.pending_intro==0

func finale_eligible() -> bool:return Finale.eligible(campaign,narrative)
func ending_pending() -> bool:return finale.status=="won"

func begin_finale() -> bool:
	if not finale_eligible() or story_waiting() or not events.pending.is_empty() or not events.ticket.is_empty() or finale.status in ["won","complete"] or cycles.game_complete or cycles.pending_intro!=0:return false
	var before=snapshot()
	if finale.status!="active":
		var attempts=finale.attempts+1;finale=Finale.initial(campaign.cycle);finale.attempts=attempts;finale.status="active"
	events.serial+=1;events.ticket={"id":events.serial,"kills":total_kills(),"clears":total_clears()}
	return commit_home(before)

func save_finale_result(index:int,won:bool,party:Array,seconds:float) -> bool:
	if finale.status!="active" or finale.next!=index or index<0 or index>=4:return false
	if not is_finite(seconds) or seconds<0 or (won and not Finale.valid_party(party)):return false
	var before=snapshot()
	if won:
		finale.next+=1;finale.checkpoint=party.duplicate(true)
		finale.battles.append({"id":Finale.catalog().battles[index].id,"seconds":seconds,"downs":party.filter(func(member):return member.hp<=0).size()})
		if finale.next==4:finale.status="won"
	else:finale.status="failed"
	return commit_home(before)

func finish_ending() -> bool:
	if not ending_pending():return false
	if campaign.cycle==3 and not events.pending.is_empty():return false
	var before=snapshot();finale.status="complete";finale.ending_seen=true
	cycles.history.append(Cycles.receipt(campaign.cycle,s.level,campaign));cycles.game_complete=campaign.cycle==3
	return commit_home(before)

func commit_home(before:Dictionary) -> bool:
	if persist():return true
	var error=last_error;restore(before);last_error=error;return false

func begin_trip() -> bool:
	if cycles.game_complete or cycles.pending_intro!=0:return false
	if not events.ticket.is_empty() or not events.pending.is_empty():return false
	var before=snapshot();events.serial+=1
	events.ticket={"id":events.serial,"kills":total_kills(),"clears":total_clears()}
	return commit_home(before)

func complete_trip() -> bool:
	if events.ticket.is_empty():return true
	var before=snapshot();var ticket=events.ticket.duplicate(true)
	var eligible=total_kills()>ticket.kills or total_clears()>ticket.clears
	home.visits+=1;events.ticket={}
	if eligible:events.eligible_returns+=1
	var id=Events.roll(events,event_context(),eligible)
	if id!="":events.pending={"id":id,"ticket":ticket.id}
	return commit_home(before)

func claim_event() -> Dictionary:
	if events.pending.is_empty():return {}
	var before=snapshot();var event=Events.find(events.pending.id)
	var reward=[]
	if event.reward.has("material"):
		events.materials+=int(event.reward.material);reward.append("稳定介质 +%d"%int(event.reward.material))
	if event.reward.has("support"):
		var id=event.reward.support
		if events.supports.has(id):events.materials+=3;reward.append("重复装置转为稳定介质 +3")
		else:
			events.supports[id]=1;reward.append("支援装置："+Events.catalog().supports[id].name)
			if events.equipped=="":events.equipped=id;reward.append("已装配")
	var receipt={"id":event.id,"title":event.title,"reward":"；".join(reward) if not reward.is_empty() else "故事已记录","ticket":events.pending.ticket}
	events.seen[event.id]=events.seen.get(event.id,0)+1;events.last[event.id]=events.eligible_returns
	events.history.append(receipt)
	if events.history.size()>50:events.history.pop_front()
	events.pending={}
	if not commit_home(before):return {}
	return receipt

func equip_support(id:String,slot:int=0) -> bool:
	last_error=""
	if slot not in [0,1] or (slot==1 and campaign.cycle<2):return false
	if id!="" and id not in events.supports:return false
	if id!="" and id==(cycles.secondary_support if slot==0 else events.equipped):last_error="同一支援装置不能重复装配。";return false
	var before=snapshot()
	if slot==0:events.equipped=id
	else:cycles.secondary_support=id
	return commit_home(before)

func support_upgrade_cost(id:String) -> int:return int(events.supports.get(id,0))*5

func upgrade_support(id:String) -> bool:
	if id not in events.supports or events.supports[id]>=3:return false
	var cost=support_upgrade_cost(id)
	if events.materials<cost:return false
	var before=snapshot();events.materials-=cost;events.supports[id]+=1;return commit_home(before)

func support_bonus() -> Dictionary:
	var id=events.equipped
	if id=="":return {}
	var entry=Events.catalog().supports[id]
	return {"stat":entry.stat,"value":entry.values[int(events.supports[id])-1]}

func support_bonuses() -> Array:
	var result=[]
	for id in [events.equipped,cycles.secondary_support]:
		if id=="":continue
		var entry=Events.catalog().supports[id];result.append({"stat":entry.stat,"value":entry.values[int(events.supports[id])-1]})
	return result

func rank() -> int:return maxi(super.rank(),int(cycles.get("skill_rank",0)))

func can_start_cycle() -> bool:
	return finale.status=="complete" and campaign.cycle<3 and not cycles.game_complete and events.pending.is_empty() and events.ticket.is_empty()

func start_next_cycle() -> bool:
	last_error=""
	if not can_start_cycle():return false
	var before=snapshot();var next=campaign.cycle+1
	# An independent, checksum-verified snapshot retains the entire completed journey.
	if persistence!=null:
		var hash=Marshalls.raw_to_base64(var_to_bytes(before)).sha256_text().substr(0,16)
		cycle_backup=persistence.path+".before-cycle-%d-"%next+hash+".json"
		var archive=Save.new(cycle_backup)
		if not FileAccess.file_exists(cycle_backup) and not archive.save(before):last_error="周目档案备份失败："+archive.error;return false
		if archive.read_path(cycle_backup)!=before:last_error="周目档案备份核验失败，当前旅程保留。";return false
	cycles.skill_rank=maxi(cycles.skill_rank,super.rank());cycles.pending_intro=next
	if next==3:cycles.resonance=0
	campaign=Campaign.initial();campaign.cycle=next;finale=Finale.initial(next);narrative.pending={}
	s.level=1;s.xp=0;b={};home.position=[800.0,740.0];home.room="living";home.seen_levels=[];home.seen_rooms=[]
	return commit_home(before)

func finish_cycle_intro() -> bool:
	if cycles.pending_intro==0:return false
	var before=snapshot();cycles.pending_intro=0;return commit_home(before)

func choose_resonance(choice:int) -> bool:
	if campaign.cycle<3 or choice not in [0,1,2]:return false
	var before=snapshot();cycles.resonance=choice;return commit_home(before)

func equip_core(id:int,hero:int) -> bool:
	last_error=""
	if not cosmos.unlocked or hero<0 or hero>=5 or (id!=0 and Cosmos.item(cosmos,id).is_empty()):return false
	var before=snapshot()
	if id>0:
		var old=Cosmos.owner(cosmos,id)
		if old>=0:cosmos.slots[old]=0
	cosmos.slots[hero]=id;return commit_home(before)

func lock_core(id:int) -> bool:
	last_error="";var core=Cosmos.item(cosmos,id)
	if core.is_empty():return false
	var before=snapshot();core.locked=not core.locked;return commit_home(before)

func upgrade_core(id:int) -> bool:
	last_error="";var core=Cosmos.item(cosmos,id)
	if core.is_empty() or core.rank>=3:return false
	var cost=Cosmos.upgrade_cost(core)
	if cosmos.stardust<cost:last_error="星尘不足，需要%d。"%cost;return false
	var before=snapshot();cosmos.stardust-=cost;core.rank+=1;return commit_home(before)

func salvage_core(id:int) -> bool:
	last_error="";var core=Cosmos.item(cosmos,id)
	if core.is_empty() or core.locked or Cosmos.owner(cosmos,id)>=0:return false
	var before=snapshot();cosmos.stardust+=Cosmos.salvage_value(core);cosmos.inventory.erase(core);return commit_home(before)

func choose_cosmic_skill(hero:int,choice:int) -> bool:
	last_error=""
	if hero<0 or hero>=5 or not Cosmos.skill_available(cosmos,choice):return false
	var before=snapshot();cosmos.skills[hero]=choice;return commit_home(before)

func cosmic_skill(hero:int) -> Dictionary:
	if hero<0 or hero>=5 or not cosmos.unlocked:return {}
	var choice=cosmos.skills[hero]
	if not Cosmos.skill_available(cosmos,choice):choice=0
	return Cosmos.catalog().skills[hero][choice]

func reward(enemy:Dictionary) -> void:
	var previous_loot=b.get("loot",[]).size()
	super.reward(enemy)
	if not measurement:salvage_new_drops(b.get("loot",[]).slice(previous_loot))
	if measurement or not cosmos.unlocked or int(b.get("campaign_id",0))<=Campaign.EARTH_COUNT:return
	# Planet kills share the existing kill/save transaction and persistent loot RNG.
	cosmos.stardust+=3 if enemy.boss else 1
	var drops=enemy.boss or cosmos.misses>=7 or rng.randf()<.20
	if not drops:cosmos.misses+=1;return
	cosmos.misses=0
	var rank=3 if cosmos.mastery>=120 else 2 if cosmos.mastery>=30 else 1
	var core=Cosmos.add_core(cosmos,Cosmos.TYPES[rng.randi_range(0,2)],rank,rng.randi_range(0,15),"planet:%d"%int(b.campaign_id))
	if not b.has("cosmic_drops"):b.cosmic_drops=[]
	b.cosmic_drops.append(core.duplicate(true))
