extends "res://scripts/pixel_hyakki/progression/gear_base.gd"

const Builds = preload("res://scripts/pixel_hyakki/progression/rules.gd")
var growth:Dictionary = Builds.initial()
var card_rng = RandomNumberGenerator.new()
var new_cards:Array = []
var measurement = false
var migration_backup = ""
var recovery_backup = ""

func _init(seed_value:int=0) -> void:
	super(seed_value)
	card_rng.seed = rng.seed ^ 0x13579BDF

func snapshot() -> Dictionary:
	growth.gear_misses = misses
	var result = super.snapshot()
	result["growth"] = growth.duplicate(true);result["card_rng"] = card_rng.state
	return result

func restore(data:Dictionary) -> bool:
	if not data.get("state") is Dictionary:return false
	var old_state = data.state
	if not old_state.get("level") is int or old_state.level < 1 or old_state.level > 1000000:return false
	if not old_state.get("xp") is int or old_state.xp < 0:return false
	if not old_state.get("training") is Array:return false
	for value in old_state.training:
		if not value is int or value < 0 or value > 1000000:return false
	if not old_state.get("inventory") is Array:return false
	for item in old_state.inventory:
		if not item is Dictionary or not item.get("level") is int or item.level > 1000000:return false
	var proposed = data.get("growth",Builds.initial())
	if not Builds.valid(proposed):return false
	if data.has("card_rng") and not data.card_rng is int:return false
	if not super.restore(data):return false
	growth = proposed.duplicate(true);misses = growth.gear_misses
	if data.has("card_rng"):card_rng.state = data.card_rng
	else:card_rng.seed = rng.state ^ 0x13579BDF
	return true

func make_save_store(path:String):return Save.new(path)

func open_profile(path:String="user://pixel-equipment.json") -> void:
	persistence = make_save_store(path);persistence_enabled = true;last_error = ""
	for source in [persistence.path,persistence.path+".bak"]:
		var data = persistence.read_path(source)
		if data.is_empty() or not restore(data):continue
		if source.ends_with(".bak"):
			recovery_backup = persistence.path+".recovery-"+FileAccess.get_sha256(source).substr(0,16)+".json"
			if not FileAccess.file_exists(recovery_backup) and DirAccess.copy_absolute(source,recovery_backup)!=OK:
				last_error="恢复备份保留失败，已停止写入。";persistence_enabled=false;return
			if persistence.read_path(recovery_backup)!=data:
				last_error="恢复备份校验失败，已停止写入。";persistence_enabled=false;return
		if not data.has("growth"):
			var hash = FileAccess.get_sha256(source)
			migration_backup = persistence.path+".before-growth-"+hash.substr(0,16)+".json"
			if not FileAccess.file_exists(migration_backup):
				if DirAccess.copy_absolute(source,migration_backup) != OK:
					last_error = "旧档备份失败，已保留原文件并停止写入。";persistence_enabled = false;return
			if persistence.read_path(migration_backup) != data:
				last_error = "旧档备份校验失败，已保留原文件并停止写入。";persistence_enabled = false
		return
	if persistence.exists():last_error = "成长存档读取失败，已保留原文件。";persistence_enabled = false

func unlocked_depth() -> int:
	var best = 0
	for record in growth.worlds.values():best = maxi(best,record.best_depth)
	return 1 if best==0 else mini(int(cfg.limits.max_depth),best+int(cfg.limits.unlock_step))

func best_depth() -> int:
	var best = 0
	for record in growth.worlds.values():best = maxi(best,record.best_depth)
	return best

func owned_card_count() -> int:
	return growth.cards.values().filter(func(record):return record.copies>0).size()

func describe_item(item:Dictionary) -> String:
	return describe_rules(G.details(item))

func describe_rules(value:String) -> String:
	return value.replace("每次行动获得10点护盾","每次行动获得最大生命2%的护盾（至少10点；总护盾上限35%）").replace("入战时全队护甲提高5点（最多15点）","入战时全队护甲+5（最多+15）；存活时全队减伤2%（最多6%）")

func rank() -> int:return Builds.skill_rank(s.level)
func mode(hero:int) -> int:return growth.modes[hero] if rank() > 0 else -1

