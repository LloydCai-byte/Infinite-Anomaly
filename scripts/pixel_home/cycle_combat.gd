extends RefCounted
static func on_action(battle,index:int) -> void:
	if index<0 or index>=5 or battle.units[index].hp<=0 or battle.action.is_empty() or battle.gear.campaign.cycle<3:return
	battle.cycle_actions[index]+=1;battle.cycle_total_actions+=1
	var choice=battle.gear.cycles.resonance
	if choice==1:return
	if choice==0 and battle.cycle_actions[index]%5!=0:return
	if choice==2 and battle.cycle_total_actions%5!=0:return
	battle.bridge();var gear=battle.gear;var event={"hits":[],"heals":[]}
	if choice==0:
		var target=battle.choose_target(battle.units[index])
		if target>=0:gear.strike(gear.b.units[index],target,gear.b.units[index].stats.atk*.75,event)
	else:
		var allies=gear.alive(0);allies.sort_custom(func(a,b):return gear.b.units[a].hp/gear.b.units[a].maxhp<gear.b.units[b].hp/gear.b.units[b].maxhp)
		if not allies.is_empty():gear.heal(allies[0],gear.b.units[allies[0]].maxhp*.12,event)
	battle.resolve_event(event,index,"cycle_resonance");battle.cycle_triggers+=1
	var title=gear.Cycles.catalog().resonances[choice].name;battle.note(title)
	battle.effects.append({"kind":"number","value":title,"pos":battle.units[index].pos+Vector2(-55,-160),"age":0.0,"life":1.3,"color":Color("adcbdc")})
