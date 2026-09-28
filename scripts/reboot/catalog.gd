extends RefCounted
## Ten training operations. Each operation owns its wave schedule and enemy behavior.
const VERSION = "0.5.2"
const PEOPLE = [
	{"id":"qiaoyue","name":"乔越","age":24,"job":"快递员","role":"盾卫","icon":"shield","hp":240.0,"atk":22.0,"armor":12.0,"interval":1.2,"range":76.0,"skill":"护盾冲击","cd":12.0,"note":"先质疑规则，危险时却总是先挡在前面。","line":"先别问出口，我看见它过来了。"},
	{"id":"zhouji","name":"周霁","age":30,"job":"电工","role":"射手","icon":"rifle","hp":160.0,"atk":28.0,"armor":5.0,"interval":1.0,"range":350.0,"skill":"连锁电击","cd":10.0,"note":"他比其他人更早注意到，房间里的设备一直在回应。","line":"电没断，断的是外面的声音。"},
	{"id":"linheng","name":"林衡","age":38,"job":"机械工","role":"炮兵","icon":"cannon","hp":200.0,"atk":42.0,"armor":8.0,"interval":1.8,"range":385.0,"skill":"穿透炮击","cd":14.0,"note":"面对陌生武器，他的第一反应是想知道它怎么工作。","line":"能打出来，就能拆明白。"},
	{"id":"hewei","name":"贺维","age":45,"job":"急救员","role":"医疗","icon":"medical","hp":175.0,"atk":14.0,"armor":5.0,"interval":1.5,"range":310.0,"skill":"紧急修复","cd":8.0,"note":"他记得每一次有人倒下时，自己距离那个人还有多远。","line":"先确认每个人都能回来。"}
]
const MISSIONS = [
	{"id":"M01","name":"废弃地铁","bg":"metro","enemy":"crawler","small":"节肢幼体","boss":"蜈节行者","power":440,"credits":100,"alloy":3,"factor":1.0,"reward":"标准武装配方","desc":"最后一班列车已经停运。站台深处仍然传来整齐的敲击声。","tip":"盾卫贴近目标，后排保持火力。倒下的队员不会在本次任务中归队。","waves":[{"count":4,"boss":false,"weight":20},{"count":6,"boss":false,"weight":20},{"count":2,"boss":true,"weight":60}]},
	{"id":"M02","name":"封闭公寓","bg":"apartment","enemy":"hollow","small":"空壳住民","boss":"回声母体","power":560,"credits":130,"alloy":3,"factor":1.43,"reward":"电弧步枪 Mk.02","desc":"楼里没有开灯，每一扇门后却都响起了同一个人的脚步。","tip":"空壳住民会远程攻击。强化火力，尽快清理后排。","waves":[{"count":4,"boss":false,"weight":15},{"count":5,"boss":false,"weight":20},{"count":5,"boss":false,"weight":20},{"count":2,"boss":true,"weight":45}]},
	{"id":"M03","name":"高架桥底","bg":"overpass","enemy":"hound","small":"板甲犬","boss":"磁脊犬王","power":670,"credits":170,"alloy":4,"factor":2.0,"reward":"磁脊盾 Mk.02 / 基地 T2","desc":"钢筋在桥墩里轻轻震动。积水倒映出一个背生刀脊的影子。","tip":"甲壳会削减伤害。林衡的穿透炮击可以击穿一半护甲。","waves":[{"count":4,"boss":false,"weight":12},{"count":5,"boss":false,"weight":16},{"count":6,"boss":false,"weight":16},{"count":4,"boss":false,"weight":16},{"count":2,"boss":true,"weight":40}]},
	{"id":"M04","name":"地下商场","bg":"mall","enemy":"mirror","small":"碎镜偶","boss":"镜壳主机","power":1050,"credits":220,"alloy":5,"factor":2.5,"reward":"碎镜甲 / 反射研究","desc":"卷帘门已经落下，橱窗里的反光却比你慢了一步。","tip":"目标数量多、单体生命低；连锁电击与穿透炮击可以清场。","mechanic":"swarm","waves":[{"count":7,"boss":false,"weight":20},{"count":8,"boss":false,"weight":20},{"count":9,"boss":false,"weight":20},{"count":5,"boss":true,"weight":40}]},
	{"id":"M05","name":"旧城区天台","bg":"rooftop","enemy":"eye","small":"浮游眼","boss":"百眼灯塔","power":1250,"credits":280,"alloy":6,"factor":3.1,"reward":"反射甲片","desc":"天线全部朝着同一个方向。楼顶的灯，没有接电。","tip":"普通浮游眼定点射击，首领激光扫射全队；防具与医疗帮助撑过齐射。","mechanic":"laser","waves":[{"count":4,"boss":false,"weight":15},{"count":5,"boss":false,"weight":15},{"count":5,"boss":false,"weight":15},{"count":6,"boss":false,"weight":15},{"count":3,"boss":true,"weight":40}]},
	{"id":"M06","name":"冷冻仓库","bg":"freezer","enemy":"frost","small":"冻壳体","boss":"霜棘搬运体","power":1500,"credits":350,"alloy":7,"factor":3.8,"reward":"基地 T3 / 第二能力槽","desc":"仓库温度不再下降。被冻结的东西，开始从里面撞门。","tip":"冻壳体有厚重护甲；炮击穿透与持续治疗比单次爆发可靠。","mechanic":"armor","waves":[{"count":4,"boss":false,"weight":12},{"count":5,"boss":false,"weight":12},{"count":6,"boss":false,"weight":12},{"count":5,"boss":false,"weight":12},{"count":6,"boss":false,"weight":12},{"count":3,"boss":true,"weight":40}]},
	{"id":"M07","name":"海边泵站","bg":"pumps","enemy":"parasite","small":"寄生壳","boss":"潮汐簇","power":1900,"credits":430,"alloy":8,"factor":4.5,"reward":"再生膜","desc":"海水从停止的水泵里向上涌。壳下面，有第二个心跳。","tip":"队尾的潮汐器官会治疗同伴。队伍会优先处理治疗目标。","mechanic":"regen","waves":[{"count":5,"boss":false,"weight":15},{"count":6,"boss":false,"weight":15},{"count":6,"boss":false,"weight":15},{"count":7,"boss":false,"weight":15},{"count":4,"boss":true,"weight":40}]},
	{"id":"M08","name":"旧观测台","bg":"observatory","enemy":"sentinel","small":"观测卫士","boss":"环首观察者","power":2050,"credits":520,"alloy":9,"factor":5.2,"reward":"聚束轨炮 / Mk.03 武装","desc":"望远镜不朝着天空。它正在追踪你们。","tip":"每波敌人带着护盾进入；聚束能力与炮兵能集中破盾。","mechanic":"shield","waves":[{"count":5,"boss":false,"weight":12},{"count":6,"boss":false,"weight":12},{"count":5,"boss":false,"weight":12},{"count":7,"boss":false,"weight":12},{"count":6,"boss":false,"weight":12},{"count":4,"boss":true,"weight":40}]},
	{"id":"M09","name":"通信塔群","bg":"towers","enemy":"beacon","small":"信标偶","boss":"信号巨人","power":2200,"credits":620,"alloy":10,"factor":6.0,"reward":"信号屏障","desc":"没有人呼叫，全部信道却同时收到了确认。","tip":"前排与远程交错出现，集体护盾能覆盖敌人齐射的间隔。","mechanic":"mixed","waves":[{"count":5,"boss":false,"weight":10},{"count":6,"boss":false,"weight":10},{"count":7,"boss":false,"weight":10},{"count":5,"boss":false,"weight":10},{"count":7,"boss":false,"weight":10},{"count":6,"boss":false,"weight":10},{"count":4,"boss":true,"weight":40}]},
	{"id":"M10","name":"零号试验场","bg":"zero","enemy":"warden","small":"训练残影","boss":"门卫","power":2250,"credits":740,"alloy":12,"factor":5.0,"reward":"基地 T4 / 毕业档案 / Mk.04","desc":"白色地面下面露出了格线。这里的一切都像是为你们准备的。","tip":"最后试验会轮换此前的作战特征。任务通关后仍可继续收集金卡。","mechanic":"final","waves":[{"count":5,"boss":false,"weight":8},{"count":6,"boss":false,"weight":8},{"count":6,"boss":false,"weight":8},{"count":7,"boss":false,"weight":8},{"count":5,"boss":false,"weight":8},{"count":7,"boss":false,"weight":8},{"count":6,"boss":false,"weight":8},{"count":4,"boss":true,"weight":44}]}
]
const INTRO = [
	["广播","连接已建立。请确认能够听见我的声音。"],
	["乔越","这是哪儿？我刚才还在路上。"],
	["贺维","先别动。每个人都看看自己有没有受伤。"],
	["广播","欢迎来到这里。你们原来的生活，已经结束了。"],
	["周霁","门锁着，窗外也没有声音。说话的人在哪？"],
	["广播","我负责分配任务。完成任务，你们会得到积分、装备，以及离开这里的机会。"],
	["林衡","这台机器……它刚刚把一把枪做出来了。"],
	["广播","任务门后有需要清除的目标。你们的装备已就绪。"],
	["乔越","我们要是死在那边呢？"],
	["广播","房间会保留你们的记录，并进行重建。但请认真对待每一次出发。"],
	["贺维","那就先保证，四个人一起回来。"],
	["广播","任务已开放。检查队员与装备，然后从任务门出发。"]
]
const CONVERSATIONS = [
	[["乔越","我以前每天跑几十公里，路都记在脑子里。可这扇门后面的路，怎么记都没用。"],["乔越","你要我们往哪儿走，总得先告诉我们会遇到什么。"],["乔越","行。我走前面，你记得看着后面的人。"]],
	[["周霁","打印机、监控、门锁，所有线路都通向墙里面。我找不到控制室。"],["周霁","你每次回应之前，灯都会先亮一下。真的是巧合吗？"],["周霁","算了。下次回来，我还会继续查。"]],
	[["林衡","武器拆开看过了。没有螺丝，也没有焊缝，像是整个长出来的。"],["林衡","要是有更多材料，我想试试这台打印机到底能做到哪一步。"],["林衡","放心。我不乱拆门。至少今天不拆。"]],
	[["贺维","我不在意它把这叫重建，还是别的什么。倒下的人总得有人记住。"],["贺维","你能看见我们，对吧？那就别只看任务进度。"],["贺维","出发前再检查一次。医疗包要放在伸手就能拿到的地方。"]]
]

