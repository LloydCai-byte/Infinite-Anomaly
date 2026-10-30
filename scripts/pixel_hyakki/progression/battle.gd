extends "res://scripts/pixel_hyakki/progression/battle_base.gd"

const Builds = preload("res://scripts/pixel_hyakki/progression/rules.gd")
var skill_used = {}
var base_armor = {}
var burn_sources = {}
var dot_sources = {}
var scene_awarded = false
var encounter_profile = "campaign"
var hazard_power = 0.0
var hazard_elapsed = 0.0
var extra_hits = 0
var skill_healing = 0.0
var skill_shielding = 0.0

func strength() -> float:return 1.0+.06*maxi(0,gear.rank()-1)

func is_boss_target(index:int) -> bool:return units[index].get("boss",is_boss_stage() and units[index].id=="oni")

func preview_stats(hero:int) -> Dictionary:
	var st = super.preview_stats(hero)
	st.hp *= 1.0+.025*gear.card_rank("oni")
	st.crit = minf(65,st.crit+1.2*gear.card_rank("tengu"))
	st.heal += 6.0*gear.card_rank("kappa")
	st.shield += st.hp*.04*gear.card_rank("umbrella")
	st.shield = minf(st.shield,st.hp*Builds.SHIELD_CAP)
	return st

func preview_equipment(id:int,hero:int,slot:String) -> Dictionary:
	var before = preview_stats(hero);var saved = gear.s.equipped.duplicate(true)
	if not gear.equip(id,hero,slot):return {}
	var after = preview_stats(hero);gear.s.equipped = saved
	var delta = {}
	for key in gear.G.AFFIX:delta[key] = after[key]-before[key]
	return {"before":before,"after":after,"delta":delta}

func spawn_stage() -> void:
	super.spawn_stage()
	if gear == null:return
	skill_used = {};base_armor = {};burn_sources = {};dot_sources = {};scene_awarded = false
	hazard_power = 0;hazard_elapsed = 0;extra_hits = 0;skill_healing = 0;skill_shielding = 0
	for u in units.slice(5):
		stats_live[u.uid].armor = 5.0+.18*(encounter_rating()-1)
		stats_live[u.uid].resist = minf(45,10+.04*(encounter_rating()-1))
		base_armor[u.uid] = stats_live[u.uid].armor
	for u in units:shields[u.uid] = minf(shields[u.uid],u.max_hp*Builds.SHIELD_CAP)

func bridge() -> void:
	super.bridge()
	gear.b["world"] = ["hyakki","sleepbeast"][clampi(level_index(),0,1)]
	gear.b["scene_id"] = scene_info().get("id",str(scene_index()+1))
	gear.b["scene_number"] = scene_index()+1
	for u in units:
		gear.b.units[u.uid]["species"] = u.id if u.side == 1 else ""
		gear.b.units[u.uid].stats["attack_element"] = "fire" if u.id in ["wang","wheel"] else "physical"
		if encounter_profile == "boss":gear.b.units[u.uid].boss = u.uid == 7
		elif encounter_profile != "campaign":gear.b.units[u.uid].boss = false

func finish(result:String) -> void:
	if not scene_awarded and result in ["clear","victory"] and gear != null:
		scene_awarded = true
		gear.record_clear(["hyakki","sleepbeast"][clampi(level_index(),0,1)],scene_info().get("id",str(scene_index()+1)),depth,is_boss_stage())
	super.finish(result)
	if gear != null and result in ["clear","victory"] and not gear.persist():note("成长记录保存失败："+gear.last_error)

func begin_action(index:int) -> void:
	skill_used[index] = false
	super.begin_action(index)
	if action.is_empty() or units[index].hp <= 0 or index >= 5:return
	bridge();var event = {"hits":[],"heals":[]};var actor = gear.b.units[index]
	if "barrier" in actor.stats.powers:
		actor.shield = minf(actor.maxhp*Builds.SHIELD_CAP,actor.shield+maxf(0,actor.maxhp*.02-10))
	if index == 1 and gear.mode(1) == 1:
		var allies = gear.alive(0);allies.sort_custom(func(a,b):return gear.b.units[a].hp/gear.b.units[a].maxhp < gear.b.units[b].hp/gear.b.units[b].maxhp)
		if not allies.is_empty():
			var target = gear.b.units[allies[0]]
			var before = target.shield
			target.shield = minf(target.maxhp*Builds.SHIELD_CAP,target.shield+target.maxhp*.065*strength())
			skill_shielding += target.shield-before
	if index == 3 and gear.mode(3) == 0:
		var allies = gear.alive(0);allies.sort_custom(func(a,b):return gear.b.units[a].hp/gear.b.units[a].maxhp < gear.b.units[b].hp/gear.b.units[b].maxhp)
		if not allies.is_empty():
			var target = gear.b.units[allies[0]]
			gear.heal(target.id,(actor.stats.atk*.35+target.maxhp*.02)*strength()*(1+actor.stats.heal/100.0),event)
			for heal in event.heals:skill_healing += heal.amount
	resolve_event(event,index,"skill_support")
	for u in units:shields[u.uid] = minf(shields[u.uid],u.max_hp*Builds.SHIELD_CAP)
	last_skill = units[index].name+" · "+(Builds.MODES[index][gear.mode(index)] if gear.mode(index)>=0 else SKILLS[units[index].id])

