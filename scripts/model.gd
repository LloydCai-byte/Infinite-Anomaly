extends RefCounted
## Pure gameplay model. Only this class awards resources, cards or completion.
const Content = preload("res://scripts/content.gd")

var content = Content.new()
var db: Dictionary = content.data
var s: Dictionary = {}
var rng = RandomNumberGenerator.new()

func _init() -> void:
	new_game()

func new_game(seed_value: int = 0) -> void:
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	s = {"save_version": 1, "revision": 0, "tutorial": false,
		"credits": 0, "energy": 0, "upgrades": {"action": 0, "display": 0, "living": 0},
		"cards": [], "tags": [], "completed": [], "cleared": [], "claimed": [],
		"mode": "IDLE", "dungeon": "A01", "target": "", "remaining": 0.0, "duration": 0.0,
		"attempt_serial": 0, "settled_serial": 0, "snapshot": {}, "carry": 0.0,
		"blocked": "", "block_reason": "", "block_seen": [], "pity": {},
		"unread_cards": [], "comics": [], "comic_progress": {}, "read_comics": [],
		"reading": "OPEN", "latest_comic": "OPEN", "events": [], "event_serial": 0,
		"last_result": {}, "first_obtained": {}, "skip_switch_warning": false,
		"last_checkpoint_utc": 0, "rng_state": str(rng.state)}
	unlock_comic("OPEN", 4)

func export_state() -> Dictionary:
	s.rng_state = str(rng.state)
	return s.duplicate(true)

func restore(value: Dictionary) -> bool:
	if int(value.get("save_version", -1)) != 1:
		return false
	for key in ["credits", "energy", "upgrades", "cards", "tags", "mode", "dungeon", "rng_state", "snapshot", "cleared", "claimed"]:
		if not value.has(key):
			return false
	if value.mode not in ["IDLE", "PUSH", "FARM", "BLOCKED"] or not db.dungeons.has(value.dungeon):
		return false
	if value.credits < 0 or value.energy < 0:
		return false
	if value.mode == "PUSH" and not db.stages.has(value.get("target", "")):
		return false
	if value.mode == "FARM" and not db.farms.has(value.get("target", "")):
		return false
	for card in value.cards:
		if not db.cards.has(card):
			return false
	var merged: Dictionary = s.duplicate(true)
	merged.merge(value.duplicate(true), true)
	s = merged
	rng.state = int(s.rng_state)
	return true

func power() -> int:
	return 1 + int(s.upgrades.action)

func event(text: String, kind: String = "info") -> void:
	s.event_serial += 1
	# Consecutive routine samples share a row; important events remain distinct.
	if kind == "sample" and not s.events.is_empty() and s.events[0].kind == "sample":
		var repeats: int = int(s.events[0].get("repeats", 1)) + 1
		s.events[0] = {"id": s.event_serial, "text": text + "（连续采集 %d 轮）" % repeats, "kind": kind, "repeats": repeats}
		return
	s.events.push_front({"id": s.event_serial, "text": text, "kind": kind})
	if s.events.size() > 40:
		s.events.resize(40)

func complete_tutorial() -> bool:
	if s.tutorial:
		return false
	s.tutorial = true
	grant_card("A01_01")
	s.claimed.append("tutorial")
	event("回归锚定已建立。打开任务档案，派出小队。", "new")
	s.revision += 1
	return true

func is_unlocked(dungeon_id: String) -> bool:
	if not db.dungeons.has(dungeon_id):
		return false
	var requirement: String = db.dungeons[dungeon_id].unlock_stage
	return s.tutorial and (requirement == "" or requirement in s.cleared)

func available_farms(dungeon_id: String) -> Array:
	var result: Array = []
	for farm_id in db.dungeons[dungeon_id].farms:
		if db.farms[farm_id].unlock_stage in s.cleared:
			result.append(farm_id)
	return result

func missing(stage_id: String) -> Array[String]:
	var result: Array[String] = []
	var stage: Dictionary = db.stages[stage_id]
	if power() < int(stage.power):
		result.append("需要处置等级 %d（升级行动中枢）" % stage.power)
	for tag in stage.tags:
		if tag not in s.tags:
			var source: String = "教程无主门卡" if tag == "anchor" else "阶段 3 首通白噪声听筒"
			result.append("需要%s（%s）" % [db.tags[tag], source])
	return result

