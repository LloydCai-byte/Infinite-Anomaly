extends RefCounted
## Original loot rules inspired by base items / random affixes / legendary powers.
const SLOTS=["weapon","head","armor","gloves","boots","belt","necklace","ring_a","ring_b"]
const SLOT_NAMES=["职业武器","头盔","护甲","手套","靴子","腰带","项链","戒指Ⅰ","戒指Ⅱ"]
const TYPES=["weapon","head","armor","gloves","boots","belt","necklace","ring"]
const QUALITY=["普通","魔法","稀有","传奇","套装","独特"]
const COLORS=["c8c8c5","7eafff","f2d474","f4a250","7be6a2","e9baff"]
const AFFIX={
	"hp":["生命",12,28,false],"atk":["攻击",2,5,false],"armor":["护甲",2,5,false],
	"speed":["行动速度",1,3,false],"crit":["暴击率",2,5,true],"crit_damage":["暴击伤害",8,16,true],
	"fire":["火焰伤害",2,5,false],"cold":["冰霜伤害",2,5,false],"lightning":["闪电伤害",2,5,false],
	"poison":["毒素伤害",2,5,false],"vamp":["伤害吸血",2,5,true],"thorns":["荆棘反伤",2,5,false],
	"heal":["支援治疗",5,12,true],"block":["格挡率",2,5,true],"dodge":["闪避率",2,4,true],
	"elite":["对首领伤害",5,12,true],"shield":["开场护盾",8,20,false],"xp":["经验获取",3,8,true],
	"gold":["金币获取",4,10,true],"luck":["装备掉率",2,5,true],"resist":["元素抗性",2,5,true]
}
const POWERS={"cleave":["裂空","攻击额外波及一名敌人，造成35%伤害"],"chain":["连锁","攻击额外弹射两名敌人，各造成20%伤害"],"bleed":["蚀刻","命中附加持续两次行动的流血"],"barrier":["守望","每次行动获得10点护盾"],"mercy":["怜悯","每次行动治疗生命最低的队友"],"echo":["回响","攻击追加一次25%伤害"],"execute":["处决","对半血以下目标伤害提高35%"],"guardian":["庇护","入战时全队护甲提高5点（最多15点）"]}
const SETS=["夜巡","沉潮","王陵"]
const SET_IDS=["hyakki","abyss","tomb"]
const SET_TYPES=["head","armor","gloves","boots"]
const BASE_NAMES={
	"head":["守夜面甲","折光头盔","盐雾风帽","猎潮兜帽","赤金冠冕","陨铁头环"],
	"armor":["异常防护衣","影纹胸甲","深潜战袍","裂帆长衣","王陵鳞甲","星砂护衣"],
	"gloves":["疾风护手","裂隙手套","珊瑚腕甲","锈铜手套","封印护腕","金纹指套"],
	"boots":["追影战靴","夜行短靴","潮汐长靴","礁石护靴","踏砂战靴","遗迹足铠"],
	"belt":["守门腰带","星图束带","船长腰封","深海缆带","赤金腰带","王朝束带"],
	"necklace":["余烬吊坠","镜月项链","海眼项坠","沉船罗盘","圣甲护符","星砂项链"],
	"ring":["赤瞳指环","虚空戒指","珍珠戒指","潮声指环","王印之戒","黄昏指环"]}
const WEAPONS=[["练习太刀","夜雨太刀","断潮长刀","烬日之刃"],["训练拳套","碎岩拳套","海兽臂铠","王卫拳甲"],["制式机枪","猎影机枪","海雾重机枪","日轮机炮"],["战术终端","夜巡控制器","深潜终端","星图终端"],["符文法器","焰环法器","潮汐法器","日冕法器"]]
static var bases:Array=[]

static func init()->void:
	if not bases.is_empty():return
	for hero in range(5):
		for n in range(4):bases.append({"name":WEAPONS[hero][n],"type":"weapon","hero":hero,"icon":8+hero,"theme":maxi(0,n-1)})
	for type in BASE_NAMES:
		for n in range(6):bases.append({"name":BASE_NAMES[type][n],"type":type,"hero":-1,"icon":TYPES.find(type)-1,"theme":n/2})
	for theme in range(3):
		for type in SET_TYPES:bases.append({"name":SETS[theme]+["面甲","战衣","护手","战靴"][SET_TYPES.find(type)],"type":type,"hero":-1,"icon":TYPES.find(type)-1,"theme":theme,"set":theme})

