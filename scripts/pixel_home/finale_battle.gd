extends "res://scripts/pixel_home/battle.gd"
const Finale=preload("res://scripts/pixel_home/finale.gd")
var pending_outcome:Dictionary={}
var boss_actions=0
var boss_triggers=0
var enrage_stacks=0

func is_finale() -> bool:return true

func reset(_start_level:int=0) -> void:
	super.reset(0)
	if gear==null or level_defs.is_empty():return
	stage=clampi(gear.finale.next,0,3);spawn_stage();phase="ready"
	pending_outcome={};apply_checkpoint()

func start() -> void:
	if gear!=null and gear.finale.status=="active" and gear.finale.next==scene_index() and gear.finale_eligible():phase="fight"

func spawn_stage() -> void:
	super.spawn_stage();boss_actions=0;boss_triggers=0;enrage_stacks=0
	if gear!=null:apply_checkpoint()

func apply_checkpoint() -> void:
	if gear.finale.checkpoint.is_empty():return
	for i in range(5):
		var saved=gear.finale.checkpoint[i];var u=units[i]
		u.hp=0 if saved.hp<=0 else maxi(1,roundi(u.max_hp*saved.hp))
		shields[i]=u.max_hp*saved.shield if u.hp>0 else 0.0
		if u.hp<=0:u.anim="die";u.dead_time=3.0;u.charge=0

func party_checkpoint() -> Array:
	var party=[]
	for i in range(5):party.append({"hp":float(units[i].hp)/maxi(1,units[i].max_hp),"shield":clampf(shields[i]/maxi(1,units[i].max_hp),0,.35)})
	return party

func finish(result:String) -> void:
	if phase!="fight" or not pending_outcome.is_empty():return
	# Keep normal loot and combat, but do not create an extra numbered campaign clear.
	scene_awarded=true
	pending_outcome={"index":scene_index(),"won":result!="defeat","party":party_checkpoint(),"seconds":stage_time,"phase":result}
	super.finish(result)
	save_outcome()

func save_outcome() -> bool:
	if pending_outcome.is_empty():return true
	var result=pending_outcome
	if not gear.save_finale_result(result.index,result.won,result.party,result.seconds):
		phase="checkpoint";note("决战记录未保存，请重试保存。");return false
	phase=result.phase;pending_outcome={};return true

func advance_stage() -> bool:
	if phase!="clear" or not pending_outcome.is_empty() or gear.finale.status!="active" or gear.finale.next!=stage+1:return false
	stage+=1;spawn_stage();return true

func begin_action(index:int) -> void:
	super.begin_action(index)
	if index<5 or units[index].hp<=0 or not units[index].get("boss",false) or action.is_empty():return
	boss_actions+=1
	var cfg=Finale.catalog().battles[stage]
	if boss_actions%int(cfg.period)!=0:return
	boss_triggers+=1;bridge();var event={"hits":[],"heals":[]};var boss=gear.b.units[index]
	match cfg.effect:
		"shield":
			for target in gear.b.units.slice(5):
				if target.hp>0:target.shield=minf(target.maxhp*.35,target.shield+target.maxhp*.05)
		"volley":
			for target in gear.alive(0):gear.strike(boss,target,boss.stats.atk*.30,event)
		"heal":
			var escorts=gear.alive(1).size()-1
			if escorts>0:gear.heal(index,boss.maxhp*.025*escorts,event)
		"enrage":
			enrage_stacks=mini(6,enrage_stacks+1)
			var base=stats_live[index].atk;units[index].power=roundi(base*(1+.06*enrage_stacks))
	resolve_event(event,index,"finale_skill")
	last_skill=units[index].name+" · "+cfg.skill;note(last_skill)
	effects.append({"kind":"number","value":cfg.skill,"pos":units[index].pos+Vector2(-60,-155),"age":0.0,"life":1.4,"color":Color("d4a7d9")})

func campaign_result_text() -> String:
	if phase=="checkpoint":return "保存失败：请重试保存后继续。"
	return "中枢决战完成" if gear.finale.status in ["won","complete"] else "生命与护盾延续；倒下的队员不会自动复活。"