func dispatch(dungeon_id: String, farm_id: String = "") -> bool:
	if not is_unlocked(dungeon_id):
		return false
	if farm_id != "" and farm_id not in available_farms(dungeon_id):
		return false
	s.dungeon = dungeon_id
	s.blocked = ""
	s.block_reason = ""
	s.carry = 0.0
	if farm_id != "":
		start_farm(farm_id)
	else:
		var next_stage: String = ""
		for id in db.dungeons[dungeon_id].stages:
			if id not in s.cleared:
				next_stage = id
				break
		if next_stage == "":
			start_farm(available_farms(dungeon_id).back())
		else:
			start_stage(next_stage)
	event("小队任务：" + db.dungeons[dungeon_id].name)
	s.revision += 1
	return true

func stop() -> bool:
	if s.mode == "IDLE":
		return false
	s.mode = "IDLE"
	s.target = ""
	s.remaining = 0.0
	s.duration = 0.0
	s.carry = 0.0
	s.snapshot = {}
	event("小队已返回主神空间。已到账收益保留。")
	s.revision += 1
	return true

func start_stage(id: String) -> void:
	var gaps: Array[String] = missing(id)
	if not gaps.is_empty():
		s.blocked = id
		s.block_reason = "；".join(gaps)
		var key: String = id + s.block_reason
		if key not in s.block_seen:
			s.block_seen.append(key)
			unlock_comic("BLOCKED", 4)
			event("前线受阻：" + s.block_reason, "blocked")
		var farms: Array = available_farms(s.dungeon)
		if farms.is_empty():
			s.mode = "BLOCKED"
			s.target = ""
			s.remaining = 0.0
			s.duration = 0.0
			s.snapshot = {}
		else:
			start_farm(farms.back())
		return
	s.blocked = ""
	s.block_reason = ""
	begin_attempt("PUSH", id, float(db.stages[id].duration))
	unlock_comic(db.stages[id].comic, 1)

func start_farm(id: String) -> void:
	begin_attempt("FARM", id, float(db.farms[id].duration))

func begin_attempt(mode: String, id: String, seconds: float) -> void:
	s.mode = mode
	s.target = id
	s.duration = seconds
	s.remaining = seconds
	s.attempt_serial += 1
	s.snapshot = {"id": s.attempt_serial, "mode": mode, "target": id, "power": power(), "tags": s.tags.duplicate(), "duration": seconds}

func retry() -> bool:
	if s.blocked == "" or not missing(s.blocked).is_empty():
		return false
	var target: String = s.blocked
	s.carry = 0.0
	start_stage(target)
	event("条件已满足，重新进入前线。", "upgrade")
	s.revision += 1
	return true

func tick(seconds: float, max_settlements: int = 8) -> int:
	if s.mode not in ["PUSH", "FARM"]:
		s.carry = 0.0
		return 0
	s.carry += maxf(seconds, 0.0)
	var count: int = 0
	while s.carry > 0 and s.mode in ["PUSH", "FARM"] and count < max_settlements:
		var consumed: float = minf(float(s.carry), float(s.remaining))
		s.remaining = maxf(0.0, float(s.remaining) - consumed)
		s.carry = maxf(0.0, float(s.carry) - consumed)
		if s.mode == "PUSH":
			var panels: int = mini(4, 1 + int((1.0 - float(s.remaining) / float(s.duration)) * 4.0))
			unlock_comic(db.stages[s.target].comic, panels, false)
		if s.remaining > 0.00001:
			break
		if not settle(int(s.attempt_serial)):
			break
		count += 1
	if s.mode not in ["PUSH", "FARM"]:
		s.carry = 0.0
	return count