static func make(rng:RandomNumberGenerator,serial:int,level:int,theme:int,forced_quality:int=-1,forced_base:int=-1)->Dictionary:
	init()
	var roll=rng.randf()
	var quality=0 if roll<.10 else (1 if roll<.38 else (2 if roll<.78 else (3 if roll<.89 else (4 if roll<.97 else 5))))
	if forced_quality>=0:quality=forced_quality
	var pool:Array=[]
	for i in range(bases.size()):
		if quality==4 and bases[i].get("set",-1)==theme:pool.append(i)
		elif quality!=4 and not bases[i].has("set") and (int(bases[i].theme)==theme or rng.randf()<.25):pool.append(i)
	var base=pool[rng.randi_range(0,pool.size()-1)] if forced_base<0 else forced_base
	var data=bases[base]
	var item={"id":serial,"base":base,"quality":quality,"level":maxi(1,level),"affixes":{},"power":"","locked":false}
	var keys=AFFIX.keys()
	var count=[0,2,3,4,3,4][quality]
	for n in range(count):
		var key=keys.pop_at(rng.randi_range(0,keys.size()-1))
		var a=AFFIX[key]
		var growth=1.0+minf(level,200)*(.008 if a[3] else .055)
		item.affixes[key]=snappedf(rng.randf_range(a[1],a[2])*growth,.1)
	if quality in [3,5]:item.power=POWERS.keys()[rng.randi_range(0,POWERS.size()-1)]
	if quality==5:
		# Unique focus: one fixed high roll and a consistent power per base.
		item.power=POWERS.keys()[base%POWERS.size()]
		item.affixes["atk"]=snappedf(6+level*.6,.1)
	return item

static func type_of(item:Dictionary)->String:
	init();return bases[int(item.base)].type
static func name_of(item:Dictionary)->String:
	init()
	var prefix=""
	if not item.power.is_empty():prefix=POWERS[item.power][0]+" · "
	return prefix+bases[int(item.base)].name
static func inherent(item:Dictionary)->Dictionary:
	var t=type_of(item);var lv=float(item.level)
	if t=="weapon":return {"atk":8+lv*1.5}
	if t in ["head","armor","gloves","boots","belt"]:return {"armor":(4 if t=="armor" else 2)+lv*.3,"hp":(12 if t=="armor" else 5)+lv*1.5}
	return {"crit":1.0+minf(lv,100)*.06}
static func details(item:Dictionary)->String:
	var lines=PackedStringArray([QUALITY[int(item.quality)]+"  ·  物品等级 %d"%item.level])
	for key in inherent(item):lines.append("固有  "+line(key,inherent(item)[key]))
	for key in item.affixes:lines.append(line(key,item.affixes[key]))
	if not item.power.is_empty():lines.append("◆ "+POWERS[item.power][1])
	var set_id=int(bases[int(item.base)].get("set",-1))
	if set_id>=0:lines.append("套装："+SETS[set_id]+"\n2件：攻击+10%\n4件："+["攻击波及一名敌人，造成35%伤害","每次行动治疗生命最低的队友","每次行动获得10点护盾"][set_id])
	var hero=int(bases[int(item.base)].hero)
	if hero>=0:lines.append("专属："+["粉粉","高哥","七七","大东老师","老王"][hero])
	return "\n".join(lines)
static func line(key:String,value:float)->String:
	return "%s +%s%s"%[AFFIX[key][0],str(snappedf(value,.1)),"%" if AFFIX[key][3] else ""]
static func slot_type(slot:String)->String:return "ring" if slot.begins_with("ring_") else slot
static func can_equip(item:Dictionary,hero:int,slot:String)->bool:
	if slot not in SLOTS or type_of(item)!=slot_type(slot):return false
	return int(bases[int(item.base)].hero) in [-1,hero]
static func score(item:Dictionary)->float:
	var result=float(item.level)*2+int(item.quality)*8
	for key in item.affixes:result+=float(item.affixes[key])*(.2 if key=="hp" else 1.0)
	return result
static func valid(item:Variant)->bool:
	init()
	if not item is Dictionary:return false
	for key in ["id","base","quality","level"]:
		if not item.get(key) is int:return false
	if item.id<=0 or item.base<0 or item.base>=bases.size() or item.quality<0 or item.quality>=QUALITY.size() or item.level<1:return false
	if not item.get("affixes") is Dictionary or not item.get("power") is String:return false
	if item.power!="" and not POWERS.has(item.power):return false
	for key in item.affixes:
		if not AFFIX.has(key) or not (item.affixes[key] is int or item.affixes[key] is float):return false
		if not is_finite(float(item.affixes[key])) or item.affixes[key]<0:return false
	return true