static func person(id: String) -> Dictionary:
	for p in PEOPLE:
		if p.id == id: return p
	return PEOPLE[0]

static func mission(id: String) -> Dictionary:
	for m in MISSIONS:
		if m.id == id: return m
	return MISSIONS[0]

static func weapon_name(role: int, mk: int) -> String:
	return [["短刃与轻盾","制式步枪","重轨炮","修复器"],["磁脊盾刃","电弧步枪","加强轨炮","脉冲修复器"],["折光盾刃","聚束步枪","聚束轨炮","再生修复器"],["零式盾刃","零式步枪","零式轨炮","零式修复器"]][clampi(mk-1,0,3)][role]

static func skill_description(role: int, level: int) -> String:
	match role:
		0: return "每12秒造成%d%%伤害，获得%d护盾，持续4秒。" % [120+20*(level-1),30+12*(level-1)]
		1: return "每10秒攻击最多3名敌人，每名受到%d%%伤害。" % [80+15*(level-1)]
		2: return "每14秒穿透最多6名敌人，造成%d%%伤害，忽略50%%护甲。" % [150+20*(level-1)]
		_: return "每8秒治疗生命比例最低的存活队员，恢复%d生命。" % [40+15*(level-1)]


const MODULES = [
 {"id":"reflect","name":"反射甲片","mission":"M05","icon":"shield","description":"把受到的直接伤害的 5% / 7% / 9% / 11% / 13% 反射给攻击者。"},
 {"id":"regen","name":"再生膜","mission":"M07","icon":"medical","description":"每 10 秒恢复自身最大生命的 4% / 5% / 6% / 7% / 8%。阵亡后停止。"},
 {"id":"beam","name":"聚束轨炮","mission":"M08","icon":"cannon","description":"每 16 秒额外造成 100% / 120% / 140% / 160% / 180% 攻击伤害。"},
 {"id":"barrier","name":"信号屏障","mission":"M09","icon":"skill","description":"每 18 秒给存活队员 20 / 28 / 36 / 44 / 52 护盾，持续 4 秒。同类护盾取较高值。"}
]
const FACILITIES = [
 {"mission":"M03","credits":500,"alloy":12},
 {"mission":"M06","credits":1600,"alloy":35},
 {"mission":"M10","credits":4000,"alloy":80}
]
const MK_COST = [[100,4],[180,6],[260,8],[420,12]]
