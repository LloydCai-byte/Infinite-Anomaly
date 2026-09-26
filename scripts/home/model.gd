extends RefCounted
## September design: each expedition is a prior self's memory; room state is the latest self.
const DATA = preload("res://scripts/home/content.gd")
var db: Dictionary = DATA.get_data()
var s: Dictionary = {}

func _init() -> void:
	new_game()

func new_game() -> void:
	s = {"version": 2, "food": 100.0, "xp": 0, "skills": {"combat":0,"perception":0,"survival":0},
		"cards": {}, "cleared": [], "stage": 0, "mode": "HOME", "generation": 1,
		"attempts": 0, "attempt_id": 0, "settled_id": 0, "remaining": 0.0, "duration": 0.0,
		"snapshot": {}, "auto": false, "auto_wait": 0.0, "focus": "perception", "room": "entry",
		"intro": false, "first_departure": true, "result": {}, "history": [], "played": 0.0,
		"ending_seen": false, "checkpoint": 0, "muted": false, "volume": 0.4, "reduced_motion": false}

func export_state() -> Dictionary:
	return s.duplicate(true)

func restore(value: Dictionary) -> bool:
	if value.get("version", 0) != 2:
		return false
	for key in s:
		if not value.has(key):
			return false
	if value.mode not in ["HOME","MEMORY","GAMEOVER","ENDING"] or value.mode == "GAMEOVER":
		return false
	if not is_finite(float(value.food)) or float(value.food) <= 0 or float(value.food) > 100:
		return false
	if int(value.xp) < 0 or int(value.stage) < 0 or int(value.stage) >= db.stages.size():
		return false
	if value.focus not in db.branches or value.room not in ["entry","hall","kitchen","bathroom","bedroom","desk","balcony"]:
		return false
	if not value.skills is Dictionary or not value.cards is Dictionary:
		return false
	for branch in db.branches:
		if not value.skills.has(branch) or int(value.skills[branch]) < 0 or int(value.skills[branch]) > 3:
			return false
	for card in value.cards:
		if card not in card_ids() or int(value.cards[card]) < 1:
			return false
	if not value.cleared is Array or not value.history is Array:
		return false
	for id in value.cleared:
		if id not in card_ids():
			return false
	if value.mode == "MEMORY":
		if not value.snapshot is Dictionary:
			return false
		for key in ["stage","stats","focus","first","id"]:
			if not value.snapshot.has(key):
				return false
		if int(value.snapshot.stage) < 0 or int(value.snapshot.stage) >= db.stages.size() or float(value.remaining) <= 0:
			return false
		if value.snapshot.focus not in db.branches or not value.snapshot.stats is Dictionary:
			return false
		for b in db.branches:
			if not value.snapshot.stats.has(b):
				return false
	s = value.duplicate(true)
	return true

func card_ids() -> Array:
	var ids: Array = []
	for stage in db.stages:
		ids.append(stage.id)
	return ids

func stats() -> Dictionary:
	var result: Dictionary = {}
	for b in db.branches:
		result[b] = 1 + int(s.skills[b])
	return result

func current_stage() -> Dictionary:
	var index: int = int(s.snapshot.stage) if s.mode == "MEMORY" else int(s.stage)
	return db.stages[index]

func can_act() -> bool:
	return s.mode not in ["GAMEOVER","ENDING"]

func depart() -> bool:
	if s.mode != "HOME":
		return false
	s.attempts += 1
	s.attempt_id += 1
	s.generation += 1
	s.snapshot = {"id":s.attempt_id,"stage":s.stage,"stats":stats(),"focus":s.focus,"first":s.first_departure}
	s.first_departure = false
	s.mode = "MEMORY"
	s.duration = float(db.stages[s.stage].duration)
	s.remaining = s.duration
	s.auto_wait = 0.0
	s.room = "entry"
	return true