func launch(actor:Dictionary,kind:String,power:int) -> void:
	if actor.uid == 4 and gear.mode(4) == 1 and kind == "fire":kind = "fire_burst"
	super.launch(actor,kind,power)

func damage(source:int,target:int,amount:int,kind:String) -> void:
	if gear == null or units[target].hp <= 0:return
	var direct = source >= 0 and kind not in ["burn","dot","test","hazard","skill_splash"]
	var branch = gear.mode(source) if source >= 0 and source < 5 else -1
	var first_hit = direct and source < 5 and not skill_used.get(source,false)
	if direct and source < 5:
		var factor = 1.0
		if gear.mode(3) == 1 and units[3].hp > 0:factor *= 1.0+.12*strength()
		if source == 0 and branch == 0:factor *= 1.0+.25*strength()
		elif source == 0 and branch == 1:factor *= .90
		elif source == 1 and branch == 0:factor *= 1.0+.10*strength()
		elif source == 2 and branch == 0 and (alive(1).size() == 1 or is_boss_target(target) or encounter_profile=="boss"):factor *= 1.0+.25*strength()
		elif source == 4 and branch == 0:factor *= .90
		elif source == 4 and branch == 1:factor *= 1.0+.45*strength()
		amount = maxi(1,roundi(amount*factor))
		if first_hit:skill_used[source] = true
	if kind == "burn":
		# v1 base dispatches burn as an unattributed raw tick. Supply the actual
		# coefficient after its replacement, in this variant's raw damage path.
		bridge();var event = {"hits":[],"heals":[]}
		var value = burn_power.get(target,amount)*(1.0+.05*gear.card_rank("wheel"))
		value *= 1.0-gear.b.units[target].stats.resist/100.0
		gear.deal(target,value,event,false,"燃烧")
		resolve_event(event,burn_sources.get(target,-1),kind);return
	if kind == "dot":
		bridge();var event = {"hits":[],"heals":[]}
		var factor = 1.0+.05*gear.card_rank("wheel") if units[target].side==1 else 1.0
		gear.deal(target,amount*factor,event,false,"持续伤害")
		resolve_event(event,dot_sources.get(target,-1),kind);return
	if kind == "skill_splash":
		bridge();var event = {"hits":[],"heals":[]}
		gear.strike(gear.b.units[source],target,amount,event)
		resolve_event(event,source,kind);return
	super.damage(source,target,amount,kind)
	if direct and source == 4 and kind == "fire":
		burn_power[target] = units[source].power*(.20*strength() if branch==0 else cfg.combat.burn_attack_ratio)
		burn_sources[target] = source
	if direct and source == 1 and branch == 0 and units[target].hp > 0:
		var initial = base_armor.get(target,stats_live[target].armor)
		stats_live[target].armor = maxf(initial*.60,stats_live[target].armor-initial*.08*strength())
	if first_hit and units[source].hp > 0:
		var splash_count = 2 if source == 0 and branch == 1 else 1 if source == 2 and branch == 1 else 0
		var coefficient = .35 if source == 0 else .50
		for enemy in units.slice(5):
			if splash_count <= 0:break
			if enemy.hp > 0 and enemy.uid != target:
				var value = roundi(units[source].power*coefficient*strength()*(1.0+.04*gear.card_rank("hyakki")))
				damage(source,enemy.uid,value,"skill_splash");extra_hits += 1;splash_count -= 1

func resolve_event(event:Dictionary,source:int,kind:String) -> void:
	if source >= 0 and kind not in ["burn","dot","test","hazard"]:
		for u in gear.b.units:
			if u.dot > 0 and (u.dot > dots[u.id] or u.dot_turns > dot_turns[u.id]):dot_sources[u.id] = source
	super.resolve_event(event,source,kind)

func tick(dt:float) -> void:
	super.tick(dt)
	if phase != "fight" or hazard_power <= 0:return
	hazard_elapsed += dt
	if hazard_elapsed >= 5.0:
		hazard_elapsed -= 5.0
		for hero in units.slice(0,5):
			if hero.hp > 0:damage(-1,hero.uid,roundi(hazard_power*(1-stats_live[hero.uid].resist/100.0)),"hazard")

func configure_encounter(profile:String,hp_multiplier:float=1.0,attack_multiplier:float=1.0) -> void:
	encounter_profile = profile
	var total_hp = 0.0;var raw_dps = 0.0
	for enemy in units.slice(5):
		total_hp += enemy.max_hp
		raw_dps += enemy.power/(100.0/enemy.agility+1.3)
	if profile == "boss":
		for enemy in units.slice(5):
			if enemy.uid != 7:enemy.hp = 0
		var boss = units[7]
		boss.max_hp = roundi(total_hp*hp_multiplier);boss.hp = boss.max_hp
		boss.power = roundi(raw_dps*(100.0/boss.agility+1.3)*attack_multiplier)
		stats_live[7].atk = boss.power
	elif profile in ["wave","pressure"]:
		for enemy in units.slice(5):
			enemy.max_hp = roundi(enemy.max_hp*hp_multiplier);enemy.hp = enemy.max_hp
			enemy.power = roundi(enemy.power*attack_multiplier*(.65 if profile=="pressure" else 1.0))
			stats_live[enemy.uid].atk = enemy.power
		if profile == "pressure":hazard_power = raw_dps*attack_multiplier*.35
