extends RefCounted
## Explicitly isolated examples. This script is never loaded by the normal home.
const Gear=preload("res://scripts/pixel_home/gear.gd")
const Content=preload("res://scripts/pixel_home/content.gd")
const ART="res://art/pixel-hyakki-level-20261024/"
const ENTRIES=[
	["opening","开场与主神空间","从轩轩醒来开始，体验移动、互动和小队出战。"],
	["graduation","地球毕业","直接查看地球1000房间全部闪光后的关键演出。"],
	["cosmos","宇宙整备与归来","领取返家物资，查看星核、技能和支援。"],
	["planet","星球战斗 · 测试素材","体验同图十波与宇宙掉落，沿用已有图像测试。"],
	["finale","连续Boss · 测试素材","体验四战连续、返家续战与一周目结局。"],
	["second","二周目继承","在轮回档案确认新周目，检查装备与双支援。"],
	["third","三周目共鸣","查看最后一次开场，选择三种记忆共鸣。"],
	["ending","最终结局","观看第三周目的完整结局及永久完结状态。"]
]
static func drain_story(g) -> void:
	while g.story_waiting():
		g.prepare_story()
		if not g.complete_story(g.narrative.pending.id):break
static func earth_fixture(g) -> void:
	# Demo-only fixture, never a gameplay reward path or a generated-art claim.
	var sample=Gear.Campaign.initial()
	for difficulty in range(1,11):Gear.Campaign.apply_result(sample,1,difficulty,10,0,90,true)
	for id in range(1,1001):g.campaign.levels[Gear.Campaign.key(id)]=sample.levels.R0001.duplicate(true)
	g.campaign.pending_story="graduation"
static func graduate(g) -> void:
	earth_fixture(g)
	g.finish_graduation();drain_story(g)
static func reach_finale(g) -> void:
	if g.campaign.phase=="earth":graduate(g)
	for id in range(1001,2001):g.record_level_result(id,1,10,0,90,true)
	drain_story(g);g.events.ticket={};g.events.pending={}
static func complete_cycle(g,finish:bool=true) -> void:
	if g.cycles.pending_intro!=0:g.finish_cycle_intro()
	reach_finale(g);g.begin_finale();var party=[]
	for i in range(5):party.append({"hp":1.0,"shield":0.0})
	for i in range(4):g.save_finale_result(i,true,party,30.0)
	g.complete_trip();g.events.pending={}
	if finish:g.finish_ending()
static func profile(kind:String) -> Dictionary:
	if not ENTRIES.any(func(entry):return entry[0]==kind):return {}
	var g=Gear.new(2847)
	if kind=="opening":return g.snapshot()
	g.home.intro_done=true;g.home.intro_version=2;g.s.level=45;g.s.gold=6000
	for i in range(5):
		var item=g.award(45,0,3,i*4);g.equip(item.id,i,"weapon")
	g.s.inventory[0].locked=true;g.s.training=[3,3,3,3,3]
	g.events.supports={"pulse":3,"anchor":2,"sight":2};g.events.equipped="pulse";g.events.materials=30
	if kind=="graduation":
		earth_fixture(g)
		return g.snapshot()
	graduate(g);g.cosmos.stardust=150
	for id in range(1001,1031):g.record_level_result(id,1,10,0,90,true)
	drain_story(g)
	if kind=="cosmos":g.events.serial+=1;g.events.pending={"id":"orbital_dust","ticket":g.events.serial}
	if kind=="finale":reach_finale(g)
	if kind in ["second","third","ending"]:complete_cycle(g)
	if kind in ["third","ending"]:
		g.start_next_cycle();g.finish_cycle_intro();g.equip_support("anchor",1);complete_cycle(g);g.start_next_cycle()
	if kind=="ending":g.finish_cycle_intro();complete_cycle(g,false)
	return g.snapshot()
static func pack(finale:bool=false) -> Dictionary:
	var base=JSON.parse_string(FileAccess.get_file_as_string(Content.BASE));var roster=JSON.parse_string(FileAccess.get_file_as_string(ART+"sprites/roster.json"))
	var result={"schema":1,"test_only":true,"level":{"id":601 if finale else 301,"title":"演示中枢 · 测试素材" if finale else "演示星球 · 测试素材","phase":"finale" if finale else "cosmos","world_key":"demo_finale" if finale else "demo_planet","rating_base":1,"scenes":[]},"enemies":{},"visuals":{}}
	for i in range(5):
		var source=["tengu","umbrella","oni","kappa","wheel"][i];var id="alien_demo_%d"%i;var visual=roster[source].duplicate(true)
		visual.giant=visual.height>84;visual.portrait=ART+"sprites/"+source+"/portrait.png"
		for clip in Content.CLIPS:visual.clips[clip].path=ART+"sprites/"+source+"/"+clip+".png"
		result.visuals[id]=visual
		result.enemies["demo_%d"%i]={"name":"演示敌人%d"%(i+1),"skill":"测试攻击","role":["ranged","melee","heavy","melee","flame"][i],"visual":id,"hp_base":220,"attack_base":18,"speed":22,"armor":12,"resist":10}
	if finale:
		for i in range(4):
			var boss=result.enemies.demo_2.duplicate(true);boss.name=Gear.Finale.catalog().battles[i].title+" · 测试替身";boss.skill=Gear.Finale.catalog().battles[i].skill;boss.hp_base=3000;boss.attack_base=70;boss.speed=32
			result.enemies["demo_boss_%d"%i]=boss
	for i in range(4 if finale else 10):
		var scene=base.levels[0].scenes[i].duplicate(true);scene.id="DEMO-%02d"%i;scene.title=Gear.Finale.catalog().battles[i].title if finale else "测试场景 %02d"%(i+1)
		scene.enemies=["demo_0","demo_1","demo_boss_%d"%i if finale else "demo_2","demo_3","demo_4"]
		scene.boss_slots=[2] if finale or i==9 else [];result.level.scenes.append(scene)
	return result