func award(level:int,theme:int,quality:int=-1,base:int=-1) -> Dictionary:
	var item = super.award(level,theme,quality,base)
	# Only newly dropped items change. Existing saved items remain byte-for-byte.
	if level > 200:
		for key in item.affixes:
			if not G.AFFIX[key][3] and not (item.quality==5 and key=="atk"):
				item.affixes[key] = snappedf(item.affixes[key]*(1.0+.055*level)/12.0,.1)
	return item

func card_rank(id:String) -> int:
	if id not in growth.slots:return 0
	return Builds.card_rank(growth.cards.get(id,{}).get("copies",0))

func choose_mode(hero:int,choice:int) -> bool:
	if hero < 0 or hero >= 5 or choice not in [0,1] or rank() == 0:return false
	growth.modes[hero] = choice;return true

func choose_cards(ids:Array) -> bool:
	var copy = growth.duplicate(true);copy.slots = ids.duplicate()
	if not Builds.valid(copy):return false
	growth.slots = ids.duplicate();return true

func discover(id:String,guaranteed:bool=false) -> void:
	if id not in Builds.CARD_IDS:return
	if not growth.cards.has(id):growth.cards[id] = {"copies":0,"kills":0,"misses":0}
	var record = growth.cards[id]
	record.kills += 1
	if guaranteed or record.misses >= Builds.CARD_PITY-1 or card_rng.randf() < Builds.CARD_CHANCE:
		record.copies += 1;record.misses = 0
		if record.copies == 1:
			new_cards.append(id)
			if growth.slots.size() < Builds.MAX_SLOTS:growth.slots.append(id)
	else:record.misses += 1

func reward(enemy:Dictionary) -> void:
	if measurement:b.kills += 1;return
	super.reward(enemy)
	growth.gear_misses = misses
	discover(enemy.get("species",""))

func record_clear(world:String,scene:String,depth:int,boss:bool) -> void:
	var key = world+":"+scene
	var record = growth.scenes.get(key,{"clears":0,"best_depth":0})
	record.clears += 1;record.best_depth = maxi(record.best_depth,depth);growth.scenes[key] = record
	if boss:
		var w = growth.worlds.get(world,{"clears":0,"best_depth":0})
		w.clears += 1;w.best_depth = maxi(w.best_depth,depth);growth.worlds[world] = w
		discover(world,true)

func deal(id:int,amount:float,event:Dictionary,crit:bool,tag:String) -> float:
	if b.units[id].side == 0:
		amount *= 1.0-.012*card_rank("sleepbeast")
		var guardians = 0
		for u in b.units:
			if u.side==0 and u.hp>0 and "guardian" in u.stats.powers:guardians += 1
		amount *= 1.0-.02*mini(3,guardians)
	return super.deal(id,amount,event,crit,tag)

func strike(actor:Dictionary,target:int,amount:float,event:Dictionary) -> void:
	var victim = b.units[target];var st = actor.stats
	if rng.randf()*100 < victim.stats.dodge:
		event.hits.append({"id":target,"before":victim.hp,"after":victim.hp,"damage":0,"crit":false,"tag":"闪避"});return
	var crit = rng.randf()*100 < st.crit
	if crit:amount *= st.crit_damage/100.0
	if victim.boss:amount *= 1+st.elite/100.0
	if "execute" in st.powers and victim.hp < victim.maxhp*.5:amount *= 1.35
	if st.get("attack_element","physical") == "fire":
		amount *= 1-victim.stats.resist/100.0
	else:
		var armor = maxf(0,victim.stats.armor)*cfg.combat.armor_scale
		amount *= 1-cfg.combat.armor_asymptote*armor/(cfg.combat.armor_constant+armor)
	amount += (st.fire+st.cold+st.lightning)*(1-victim.stats.resist/100.0)
	if rng.randf()*100 < victim.stats.block:amount *= .5
	var actual = deal(target,maxf(1,amount),event,crit,"")
	if st.vamp > 0:heal(actor.id,actual*st.vamp/100.0,event)
	if victim.hp > 0:
		if st.cold > 0:victim.slow = minf(5,st.cold*.2)
		if st.poison > 0 or "bleed" in st.powers:
			victim.dot = maxf(victim.dot,st.poison*(1-victim.stats.resist/100.0)+(st.atk*.15 if "bleed" in st.powers else 0));victim.dot_turns = 2
	if victim.stats.thorns > 0 and actor.hp > 0:deal(actor.id,victim.stats.thorns,event,false,"反伤")
