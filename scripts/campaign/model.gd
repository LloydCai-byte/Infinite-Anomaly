extends RefCounted
const Catalog = preload("res://scripts/campaign/catalog.gd")
var nodes: Array = Catalog.read()
var s: Dictionary

func _init() -> void:
	new_game()

func new_game() -> void:
	s = {"version":3, "food":100.0, "xp":0, "skills":{"perception":0,"combat":0,"survival":0},
		"mode":"HOME", "room":"entry", "frontier":0, "selected":0, "seen":{}, "cleared":[],
		"failures":{}, "routes":{}, "memories":{}, "result":{}, "observed":[], "run":0, "settled":0,
		"timer":0.0, "auto":false, "chain":true, "focus":"perception", "intro":false,
		"played":0.0, "saved_at":"", "ending_seen":false, "volume":0.45, "motion":true,
		"text_speed":0.025, "fullscreen":false, "notice":"", "auto_runs":0}

func restore(value: Dictionary) -> bool:
	if value.get("version",0) != 3: return false
	for key in s:
		if not value.has(key): return false
	if value.mode not in ["HOME","EXPLORE","AUTO","WAIT","RESULT","ENDING"]: return false
	for field in ["food","played","timer","volume","text_speed"]:
		if not (value[field] is float or value[field] is int): return false
		if not is_finite(float(value[field])) or float(value[field]) < 0: return false
	if value.food <= 0 or value.food > 100 or value.volume > 1: return false
	for field in ["xp","frontier","selected","run","settled","auto_runs"]:
		if not whole_number(value[field]): return false
	if value.frontier > nodes.size() or value.selected >= nodes.size() or value.settled > value.run: return false
	if value.selected > value.frontier or value.text_speed > 1: return false
	if value.focus not in Catalog.SKILLS or value.room not in Catalog.ROOM_NAMES: return false
	if not value.skills is Dictionary: return false
	for skill in Catalog.SKILLS:
		if not value.skills.has(skill) or not whole_number(value.skills[skill],6): return false
	for key in ["seen","failures","routes","memories","result"]:
		if not value[key] is Dictionary: return false
	for key in ["observed","cleared"]:
		if not value[key] is Array: return false
	for idx in value.cleared:
		if not idx is String or idx not in valid_ids(): return false
	if value.cleared.size() != int(value.frontier): return false
	for i in int(value.frontier):
		if not value.cleared.has(str(i)): return false
	for key in ["saved_at","notice"]:
		if not value[key] is String: return false
	for key in ["auto","chain","intro","ending_seen","motion","fullscreen"]:
		if not value[key] is bool: return false
	for key in value.seen:
		if key not in valid_ids() or not value.seen[key] is Array: return false
		for point in value.seen[key]:
			if not point is String or point not in ["0","1","2"]: return false
	for point in value.observed:
		if not point is String or point not in ["0","1","2"]: return false
	for key in value.failures:
		if key not in valid_ids() or value.failures[key] not in Catalog.SKILLS: return false
	for key in value.routes:
		if key not in value.cleared or not value.routes[key] is Array: return false
		for route in value.routes[key]:
			if route not in Catalog.SKILLS: return false
	for key in value.memories:
		if key not in valid_ids() or not value.memories[key] is Dictionary: return false
		var memory: Dictionary = value.memories[key]
		if not memory.get("won") is bool or not whole_number(memory.get("visits")) or memory.visits < 1: return false
		if memory.get("route") not in ["","perception","combat","survival"]: return false
		if memory.won and (memory.route == "" or key not in value.cleared): return false
		if not memory.won and not value.failures.has(key): return false
	for key in value.cleared:
		if not value.memories.has(key) or not value.memories[key].won: return false
	if not value.result.is_empty():
		var result: Dictionary = value.result
		if not whole_number(result.get("stage"),nodes.size()-1) or not whole_number(result.get("xp"),9): return false
		for key in ["won","first","breakthrough"]:
			if not result.get(key) is bool: return false
		if result.get("skill") not in Catalog.SKILLS: return false
		for key in ["text","hint"]:
			if not result.get(key) is String: return false
	if value.mode in ["RESULT","ENDING"] and value.result.is_empty(): return false
	if value.mode == "AUTO" and not value.cleared.has(str(int(value.selected))): return false
	if value.mode in ["EXPLORE","AUTO","WAIT"] and value.run <= value.settled: return false
	if value.mode == "ENDING" and value.frontier < nodes.size(): return false
	s = value.duplicate(true)
	# JSON numbers are floats. Canonical integer IDs must survive a restart.
	for field in ["version","xp","frontier","selected","run","settled","auto_runs"]: s[field]=int(s[field])
	for skill in Catalog.SKILLS: s.skills[skill]=int(s.skills[skill])
	for key in s.memories: s.memories[key].visits=int(s.memories[key].visits)
	if not s.result.is_empty():
		s.result.stage=int(s.result.stage)
		s.result.xp=int(s.result.xp)
	return true

func whole_number(value: Variant, maximum: int = 1000000000) -> bool:
	if not (value is int or value is float): return false
	return is_finite(float(value)) and value >= 0 and value <= maximum and value == int(value)

func valid_ids() -> Array:
	var result: Array = []
	for i in nodes.size(): result.append(str(i))
	return result

func current() -> Dictionary:
	return nodes[int(s.selected)]

func stat(skill: String) -> int:
	return 1 + int(s.skills.get(skill,0))

