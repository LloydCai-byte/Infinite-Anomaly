extends RefCounted
const ROOMS=1000000
const TRAIN_TIME=30.0
const TRAVEL_TIME=10.0
const UNLOAD_TIME=2.0
const ROLES=[
	{"name":"盾卫","icon":"shield","hp":180.0,"atk":12.0,"armor":20.0,"interval":1.2,"asset":"troop_shield"},
	{"name":"射手","icon":"rifle","hp":90.0,"atk":20.0,"armor":5.0,"interval":1.0,"asset":"troop_rifle"},
	{"name":"炮兵","icon":"cannon","hp":100.0,"atk":35.0,"armor":5.0,"interval":2.0,"asset":"troop_cannon"},
	{"name":"医疗","icon":"medical","hp":85.0,"atk":8.0,"armor":5.0,"interval":1.5,"asset":"troop_medic"}
]
const TECH=[
	{"id":"weapons","name":"武器工程","icon":"rifle","desc":"新培养的士兵：基础攻击每级 +8%。"},
	{"id":"armor","name":"防护工程","icon":"shield","desc":"新培养的士兵：基础生命与护甲每级 +8%。"},
	{"id":"medicine","name":"战地医学","icon":"medical","desc":"新培养的医疗兵：每次治疗量每级 +8%。"},
	{"id":"logistics","name":"航行网络","icon":"door","desc":"下一趟去程与返程各缩短 3%，最低 4 秒。"}
]
const PLANETS=[
	{"id":"P01","name":"潮汐矿卫星","civ":"潮汐掘进体","bg":"p01","enemy":"crawler","factor":1.0,"supplies":300,"science":20,"stages":4,"behavior":"burrow","tip":"大量掘进体不断越过矿坑。准备盾卫承受第一轮接触。"},
	{"id":"P02","name":"玻璃苔原","civ":"晶原议会","bg":"p02","enemy":"mirror","factor":1.22,"supplies":420,"science":30,"stages":5,"behavior":"glass","tip":"晶体远程部队伤害高、生命低。射手和炮兵能尽快压制。"},
	{"id":"P03","name":"沉降环带","civ":"磁环共同体","bg":"p03","enemy":"sentinel","factor":1.48,"supplies":600,"science":50,"stages":4,"behavior":"shield","tip":"环带驻军携带护盾和重甲。炮兵的穿透火力更有效。"},
	{"id":"P04","name":"双日沙海","civ":"沙脊王庭","bg":"p04","enemy":"hound","factor":1.8,"supplies":800,"science":70,"stages":6,"behavior":"rush","tip":"侧翼冲锋压缩战线。提高前排比例，别让登陆锚点失守。"},
	{"id":"P05","name":"菌海大陆","civ":"共生群落","bg":"p05","enemy":"parasite","factor":2.2,"supplies":1050,"science":90,"stages":5,"behavior":"regen","tip":"敌人持续再生。输出不足时，应该暂停进攻并积累兵力。"},
	{"id":"P06","name":"潮锁都市","civ":"深层市民","bg":"p06","enemy":"beacon","factor":2.68,"supplies":1350,"science":120,"stages":7,"behavior":"ranged","tip":"都市炮台齐射后排。医疗与防護工程可以减少伤亡。"},
	{"id":"P07","name":"碎月铸场","civ":"铸月联盟","bg":"p07","enemy":"frost","factor":3.27,"supplies":1700,"science":150,"stages":5,"behavior":"armor","tip":"铸场重装军团护甲极高。炮兵比例和武器工程决定推进速度。"},
	{"id":"P08","name":"黑曜雨林","civ":"影梭文明","bg":"p08","enemy":"eye","factor":3.99,"supplies":2100,"science":190,"stages":6,"behavior":"ranged","tip":"散开的影梭持续攻击后排。用医疗和集结后的兵力稳步推进。"},
	{"id":"P09","name":"恒风海盆","civ":"风帆联邦","bg":"p09","enemy":"sentinel","factor":4.87,"supplies":2600,"science":230,"stages":7,"behavior":"shield","tip":"风帆护盾反复充能。炮兵穿透可减轻持久作战的压力。"},
	{"id":"P10","name":"空壳环城","civ":"环城继承者","bg":"p10","enemy":"hollow","factor":5.94,"supplies":3200,"science":280,"stages":6,"behavior":"regen","tip":"远程军团受到修复中枢支援。先建立足够的火力再进攻。"},
	{"id":"P11","name":"红移圣所","civ":"红移守望者","bg":"p11","enemy":"frost","factor":7.25,"supplies":3900,"science":340,"stages":7,"behavior":"elite","tip":"圣所精锐生命极高。保存活下来的老兵，等待新一轮投送。"},
	{"id":"P12","name":"中枢星域","civ":"终端协定","bg":"p12","enemy":"terminal","factor":8.85,"supplies":5000,"science":420,"stages":8,"behavior":"final","tip":"终端守卫会轮换护盾、修复与冲锋。全部战略枢纽就在这里连成一体。"}
]
static func planet(index: int) -> Dictionary: return PLANETS[clampi(index,0,11)]
static func recommended(index: int) -> int: return int(3000000*pow(planet(index).factor,1.15))
static func number(n: float) -> String:
	if n>=100000000: return "%.2f亿"%(n/100000000.0)
	if n>=10000: return "%.1f万"%(n/10000.0)
	return str(int(n))
static func phase_name(id: String) -> String:
	return {"training":"培养新人","ready":"整备待命","outbound":"满员去程","unloading":"正在卸载","returning":"空房返航"}.get(id,id)