func tick(seconds: float) -> String:
	if not can_act():
		return ""
	var dt: float = maxf(0.0, seconds)
	s.played += dt
	var alive_time: float = float(s.food) / float(db.balance.food_per_second)
	if dt >= alive_time:
		s.food = 0.0
		s.mode = "GAMEOVER"
		s.auto = false
		return "gameover"
	s.food = maxf(0, float(s.food) - dt * float(db.balance.food_per_second))
	if s.mode == "MEMORY":
		s.remaining = maxf(0.0, float(s.remaining) - dt)
		if s.remaining <= 0:
			settle()
			return "settled"
	elif s.auto and s.mode == "HOME":
		s.auto_wait = maxf(0.0, float(s.auto_wait) - dt)
		if s.auto_wait <= 0 and depart():
			return "departed"
	return ""

func settle() -> bool:
	if s.mode != "MEMORY" or s.remaining > 0 or int(s.attempt_id) <= int(s.settled_id):
		return false
	s.settled_id = s.attempt_id
	var chapter: Dictionary = db.stages[int(s.snapshot.stage)]
	var eligible: Array = []
	for branch in db.branches:
		if int(s.snapshot.stats[branch]) >= int(chapter.thresholds[branch]):
			eligible.append(branch)
	var route: String = str(s.snapshot.focus) if s.snapshot.focus in eligible else (str(eligible[0]) if not eligible.is_empty() else "")
	var success: bool = route != "" and not s.snapshot.first
	var first: bool = not s.cards.has(chapter.id)
	s.cards[chapter.id] = int(s.cards.get(chapter.id, 0)) + 1
	var earned: int = int(db.balance.first_xp) if first else int(db.balance.repeat_xp)
	s.xp += earned
	var text: String = chapter.routes[route] if success else chapter.failure
	s.result = {"id":s.attempt_id,"stage":s.snapshot.stage,"card":chapter.id,"new":first,"success":success,
		"route":route if success else "", "text":text,"xp":earned,"generation":s.generation}
	s.history.push_front(s.result.duplicate(true))
	if s.history.size() > 60:
		s.history.resize(60)
	s.mode = "HOME"
	s.auto_wait = float(db.balance.auto_delay)
	if success:
		if chapter.id not in s.cleared:
			s.cleared.append(chapter.id)
		if int(s.snapshot.stage) == db.stages.size() - 1:
			s.mode = "ENDING"
			s.auto = false
		else:
			s.stage = maxi(int(s.stage), int(s.snapshot.stage) + 1)
	return true

func set_auto(enabled: bool) -> bool:
	if not can_act():
		return false
	s.auto = enabled
	s.auto_wait = float(db.balance.auto_delay)
	return true

func set_focus(branch: String) -> bool:
	if branch not in db.branches or not can_act():
		return false
	s.focus = branch
	return true

func upgrade(branch: String) -> bool:
	if branch not in db.branches or not can_act():
		return false
	var level: int = int(s.skills[branch])
	if level >= 3:
		return false
	var cost: int = int(db.balance.skill_costs[level])
	if int(s.xp) < cost:
		return false
	s.xp -= cost
	s.skills[branch] += 1
	return true

func absorb(card: String, all_duplicates: bool = false) -> int:
	if not can_act() or int(s.cards.get(card, 0)) <= 1:
		return 0
	var count: int = int(s.cards[card]) - 1 if all_duplicates else 1
	s.cards[card] -= count
	s.xp += count * int(db.balance.absorb_xp)
	return count

func supply() -> bool:
	if not can_act() or int(s.xp) < int(db.balance.supply_cost) or float(s.food) >= 99.999:
		return false
	s.xp -= int(db.balance.supply_cost)
	s.food = minf(100.0, float(s.food) + float(db.balance.supply_amount))
	return true

func select_stage(index: int) -> bool:
	if s.mode != "HOME" or index < 0 or index >= db.stages.size():
		return false
	if index > 0 and db.stages[index-1].id not in s.cleared:
		return false
	s.stage = index
	return true

func progress() -> float:
	return 1.0 - float(s.remaining) / maxf(float(s.duration), 1.0) if s.mode == "MEMORY" else 0.0
