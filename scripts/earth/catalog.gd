extends RefCounted
const VERSION = "0.11.0-earth"
const Assets = preload("res://scripts/earth/assets.gd")
const Anomalies = preload("res://scripts/earth/anomalies.gd")
const CAMPAIGN_STAGE_COUNT = 300
const STAGE_COUNT = 302
const SUITS = [
	{"tier":1,"name":"制式战斗服","unlock":0,"room":1,"factor":1.0,"credits":0,"alloy":0,"cores":0,"weapons":["冲击短棍","制式太刀","强化拳套","标记手枪","修复手枪"],"look":"黑色贴身战斗服、克制的灰色节点；各自脸型与发型保留。"},
	{"tier":2,"name":"磁脊强化服","unlock":3,"room":2,"factor":1.55,"credits":340,"alloy":12,"cores":1,"weapons":["磁脊盾棍","磁刃太刀","重力拳套","感应步枪","脉冲修复枪"],"look":"深蓝外覆甲、浅色肩部与小型电弧节点，武器同步升级。"},
	{"tier":3,"name":"零式共鸣服","unlock":6,"room":3,"factor":2.35,"credits":900,"alloy":28,"cores":3,"weapons":["零式盾斧","共鸣长刀","零式重拳","聚束步枪","再生投射器"],"look":"米白胸肩甲与黑色内衬，紫色能量节点，武器轮廓增强。"}
]
const SUPPORTS = [
	{"id":"laser","name":"折光激光盒","unlock":3,"interval":6.0,"description":"每 6 秒打击一名异常；伤害随装置等级与小队攻击成长。"},
	{"id":"regen","name":"潮汐再生器","unlock":5,"interval":8.0,"description":"每 8 秒恢复全体存活战士的生命；不复活已倒下者。"},
	{"id":"bomb","name":"信标轰击器","unlock":6,"interval":10.0,"description":"每 10 秒轰击当前全部敌人。"}
]
const AREAS = [
	["夜行街区","street","katana","青发刀客","巡游"],
	["封闭公寓","apartment","hollow","空壳住民","包围"],
	["激光盒子","rooftop","eye","持盒异常","激光"],
	["高架桥下","overpass","hound","磁脊犬","重甲"],
	["海边泵站","pumps","parasite","潮汐簇","再生"],
	["通信塔群","towers","beacon","信标偶","齐射"],
	["冷冻仓库","freezer","frost","霜棘搬运体","冰冻"],
	["旧观测台","observatory","sentinel","环首观察者","护盾"],
	["地下商场","mall","mirror","镜壳主机","蜂群"],
	["零号地铁","metro","warden","门卫","变异"]
]
const PEOPLE = [
	{"id":"dadong","name":"大东老师","role":"先锋","hp":360.0,"atk":25.0,"armor":12.0,"interval":1.15,"skill":"坚守","file":"大东老师.png","portrait":[663,43,339,465]},
	{"id":"fenfen","name":"粉粉","role":"突击","hp":285.0,"atk":34.0,"armor":7.0,"interval":1.0,"skill":"破势","file":"粉粉.png","portrait":[644,40,359,465]},
	{"id":"gao","name":"高哥","role":"重击","hp":410.0,"atk":39.0,"armor":14.0,"interval":1.45,"skill":"震荡","file":"高哥.png","portrait":[653,42,350,466]},
	{"id":"wang","name":"老王","role":"控制","hp":290.0,"atk":28.0,"armor":8.0,"interval":1.25,"skill":"弱点标记","file":"老王.png","portrait":[644,42,359,465]},
	{"id":"qiqi","name":"七七","role":"恢复","hp":275.0,"atk":22.0,"armor":6.0,"interval":1.1,"skill":"生息","file":"七七.png","portrait":[90,20,84,124]}
]

static func portrait(index: int) -> Texture2D:
	var p = PEOPLE[index]
	if Assets.final_available("portrait."+p.id): return Assets.texture("portrait."+p.id)
	var texture = AtlasTexture.new()
	texture.atlas = load("res://assets/earth/cast/"+p.file)
	var r = p.portrait
	texture.region = Rect2(r[0],r[1],r[2],r[3])
	return texture

static func mission(stage: int) -> Dictionary:
	if Anomalies.has_stage(stage):return Anomalies.mission(stage)
	var area=AREAS[(stage-1)%AREAS.size()]
	var chapter=int((stage-1)/10)+1
	var patterns=[[2,3],[3,2,3],[4,2],[2,4,3,2],[3,3,2]]
	var pattern=patterns[(stage-1)%patterns.size()].duplicate()
	if area[4]=="蜂群": pattern=[5,4,6]
	return {"stage":stage,"chapter":chapter,"name":area[0]+(" · 异常等级 %d"%chapter if chapter>1 else ""),"bg":area[1],"enemy":area[2],"boss":area[3],"mechanic":area[4],"schedule":pattern,"encounters":pattern.size()+1,"count":pattern[0],"factor":1+.16*(stage-1),"credits":130+stage*35,"alloy":3+int(stage/3),"cores":1+int(stage/60) if stage%3==0 else 0}

static func mechanic_tip(name: String) -> String:
	if name=="怪谈清剿":return "沿五段长街向右推进，每段五个敌人；队员持续自动攻击，肃清全部目标后结算。"

	return {"巡游":"刀客向前冲击，先锋承伤，突击与重击处理近身目标。","包围":"部分异常从后方出现，注意七七的生命。","激光":"首领周期性向全队扫射；击败后可取得激光盒配方。","重甲":"高护甲压低普通伤害；老王的标记与爆发技能更有效。","再生":"异常周期恢复生命；持续输出压过恢复，取得再生器配方。","齐射":"首领集体射击；空间可解锁独立轰击支援。","冰冻":"寒冷减缓队伍移动速度，攻击间隔保持不变。","护盾":"异常携带额外护盾，先破盾再损伤本体。","蜂群":"多批密集小怪，高哥震荡和轰击装置能同时打击多个目标。","变异":"首领兼具重甲和更快攻击；这是当前异常等级的收束任务。"}.get(name,"")

static func stage_unlocked(stage: int,max_stage: int) -> bool:
	return Anomalies.has_stage(stage) or (stage>=1 and stage<=mini(max_stage,CAMPAIGN_STAGE_COUNT))

static func next_stage(stage: int) -> int:
	return stage+1 if stage<CAMPAIGN_STAGE_COUNT or stage==301 else 0
