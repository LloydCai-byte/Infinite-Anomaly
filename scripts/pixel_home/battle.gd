extends "res://scripts/pixel_hyakki/progression/battle.gd"
const CosmicCombat=preload("res://scripts/pixel_home/cosmic_combat.gd")
const Content=preload("res://scripts/pixel_home/content.gd")
const CycleCombat=preload("res://scripts/pixel_home/cycle_combat.gd")
const RoomLayout=preload("res://scripts/pixel_home/room_layout.gd")
var registry_path=Content.REGISTRY
var allow_test_content=false
var chapter_run:Dictionary={}
var chapter_result:Dictionary={}
var cosmic_actions:Array=[0,0,0,0,0]
var cosmic_triggers:Array=[0,0,0,0,0]
var cosmic_chill:Dictionary={}
var cosmic_run_loot:Array=[]
var cycle_actions:Array=[0,0,0,0,0]
var cycle_total_actions=0
var cycle_triggers=0
var pending_room_outcome:Dictionary={}

func load_content() -> Dictionary:
	var content=Content.load_campaign(registry_path,allow_test_content)
	var rooms=RoomLayout.expand(content.levels)
	content.levels=rooms.levels;content.errors.append_array(rooms.errors);content.reserve_themes=rooms.reserve_themes
	return content

func room_mode() -> bool:return not level_defs.is_empty() and level_defs[level_index()].get("room_mode",false)

func level_offset(index:int) -> int:
	if not level_defs.is_empty() and level_defs[0].get("room_mode",false):return clampi(index,0,level_defs.size())*RoomLayout.WAVES
	return super.level_offset(index)

func level_index(at:int=-1) -> int:
	if at<0:at=stage
	if not level_defs.is_empty() and level_defs[0].get("room_mode",false):
		return int(at/RoomLayout.WAVES) if at>=0 and at<level_defs.size()*RoomLayout.WAVES else 0
	return super.level_index(at)

func apply_loadout() -> void:
	super.apply_loadout()
	if gear!=null:
		apply_authored_enemies()
		if units.size()>5 and units[5].has("cycle_base_hp"):apply_cycle_difficulty()

func encounter_rating() -> int:
	if level_defs.is_empty():return super.encounter_rating()
	var base=int(level_defs[level_index()].get("rating_base",1+int(cfg.encounter.world_offset)*(chapter_id()-1)))
	return base+scene_index()+int(cfg.encounter.depth_stride)*(depth-1)

func chapter_id() -> int:
	if level_defs.is_empty():return 0
	return int(level_defs[level_index()].get("campaign_id",level_defs[level_index()].get("id",0)))

func world_key() -> String:
	if level_defs.is_empty():return "unknown"
	var id=chapter_id()
	return str(level_defs[level_index()].get("world_key",{1:"hyakki",2:"sleepbeast"}.get(id,"L%03d"%id)))

func spawn_stage() -> void:
	super.spawn_stage()
	if gear==null:return
	apply_authored_enemies()
	apply_cycle_difficulty()
	cycle_actions=[0,0,0,0,0];cycle_total_actions=0;cycle_triggers=0
	cosmic_actions=[0,0,0,0,0];cosmic_triggers=[0,0,0,0,0];cosmic_chill={}
	var id=chapter_id()
	if scene_index()==0:
		pending_room_outcome={}
		cosmic_run_loot=[]
		chapter_run={"id":id,"depth":depth,"next":0,"scenes":[],"downs":{},"start_time":time,"valid":scene_count()==10}
		chapter_result={}
	elif chapter_run.is_empty() or chapter_run.get("id",0)!=id or chapter_run.get("next",-1)!=scene_index():
		chapter_run={"id":id,"depth":depth,"next":scene_index(),"scenes":[],"downs":{},"start_time":time,"valid":false}
	observe_downs()

func apply_authored_enemies() -> void:
	var level=level_defs[level_index()] if not level_defs.is_empty() else {}
	if not level.has("enemy_catalog"):return
	var scene=scene_info()
	var rating=encounter_rating()-1
	for i in range(5):
		var u=units[i+5];var id=scene.enemies[i];var entry=level.enemy_catalog[id]
		var health_ratio=float(u.hp)/maxi(1,u.max_hp)
		u.id=Content.ROLES[entry.role];u.name=entry.name;u.species=id;u.visual_id=entry.visual;u.skill_name=entry.skill;u.element="fire" if entry.role=="flame" else "physical"
		u.boss=i in scene.get("boss_slots",[])
		u.max_hp=maxi(1,roundi(entry.hp_base*pow(1+cfg.encounter.hp_step*rating,cfg.encounter.hp_exponent)));u.hp=roundi(u.max_hp*health_ratio)
		u.power=maxi(1,roundi(entry.attack_base*pow(1+cfg.encounter.attack_step*rating,cfg.encounter.attack_exponent)));u.agility=entry.speed
		stats_live[u.uid].hp=u.max_hp;stats_live[u.uid].atk=u.power;stats_live[u.uid].speed=u.agility
		stats_live[u.uid].armor=entry.armor;stats_live[u.uid].resist=entry.resist;base_armor[u.uid]=entry.armor

