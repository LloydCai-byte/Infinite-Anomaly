extends RefCounted
## Additional skills run on the existing ATB action; there is no second combat loop.
static func on_action(battle,hero:int) -> void:
	if hero<0 or hero>=5 or battle.units[hero].hp<=0 or battle.action.is_empty():return
	var skill=battle.gear.cosmic_skill(hero)
	if skill.is_empty():return
	battle.cosmic_actions[hero]+=1
	if battle.cosmic_actions[hero]%int(battle.gear.Cosmos.catalog().skill_cadence)!=0:return
	var enemies=battle.alive(1)
	if enemies.is_empty():return
	var target=int(battle.action.target)
	if battle.units[target].hp<=0:target=enemies[0].uid
	var power=battle.units[hero].power*skill.power
	battle.cosmic_triggers[hero]+=1
	match skill.effect:
		"single":hit(battle,hero,target,power)
		"plasma":hit(battle,hero,target,power,"fire")
		"all","fire_all","freeze":
			for enemy in enemies:
				if battle.units[hero].hp<=0:break
				hit(battle,hero,enemy.uid,power,"fire" if skill.effect=="fire_all" else "cold" if skill.effect=="freeze" else "physical")
				if skill.effect=="freeze" and enemy.hp>0:
					battle.cosmic_chill[enemy.uid]=4.0
					enemy.agility=maxf(1,battle.stats_live[enemy.uid].speed-4.0)
		"two":
			enemies.sort_custom(func(a,b):return a.uid==target if a.uid==target or b.uid==target else a.uid<b.uid)
			for enemy in enemies.slice(0,2):hit(battle,hero,enemy.uid,power)
		"largest":
			enemies.sort_custom(func(a,b):return a.max_hp>b.max_hp)
			hit(battle,hero,enemies[0].uid,power)
		"execute":
			enemies.sort_custom(func(a,b):return float(a.hp)/a.max_hp<float(b.hp)/b.max_hp)
			var enemy=enemies[0];hit(battle,hero,enemy.uid,power*(2 if enemy.hp<=enemy.max_hp*.5 else 1))
		"break":
			hit(battle,hero,target,power)
			var original=battle.base_armor.get(target,battle.stats_live[target].armor)
			battle.stats_live[target].armor=maxf(original*.30,battle.stats_live[target].armor-original*skill.shred)
		"shield_strike":
			var spent=battle.shields[hero]*.5;battle.shields[hero]-=spent
			hit(battle,hero,target,power+spent*.6)
		"shield_all":
			for ally in battle.alive(0):shield(battle,ally.uid,ally.max_hp*skill.power)
		"heal_all":
			for ally in battle.alive(0):heal(battle,hero,ally.uid,ally.max_hp*.04+power)
		"rescue":
			var allies=battle.alive(0);allies.sort_custom(func(a,b):return float(a.hp)/a.max_hp<float(b.hp)/b.max_hp)
			if not allies.is_empty():
				heal(battle,hero,allies[0].uid,allies[0].max_hp*.2);shield(battle,allies[0].uid,allies[0].max_hp*.04)
		"charge":
			var allies=battle.alive(0).filter(func(u):return u.uid!=hero and not u.uid in battle.ready_queue)
			allies.sort_custom(func(a,b):return a.charge<b.charge)
			for ally in allies.slice(0,2):ally.charge=maxf(ally.charge,minf(.99,ally.charge+skill.power))
	battle.last_skill=battle.units[hero].name+" · "+skill.name
	battle.note(battle.last_skill)
	battle.effects.append({"kind":"number","value":skill.name,"pos":battle.units[hero].pos+Vector2(0,-165),"age":0.0,"life":1.0,"color":Color("a2dce8")})

static func hit(battle,hero:int,target:int,amount:float,element:String="physical") -> void:
	if battle.units[hero].hp<=0 or battle.units[target].hp<=0:return
	battle.bridge();var event={"hits":[],"heals":[]};battle.gear.b.units[hero].stats.attack_element=element
	battle.gear.strike(battle.gear.b.units[hero],target,amount,event)
	battle.resolve_event(event,hero,"cosmic")
	battle.effects.append({"kind":"spark","pos":battle.units[target].pos+Vector2(0,-70),"age":0.0,"life":.45,"color":Color("8fdbe7")})

static func heal(battle,hero:int,target:int,amount:float) -> void:
	if battle.units[target].hp<=0 or battle.units[hero].hp<=0:return
	battle.bridge();var event={"hits":[],"heals":[]}
	battle.gear.heal(target,amount*(1+battle.stats_live[hero].heal/100.0),event)
	battle.resolve_event(event,hero,"cosmic_support")

static func shield(battle,target:int,amount:float) -> void:
	battle.shields[target]=minf(battle.units[target].max_hp*.35,battle.shields[target]+amount)
