extends "res://scripts/pixel_hyakki/equipment.gd"

var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/pixel_campaign/progression.json"))
var rating = 1
var misses = 0

func xp_required() -> int:
	return ceili(cfg.experience.base * pow(s.level,cfg.experience.level_exponent))

func train_cost(hero:int) -> int:
	var rank = s.training[hero]
	return roundi(cfg.gold.training_base + cfg.gold.training_linear*rank + cfg.gold.training_quadratic*rank*rank)

func train(hero:int) -> bool:
	if hero < 0 or hero >= 5:return false
	var price = train_cost(hero)
	if s.gold < price:return false
	s.gold -= price;s.training[hero] += 1
	return true

func reward(enemy:Dictionary) -> void:
	var key = "%d:%d" % [b.theme,enemy.kind]
	s.kills[key] = s.kills.get(key,0)+1;b.kills += 1
	var money = roundi((cfg.gold.kill_base + cfg.gold.rating_scale*pow(rating,cfg.gold.rating_exponent))*(1+party_bonus("gold")/100.0))
	s.gold += money;b.gold += money
	s.xp += roundi((cfg.experience.kill_base + cfg.experience.rating_scale*pow(rating,cfg.experience.rating_exponent))*(1+party_bonus("xp")/100.0))
	while s.xp >= xp_required():
		s.xp -= xp_required();s.level += 1
	var drop = enemy.boss or misses >= cfg.loot.miss_pity-1 or rng.randf() < minf(cfg.loot.max_probability,cfg.loot.normal_probability+party_bonus("luck")/100.0)
	if not drop:misses += 1;return
	misses = 0
	var item_level = maxi(1,rating + int(cfg.loot.boss_level_bonus if enemy.boss else 0) + rng.randi_range(int(cfg.loot.level_jitter_min),int(cfg.loot.level_jitter_max)))
	var item = award(item_level,b.theme)
	item["origin"] = {"type":"monster","enemy":enemy.name,"theme":b.theme,"scene":b.get("scene_number",b.scene),"scene_id":b.get("scene_id",""),"world":b.get("world",""),"rating":rating}
	s.loot_log.append({"id":item.id,"name":G.name_of(item),"quality":int(item.quality),"enemy":enemy.name})
	if s.loot_log.size()>40:s.loot_log.pop_front()
	b.loot.append(item.id)
	if not b.has("drop_events"):b["drop_events"] = []
	b.drop_events.append({"id":item.id,"enemy":enemy.id})

func strike(actor:Dictionary,target:int,amount:float,event:Dictionary) -> void:
	# Change only the physical mitigation factor in the inherited strike.
	# This converts bounded mitigation into the equivalent old-formula armor;
	# restoration preserves the real armor stat and existing powers/procs.
	var victim = b.units[target]
	var actual_armor = victim.stats.armor
	var scaled = maxf(0,actual_armor)*cfg.combat.armor_scale
	var factor = 1.0-cfg.combat.armor_asymptote*scaled/(cfg.combat.armor_constant+scaled)
	victim.stats.armor = (1.0/factor-1.0)*100.0/3.0
	super.strike(actor,target,amount,event)
	victim.stats.armor = actual_armor