func apply_cycle_difficulty() -> void:
	var factor=gear.Cycles.difficulty(gear.campaign.cycle)
	var authored=not level_defs.is_empty() and level_defs[level_index()].has("enemy_catalog")
	for u in units.slice(5):
		var ratio=float(u.hp)/maxi(1,u.max_hp)
		if authored or not u.has("cycle_base_hp"):u.cycle_base_hp=u.max_hp;u.cycle_base_attack=u.power
		u.max_hp=roundi(u.cycle_base_hp*factor.hp);u.hp=0 if ratio<=0 else maxi(1,roundi(u.max_hp*ratio));u.power=roundi(u.cycle_base_attack*factor.attack)
		stats_live[u.uid].hp=u.max_hp;stats_live[u.uid].atk=u.power

func observe_downs() -> void:
	if chapter_run.is_empty():return
	for hero in units.slice(0,5):
		if hero.hp<=0:chapter_run.downs[hero.uid]=true

func start() -> void:
	if room_mode() and (depth<1 or depth>10):return
	if gear!=null and gear.has_method("can_enter_level") and not gear.can_enter_level(chapter_id()):return
	if gear!=null and phase=="ready" and not gear.mark_encounter(chapter_id(),level_defs):return
	super.start()

func advance_stage() -> bool:
	if not pending_room_outcome.is_empty():return false
	if room_mode() and not is_level_end():return advance_wave()
	if is_level_end() and gear!=null and gear.has_method("graduation_pending"):
		if gear.graduation_pending():return false
		var next_index=level_index()+1
		if next_index<level_defs.size():
			var entry=level_defs[next_index]
			if room_mode() and int(entry.get("room_id",0))!=chapter_id()+1:return false
			if not gear.can_enter_level(int(entry.get("campaign_id",entry.get("id",0)))):return false
	if phase=="clear" and stage+1<stage_count() and gear!=null:
		var entry=level_defs[level_index(stage+1)]
		if not gear.mark_encounter(int(entry.get("campaign_id",entry.get("id",0))),level_defs):return false
	return super.advance_stage()

func advance_wave() -> bool:
	if phase!="clear":return false
	var party=[]
	for hero in units.slice(0,5):
		party.append({"hp":hero.hp,"charge":hero.charge,"burn":hero.burn,"burn_tick":hero.burn_tick,"dead_time":hero.dead_time,"shield":shields[hero.uid],"dot":dots[hero.uid],"dot_turns":dot_turns[hero.uid],"slow":slows[hero.uid],"armor":stats_live[hero.uid].armor,"agility":hero.agility,"burn_power":burn_power.get(hero.uid,0)})
	var cosmic=cosmic_actions.duplicate();var cosmic_count=cosmic_triggers.duplicate();var chill=cosmic_chill.duplicate()
	var memory=cycle_actions.duplicate();var memory_total=cycle_total_actions;var memory_triggers=cycle_triggers
	stage+=1;spawn_stage()
	cosmic_actions=cosmic;cosmic_triggers=cosmic_count;cosmic_chill=chill
	cycle_actions=memory;cycle_total_actions=memory_total;cycle_triggers=memory_triggers
	for i in range(5):
		var hero=units[i];var saved=party[i]
		hero.hp=mini(hero.max_hp,saved.hp);hero.charge=saved.charge;hero.burn=saved.burn;hero.burn_tick=saved.burn_tick;hero.dead_time=saved.dead_time
		hero.pos=hero.home;hero.anim="idle" if hero.hp>0 else "die";hero.agility=saved.agility
		shields[i]=minf(hero.max_hp*.35,saved.shield);dots[i]=saved.dot;dot_turns[i]=saved.dot_turns;slows[i]=saved.slow
		stats_live[i].armor=saved.armor;burn_power[i]=saved.burn_power
	observe_downs();return true

func tick(dt:float) -> void:
	super.tick(dt);observe_downs()

func finish(result:String) -> void:
	if room_mode():
		finish_room_wave(result);return
	if not scene_awarded and result in ["clear","victory"] and gear!=null:
		observe_downs()
		if not chapter_run.is_empty():
			if chapter_run.id!=chapter_id() or chapter_run.depth!=depth or chapter_run.next!=scene_index():chapter_run.valid=false
			if scene_info().get("id",str(scene_index())) in chapter_run.scenes:chapter_run.valid=false
			chapter_run.scenes.append(scene_info().get("id",str(scene_index())));chapter_run.next=scene_index()+1
			if is_level_end() and gear.has_method("record_level_result"):
				chapter_result=gear.record_level_result(chapter_id(),depth,chapter_run.scenes.size(),chapter_run.downs.size(),time-chapter_run.start_time,chapter_run.valid)
		# Use authored world keys for every future planet; never map all to sleepbeast.
		gear.record_clear(world_key(),scene_info().get("id",str(scene_index()+1)),depth,is_boss_stage())
		scene_awarded=true
	super.finish(result)

