extends RefCounted

const MODES = [
	["决斗", "横斩"], ["破甲", "守护"], ["集中火力", "跳弹"],
	["急救", "战术支援"], ["余烬", "爆燃"]
]
const SKILL_LEVELS = [3,10,20,35,50]
const CARD_IDS = ["tengu","umbrella","oni","kappa","wheel","hyakki","sleepbeast"]
const CARD_NAMES = ["天狗观察","唐伞观察","赤鬼观察","河童观察","轮入道观察","百鬼夜行","眠兽余温"]
const CARD_THRESHOLDS = [1,3,8,20,40]
const CARD_CHANCE = 0.06
const CARD_PITY = 30
const MAX_SLOTS = 3
const SHIELD_CAP = 0.35

static func skill_description(hero:int,choice:int,rank:int) -> String:
	var strength = 1.0+.06*maxi(0,rank-1)
	var descriptions = [
		["主目标伤害 +%.1f%%"%(25*strength),"主目标伤害 90%%；每次行动额外攻击两敌，各造成 %.1f%% 攻击伤害"%(35*strength)],
		["主目标伤害 +%.1f%%；命中削减初始护甲 %.1f%%，累计最多 40%%"%[10*strength,8*strength],"每次行动为生命比例最低的队友提供 %.1f%% 最大生命护盾"%(6.5*strength)],
		["对首领或最后一名敌人的主攻击伤害 +%.1f%%"%(25*strength),"每次四发射击额外跳弹一次，造成 %.1f%% 攻击伤害"%(50*strength)],
		["每次行动额外治疗：%.1f%% 攻击 + 目标 %.2f%% 最大生命"%[35*strength,2*strength],"存活时，全队主攻击伤害 +%.1f%%"%(12*strength)],
		["直击伤害 90%%；燃烧每 0.8 秒造成 %.1f%% 攻击的火焰伤害，持续 3.3 秒"%(20*strength),"火球直击伤害 +%.1f%%，不附加燃烧"%(45*strength)]
	]
	return descriptions[hero][choice]

static func card_description(id:String,rank:int) -> String:
	match id:
		"tengu":return "全队暴击率 +%.1f 个百分点"%(1.2*rank)
		"umbrella":return "入场护盾 +%d%% 最大生命；总护盾上限 35%%"%(4*rank)
		"oni":return "全队最大生命 +%.1f%%"%(2.5*rank)
		"kappa":return "全队治疗加成 +%d 个百分点"%(6*rank)
		"wheel":return "燃烧、毒与流血伤害 +%d%%"%(5*rank)
		"hyakki":return "横斩与跳弹的额外目标伤害 +%d%%"%(4*rank)
		"sleepbeast":return "全队受到的伤害降低 %.1f%%"%(1.2*rank)
	return ""

static func skill_rank(level:int) -> int:
	var rank = 0
	for threshold in SKILL_LEVELS:
		if level >= threshold:rank += 1
	return rank

static func card_rank(copies:int) -> int:
	var rank = 0
	for threshold in CARD_THRESHOLDS:
		if copies >= threshold:rank += 1
	return rank

static func initial() -> Dictionary:
	return {"schema":1,"modes":[0,0,0,0,0],"cards":{},"slots":[],"scenes":{},"worlds":{},"gear_misses":0}

static func valid(p:Variant) -> bool:
	if not p is Dictionary or p.get("schema",0) != 1:return false
	if not p.get("modes") is Array or p.modes.size() != 5:return false
	for mode in p.modes:
		if not mode is int or mode not in [0,1]:return false
	if not p.get("cards") is Dictionary or not p.get("slots") is Array or p.slots.size() > MAX_SLOTS:return false
	if not p.get("gear_misses") is int or p.gear_misses < 0 or p.gear_misses > 7:return false
	for id in p.cards:
		if id not in CARD_IDS or not p.cards[id] is Dictionary:return false
		for key in ["copies","kills","misses"]:
			if not p.cards[id].get(key) is int or p.cards[id][key] < 0:return false
		if p.cards[id].misses >= CARD_PITY:return false
	var used = {}
	for id in p.slots:
		if not id is String or id not in p.cards or p.cards[id].copies < 1 or used.has(id):return false
		used[id] = true
	for key in ["scenes","worlds"]:
		if not p.get(key) is Dictionary:return false
		for id in p[key]:
			var record = p[key][id]
			if not id is String or not record is Dictionary:return false
			for field in ["clears","best_depth"]:
				if not record.get(field) is int or record[field] < 1:return false
	return true