func select_node(index: int) -> bool:
	if s.mode != "HOME" or index < 0 or index >= nodes.size() or index > s.frontier: return false
	s.selected = index
	return true

func depart(automatic: bool = false) -> bool:
	if s.mode != "HOME" or s.food <= 5 or s.frontier >= nodes.size(): return false
	s.run += 1
	s.auto = automatic
	s.observed = []
	s.result = {}
	s.food -= 3.5
	s.room = "entry"
	s.timer = 0.0
	if automatic and not s.cleared.has(str(s.selected)):
		s.mode = "WAIT"
	else:
		s.mode = "AUTO" if automatic else "EXPLORE"
	return true

func take_control() -> bool:
	if s.mode not in ["WAIT","AUTO"]: return false
	s.mode = "EXPLORE"
	s.auto = false
	s.observed = s.seen.get(str(s.selected),[]).duplicate()
	return true

func observe(index: int) -> Dictionary:
	if s.mode != "EXPLORE" or index < 0 or index >= current().points.size(): return {}
	var key = str(s.selected)
	var mark = str(index)
	if not s.observed.has(mark): s.observed.append(mark)
	if not s.seen.has(key): s.seen[key] = []
	var first = not s.seen[key].has(mark)
	if first:
		s.seen[key].append(mark)
		s.xp += 1
	return {"text":current().points[index].text, "first":first, "label":current().points[index].label}

func required(skill: String) -> int:
	return int(current().requirements[skill])

func attempt(skill: String) -> Dictionary:
	if s.mode != "EXPLORE" or skill not in Catalog.SKILLS or s.observed.size() < 2 or s.timer < 2.0: return {}
	s.focus = skill
	return settle(skill)

func settle(skill: String) -> Dictionary:
	if s.run <= s.settled: return {}
	s.settled = s.run
	var key = str(s.selected)
	var won = stat(skill) >= required(skill)
	var first = not s.cleared.has(key)
	var reward = 0
	var breakthrough = false
	if won:
		reward = 7 if first else 3
		if first: s.cleared.append(key)
		s.frontier = maxi(s.frontier, int(s.selected)+1)
		if not s.routes.has(key): s.routes[key] = []
		breakthrough = not s.routes[key].has(skill)
		if breakthrough:
			s.routes[key].append(skill)
			reward += 2
	else:
		reward = 2 if not s.failures.has(key) else 0
		s.failures[key] = skill
	s.xp += reward
	if not s.memories.has(key): s.memories[key] = {"won":false,"route":"","visits":0}
	s.memories[key].visits += 1
	if won:
		s.memories[key].won = true
		s.memories[key].route = skill
	s.result = {"stage":s.selected,"won":won,"xp":reward,"first":first and won,"breakthrough":breakthrough,"skill":skill,
		"text":current().success[skill] if won else current().failure[skill],
		"hint":"" if won else "%s %d / %d：%s" % [Catalog.SKILLS[skill],stat(skill),required(skill),current().hint[skill]]}
	s.room = "entry"
	s.mode = "RESULT"
	s.timer = 0.0
	if won and s.frontier >= nodes.size(): s.mode = "ENDING"
	return s.result.duplicate(true)

func return_home() -> void:
	if s.mode != "RESULT": return
	s.mode = "HOME"
	if s.result.get("first",false): s.selected = mini(int(s.frontier),nodes.size()-1)
	s.timer = 0.0

func withdraw() -> bool:
	if s.mode not in ["EXPLORE","AUTO","WAIT"]: return false
	s.settled = s.run
	s.auto = false
	s.mode = "HOME"
	s.room = "entry"
	s.result = {}
	return true

func tick(delta: float) -> String:
	if not s.intro or s.mode in ["WAIT","RESULT","ENDING","GAMEOVER"]: return ""
	s.played += delta
	s.timer += delta
	s.food = maxf(0.0, s.food - delta * (0.026 if s.mode in ["EXPLORE","AUTO"] else 0.012))
	if s.food <= 0:
		s.mode = "GAMEOVER"
		s.auto = false
		return "gameover"
	if s.mode == "AUTO" and s.timer >= 15.0:
		settle(s.focus)
		s.auto_runs += 1
		return "result"
	if s.mode == "HOME" and s.auto and s.timer >= 3:
		if s.food <= 15:
			s.auto = false
			s.notice = "补给偏低，重复探索已停止。"
			return "low"
		depart(true)
		return "depart"
	return ""

func advance_auto() -> void:
	if s.mode != "RESULT" or not s.auto: return
	var won: bool = s.result.get("won",false)
	if not won:
		s.auto = false
		return
	var index: int = s.selected
	return_home()
	if s.chain:
		s.selected = mini(index+1,nodes.size()-1)
		if s.selected <= s.frontier and not s.cleared.has(str(s.selected)):
			depart(true)

func upgrade(skill: String) -> bool:
	if s.mode not in ["HOME","RESULT","WAIT"] or skill not in Catalog.SKILLS: return false
	var level: int = s.skills[skill]
	if level >= Catalog.COSTS.size() or s.xp < Catalog.COSTS[level]: return false
	s.xp -= Catalog.COSTS[level]
	s.skills[skill] += 1
	return true

func supply() -> bool:
	if s.mode not in ["HOME","RESULT","WAIT"] or s.xp < 3 or s.food > 65: return false
	s.xp -= 3
	s.food = minf(100,s.food+35)
	return true