func finish_room_wave(result:String) -> void:
	if scene_awarded or not pending_room_outcome.is_empty():return
	if result in ["clear","victory"] and gear!=null:
		observe_downs()
		if chapter_run.is_empty():return
		if chapter_run.id!=chapter_id() or chapter_run.depth!=depth or chapter_run.next!=scene_index():chapter_run.valid=false
		chapter_run.scenes.append(scene_index()+1);chapter_run.next=scene_index()+1
		if is_level_end():
			pending_room_outcome={"level":level_defs[level_index()].duplicate(true),"depth":depth,"waves":chapter_run.scenes.duplicate(),"downs":chapter_run.downs.size(),"seconds":time-chapter_run.start_time,"valid":chapter_run.valid,"phase":result}
	scene_awarded=true
	# Suppress the inherited per-picture award; only a complete room earns it.
	super.finish(result)
	if not pending_room_outcome.is_empty():save_room_outcome()

func save_room_outcome() -> bool:
	if pending_room_outcome.is_empty():return true
	var receipt=pending_room_outcome
	if not receipt.valid:
		phase="defeat";pending_room_outcome={};note("本次十波记录不连续，请重新挑战。");return false
	var result=gear.record_room_result(receipt.level,receipt.depth,receipt.waves,receipt.downs,receipt.seconds,receipt.valid)
	if result.is_empty():
		phase="checkpoint";note("房间成绩未保存，请重试保存。");return false
	chapter_result=result;phase=receipt.phase;pending_room_outcome={};return true

func bridge() -> void:
	super.bridge()
	if gear!=null:gear.b.world=world_key();gear.b.campaign_id=chapter_id()
	if gear!=null and room_mode():gear.b.theme=clampi(int(level_defs[level_index()].source_theme)-1,0,2)
	for u in units.slice(5):
		if u.has("species"):
			gear.b.units[u.uid].species=u.species;gear.b.units[u.uid].boss=u.boss;gear.b.units[u.uid].stats.attack_element=u.element

func begin_action(index:int) -> void:
	if cosmic_chill.has(index):
		units[index].agility=maxf(1,stats_live[index].speed-slows[index]);cosmic_chill.erase(index)
	super.begin_action(index)
	if index>=5 and units[index].has("skill_name") and units[index].hp>0 and not action.is_empty():last_skill=units[index].name+" · "+units[index].skill_name
	if gear!=null:CosmicCombat.on_action(self,index)
	if gear!=null:CycleCombat.on_action(self,index)

func damage(source:int,target:int,amount:int,kind:String) -> void:
	var armor_before=stats_live[target].armor if target>=5 and target<stats_live.size() else -1.0
	super.damage(source,target,amount,kind)
	# The old 40% break cap must not restore armor already removed by a stronger skill.
	if source==1 and armor_before>=0 and gear!=null and gear.cosmos.unlocked and gear.mode(1)==0:
		stats_live[target].armor=minf(stats_live[target].armor,armor_before)

func resolve_event(event:Dictionary,source:int,kind:String) -> void:
	var drops=gear.b.get("cosmic_drops",[]).duplicate(true)
	var recycled=int(gear.b.get("auto_salvage_count",0));var coins=int(gear.b.get("auto_salvage_gold",0))
	super.resolve_event(event,source,kind)
	if recycled>0:
		note("自动分解 %d件 · +%d金币"%[recycled,coins])
		effects.append({"kind":"number","value":"分解 +%d金币"%coins,"pos":Vector2(790,350),"age":0.0,"life":1.5,"color":Color("f0ca7b")})
	for core in drops:
		cosmic_run_loot.append(core.id);note("星核入库："+gear.Cosmos.title(core))
		effects.append({"kind":"number","value":"星核入库","pos":units[maxi(0,source)].pos+Vector2(0,-140),"age":0.0,"life":1.5,"color":Color("b5dce9")})

func cosmic_caption(hero:int) -> String:
	var skill=gear.cosmic_skill(hero)
	return "" if skill.is_empty() else skill.name+" %d/3"%(cosmic_actions[hero]%3)

func campaign_result_text() -> String:
	if phase=="checkpoint":return "房间成绩未保存，请重试保存后继续。"
	if chapter_result.is_empty():return ""
	return "第%d关 · %s"%[chapter_result.id,"首次获得金标" if chapter_result.first_gold else chapter_result.reason]

func preview_stats(hero:int) -> Dictionary:
	var stats=super.preview_stats(hero)
	if gear==null or not gear.has_method("support_bonus"):return stats
	var bonuses=gear.support_bonuses()
	for bonus in bonuses:
		if bonus.stat=="hp":stats.hp*=1.0+bonus.value
	for bonus in bonuses:
		match bonus.stat:
			"shield":stats.shield=minf(stats.hp*Builds.SHIELD_CAP,stats.shield+stats.hp*bonus.value)
			"crit":stats.crit=minf(65,stats.crit+bonus.value)
	stats=gear.Cosmos.apply_stats(gear.cosmos,hero,stats)
	if gear.campaign.cycle>=3 and gear.cycles.resonance==1:stats.shield=minf(stats.hp*Builds.SHIELD_CAP,stats.shield+stats.hp*.08)
	return stats
