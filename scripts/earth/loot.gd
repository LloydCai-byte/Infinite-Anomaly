extends RefCounted
## Equipment is independent of the costume + weapon package.
const SLOTS=["head","hands","charm"]
const SLOT_NAMES={"head":"头部","hands":"手部","charm":"饰品"}
const QUALITY=["制式","精良","异质"]
const COLORS=[Color("d7dfdc"),Color("87df8f"),Color("ffb447")]
const AFFIX_NAMES={"hp":"生命","atk":"攻击","armor":"防御","haste":"攻速","skill":"技能强度"}
const BASES=[
	{"name":"棱镜头盔","slot":"head","special":"laser","flavor":"折光核心在头顶凝成一只独眼精灵。"},
	{"name":"脉冲护手","slot":"hands","special":"bomb","flavor":"悬浮火种会追踪敌群，引发脉冲爆破。"},
	{"name":"潮汐吊坠","slot":"charm","special":"regen","flavor":"微小的水灵跟随佩戴者，修复队友伤口。"},
	{"name":"守夜面罩","slot":"head","special":"","flavor":"带有细密裂纹的面罩，仍然可靠。"},
	{"name":"纤维手套","slot":"hands","special":"","flavor":"指节间藏着异常韧性的纤维。"},
	{"name":"回声护符","slot":"charm","special":"","flavor":"安静时能听见另一个房间的钟声。"}
]
const SPECIAL_NAMES={"laser":"折光精灵","bomb":"脉冲火种","regen":"潮汐水灵"}
const INTERVALS={"laser":5.0,"bomb":8.0,"regen":7.0}

static func make(stage: int,serial: int,seed_value: int,first=false) -> Dictionary:
	var rng=RandomNumberGenerator.new()
	rng.seed=seed_value+serial*104729+stage*1009
	var quality=1 if rng.randf()<.55 else (2 if rng.randf()<.75 else 3)
	var base=rng.randi_range(0,BASES.size()-1)
	if first:base=0;quality=2
	var keys=AFFIX_NAMES.keys()
	var affixes={}
	for i in range(2 if quality<3 else 3):
		var pick=rng.randi_range(0,keys.size()-1)
		var key=keys.pop_at(pick)
		affixes[key]=snappedf((2.0+quality*2.0+stage*.12)*rng.randf_range(.8,1.2),.1)
	return {"id":serial,"base":base,"quality":quality,"level":stage,"affixes":affixes}

static func valid(item: Variant) -> bool:
	if not item is Dictionary:return false
	for key in ["id","base","quality","level"]:
		if not item.get(key) is int:return false
	if item.id<1 or item.base<0 or item.base>=BASES.size() or item.quality<1 or item.quality>3 or item.level<1 or item.level>300:return false
	if not item.get("affixes") is Dictionary or item.affixes.size()<2 or item.affixes.size()>3:return false
	for key in item.affixes:
		var value=item.affixes[key]
		if not AFFIX_NAMES.has(key) or not (value is int or value is float) or not is_finite(float(value)) or value<=0 or value>60:return false
	return true

static func valid_inventory(data: Dictionary) -> bool:
	if not data.get("inventory") is Array or not data.get("equipped") is Array or data.equipped.size()!=5:return false
	if not data.get("loot_serial") is int or data.loot_serial<1 or not data.get("loot_seed") is int:return false
	var ids={}
	for item in data.inventory:
		if not valid(item) or ids.has(item.id) or item.id>=data.loot_serial:return false
		ids[item.id]=item
	var worn={}
	for loadout in data.equipped:
		if not loadout is Dictionary:return false
		for slot in loadout:
			var id=loadout[slot]
			if slot not in SLOTS or not id is int or not ids.has(id) or worn.has(id):return false
			if BASES[ids[id].base].slot!=slot:return false
			worn[id]=true
	return true

static func name_of(item: Dictionary) -> String:
	return BASES[item.base].name

static func affix_text(item: Dictionary) -> String:
	var lines=PackedStringArray()
	for key in item.affixes:lines.append("%s +%.1f%%"%[AFFIX_NAMES[key],item.affixes[key]])
	return "\n".join(lines)

static func special_text(item: Dictionary) -> String:
	var id=BASES[item.base].special
	if id=="":return "无召唤词条 · 专注属性提升"
	var power=1+.25*(item.quality-1)
	match id:
		"laser":return "召唤折光精灵：每 5 秒发射激光，造成佩戴者 %.0f%% 攻击的穿甲伤害。"%(power*145)
		"bomb":return "召唤脉冲火种：每 8 秒轰击敌群，分别造成佩戴者 %.0f%% 攻击的伤害。"%(power*90)
		"regen":return "召唤潮汐水灵：每 7 秒治疗生命比例最低的队友，恢复其 %.1f%% 最大生命。"%(power*8)
	return ""