func settle(attempt_id: int) -> bool:
	if s.mode not in ["PUSH", "FARM"] or s.remaining > 0.00001:
		return false
	if attempt_id != int(s.attempt_serial) or attempt_id <= int(s.settled_serial):
		return false
	var old_credits: int = int(s.credits)
	var old_energy: int = int(s.energy)
	var old_cards: int = s.cards.size()
	var mode: String = s.mode
	var target: String = s.target
	s.settled_serial = attempt_id
	var obtained: String = ""
	if mode == "PUSH":
		var stage: Dictionary = db.stages[target]
		unlock_comic(stage.comic, 4, false)
		if target not in s.claimed:
			s.credits += int(stage.credits)
			s.energy += int(stage.energy)
			if stage.card != "":
				obtained = stage.card
				grant_card(stage.card)
			s.claimed.append(target)
		if target not in s.cleared:
			s.cleared.append(target)
		event("首通 · " + stage.name, "success")
	else:
		var farm: Dictionary = db.farms[target]
		s.credits += int(farm.credits)
		s.energy += int(farm.energy)
		obtained = draw_pool(farm.pool)
	check_collections()
	s.last_result = {"attempt": attempt_id, "credits": int(s.credits) - old_credits, "energy": int(s.energy) - old_energy, "card": obtained, "new": s.cards.size() > old_cards}
	if mode == "FARM":
		var label: String = "首次收容" if s.last_result.new else "回响解析"
		event("%s · %s  +%d 信用点 / +%d 能量" % [label, db.cards[obtained].name, s.last_result.credits, s.last_result.energy], "new" if s.last_result.new else "sample")
		start_farm(target)
	else:
		var stages: Array = db.dungeons[s.dungeon].stages
		var index: int = stages.find(target)
		if index + 1 < stages.size():
			start_stage(stages[index + 1])
		else:
			start_farm(available_farms(s.dungeon).back())
			event("副本通关，自动采集关底回响。新副本由你主动选择。", "success")
	s.revision += 1
	return true

func grant_card(id: String) -> bool:
	if id in s.cards:
		s.energy += int(db.cards[id].duplicate)
		return false
	s.cards.append(id)
	s.unread_cards.append(id)
	s.first_obtained[id] = Time.get_datetime_string_from_system(false, true)
	var tag: String = db.cards[id].tag
	if tag != "" and tag not in s.tags:
		s.tags.append(tag)
		event("能力已解锁 · " + db.tags[tag], "upgrade")
	return true

func missing_cards(pool_id: String) -> Array:
	var result: Array = []
	for id in db.pools[pool_id].cards:
		if id not in s.cards:
			result.append(id)
	return result

func draw_pool(pool_id: String) -> String:
	var pool: Dictionary = db.pools[pool_id]
	var missing_ids: Array = missing_cards(pool_id)
	var count: int = int(s.pity.get(pool_id, 0))
	var candidates: Array = missing_ids if not missing_ids.is_empty() and count >= int(pool.pity) - 1 else pool.cards
	var chosen: String = candidates[rng.randi_range(0, candidates.size() - 1)]
	var is_new: bool = grant_card(chosen)
	s.pity[pool_id] = 0 if is_new or missing_ids.is_empty() else count + 1
	if missing_cards(pool_id).is_empty():
		s.pity[pool_id] = 0
	return chosen

func check_collections() -> void:
	for id in db.collections:
		if id in s.completed:
			continue
		var collection: Dictionary = db.collections[id]
		var complete: bool = true
		for card in collection.cards:
			if card not in s.cards:
				complete = false
		if not complete:
			continue
		s.completed.append(id)
		s.claimed.append("collection:" + id)
		var bonus: float = 1.2 if s.upgrades.display > 0 else 1.0
		s.credits += int(round(float(collection.credits) * bonus))
		s.energy += int(collection.energy)
		unlock_comic(collection.ending, 4)
		event("金边结案 · %s  +%d 信用点 / +%d 能量" % [collection.name, int(round(collection.credits * bonus)), collection.energy], "gold")
	for pool in db.pools:
		if missing_cards(pool).is_empty():
			s.pity[pool] = 0

func buy(id: String) -> bool:
	if not db.upgrades.has(id):
		return false
	var upgrade: Dictionary = db.upgrades[id]
	if int(s.upgrades[id]) >= int(upgrade.max) or s.credits < upgrade.credits or s.energy < upgrade.energy:
		return false
	s.credits -= int(upgrade.credits)
	s.energy -= int(upgrade.energy)
	s.upgrades[id] += 1
	event("设施升级 · " + upgrade.name, "upgrade")
	s.revision += 1
	return true

func unlock_comic(id: String, panels: int, make_latest: bool = true) -> void:
	if id not in s.comics:
		s.comics.append(id)
	s.comic_progress[id] = maxi(int(s.comic_progress.get(id, 0)), panels)
	if make_latest:
		s.latest_comic = id

func read_comic(id: String) -> void:
	s.reading = id
	if int(s.comic_progress.get(id, 0)) == 4 and id not in s.read_comics:
		s.read_comics.append(id)

func collection_count(id: String) -> int:
	var count: int = 0
	for card in db.collections[id].cards:
		if card in s.cards:
			count += 1
	return count
