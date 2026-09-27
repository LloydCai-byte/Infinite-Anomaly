extends RefCounted
## New design: authored first exploration plus an independent repeat-exploration clock.
const CONTENT = "res://data/continuity/floor.json"
const VERSION = 2
const IDLE_CONTENT = "res://data/continuity/idle.json"
var story: Dictionary = {}
var idle_config: Dictionary = {}
var s: Dictionary = {}
var error: String = ""

func _init() -> void:
	var raw = JSON.parse_string(FileAccess.get_file_as_string(CONTENT))
	if raw is Dictionary:
		story = raw
	idle_config = JSON.parse_string(FileAccess.get_file_as_string(IDLE_CONTENT))
	new_game()

func new_game() -> void:
	s = {"version":VERSION,"mode":"home","node":"landing","flags":{},"seen":[],"cards":{},"skills":{"nerve":1},"deaths":0,"runs":0,"completed_runs":0,"last_line":"门外传来了下楼的脚步声。","muted":false,"show_hints":false}
	add_home_defaults(s)

func add_home_defaults(state: Dictionary) -> void:
	state.room = "entry"
	state.idle = {"active":false,"elapsed":0.0,"next_round":1,"settled":0,"stop_after":false}
	state.inbox = {}
	state.bag = {}
	state.box_rounds = 0
	state.claimed_rounds = 0
	state.companion_time = 0.0
	state.music_on = true
	state.ambience_on = true
	state.pomo = {"running":false,"phase":"focus","remaining":1500.0,"duration":1500,"completed":0}

func node() -> Dictionary:
	return story.get("nodes",{}).get(s.node,{})

func actions() -> Array:
	return node().get("spots",[]) if s.mode == "story" else []

func find_action(id: String) -> Dictionary:
	for spot in actions():
		if spot.id == id:
			return spot

		for choice in spot.get("choices",[]):
			if choice.id == id:
				return choice
	return {}

func act(id: String) -> Dictionary:
	var home_result = home_action(id)
	if not home_result.is_empty():
		return home_result
	if id == "depart" and s.mode == "home" and not s.idle.active:
		s.room = "entry"
		s.runs += 1
		s.mode = "story"
		s.node = story.start
		s.flags = {}
		s.seen = [s.node]
		s.last_line = node().line
		return {"changed":true,"scene":true,"cue":"door"}
	if id == "wake" and s.mode == "dead":
		s.mode = "home"
		s.room = "entry"
		s.last_line = "你又在家里醒来。刚才发生的事，还记得。"
		return {"changed":true,"scene":true,"cue":"return"}
	if id == "put_away" and s.mode == "reward":
		s.mode = "home"
		s.last_line = "卡片放进了柜子。门还在那里。"
		return {"changed":true,"scene":true}
	if s.mode != "story":
		return {}
	var action = find_action(id)
	if action.is_empty():
		return {}
	if action.has("choices"):
		return {"choices":action.choices,"title":action.title}
	var result = {"changed":true,"cue":action.get("cue","click")}
	if action.has("flag"):
		s.flags[action.flag] = true
	if action.has("text"):
		s.last_line = action.text
		result.line = action.text
	if action.has("speech"):
		result.speech = action.speech
	var can_pass = not action.has("stat") or int(s.skills.get(action.get("stat",""),0)) >= int(action.get("threshold",0))
	if action.has("death") and (not action.has("stat") or not can_pass):
		s.mode = "dead"
		s.deaths += 1
		s.last_line = action.death
		result.scene = true
		result.cue = "return"
	elif action.get("complete",false):
		result.first_card = not s.cards.has(story.card.id)
		s.cards[story.card.id] = true
		s.completed_runs += 1
		s.mode = "reward"
		s.last_line = "你带回了一张卡。" if result.first_card else "还是那张卡。它留住了刚才的经历。"
		result.scene = true
	elif action.has("next") and can_pass:
		s.node = action.next
		if s.node not in s.seen:
			s.seen.append(s.node)
		s.last_line = node().line
		result.scene = true
	return result

func export_state() -> Dictionary:
	return s.duplicate(true)

func restore(value: Dictionary) -> bool:
	# Reject incompatible/corrupt states without partially mutating live state.
	if not valid_number(value.get("version"),1,VERSION) or value.get("mode") not in ["home","story","dead","reward"]:
		return false
	if not story.nodes.has(value.get("node","")):
		return false
	if not value.get("flags") is Dictionary or not value.get("cards") is Dictionary or not value.get("skills") is Dictionary or not value.get("seen") is Array:
		return false
	for key in ["deaths","runs","completed_runs"]:
		if not valid_number(value.get(key),0,1000000):
			return false
	if value.completed_runs > value.runs or value.deaths > value.runs:
		return false
	if not valid_number(value.skills.get("nerve"),1,999):
		return false
	if not value.get("muted") is bool or not value.get("show_hints") is bool:
		return false
	if not value.get("last_line") is String or value.last_line.length() > 500:
		return false
	for key in value.flags:
		if key not in ["window","number","asked","rule","heard"] or not value.flags[key] is bool or not value.flags[key]:
			return false
	for key in value.cards:
		if key != "stair" or not value.cards[key] is bool or not value.cards[key]:
			return false
	for entry in value.seen:
		if not entry is String or not story.nodes.has(entry):
			return false
	if value.mode == "reward" and not value.cards.has("stair"):
		return false
	if value.mode in ["story","dead","reward"] and value.runs == 0:
		return false
	var candidate = value.duplicate(true)
	if int(candidate.version) == 1:
		add_home_defaults(candidate)
		candidate.version = VERSION
	if not valid_home(candidate):
		return false
	s = candidate
	return true

func valid_number(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and value >= low and value <= high

func valid_real(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= low and value <= high

func valid_home(value: Dictionary) -> bool:
	if value.get("room") not in ["entry","bedroom","peephole"]:
		return false
	for key in ["idle","pomo","inbox","bag"]:
		if not value.get(key) is Dictionary:
			return false
	var task: Dictionary = value.idle
	if not task.get("active") is bool or not task.get("stop_after") is bool:
		return false
	if not valid_real(task.get("elapsed"),0,round_seconds()) or task.elapsed >= round_seconds():
		return false
	if not valid_number(task.get("settled"),0,100000000) or not valid_number(task.get("next_round"),1,100000001) or task.next_round != task.settled + 1:
		return false
	if task.active and (value.mode != "home" or not value.cards.has("stair")):
		return false
	if not task.active and (task.elapsed != 0 or task.stop_after or value.room == "peephole"):
		return false
	for key in ["box_rounds","claimed_rounds"]:
		if not valid_number(value.get(key),0,100000000):
			return false
	if value.box_rounds + value.claimed_rounds != task.settled:
		return false
	for key in ["inbox","bag"]:
		for item in value[key]:
			if not idle_config.items.has(item) or not valid_number(value[key][item],1,1000000000):
				return false
	if (value.box_rounds == 0) != value.inbox.is_empty():
		return false
	if not valid_real(value.get("companion_time"),0,40) or value.companion_time >= 40:
		return false
	if not value.get("music_on") is bool or not value.get("ambience_on") is bool:
		return false
	var timer: Dictionary = value.pomo
	if not timer.get("running") is bool or timer.get("phase") not in ["focus","break"] or not valid_number(timer.get("duration"),300,1500):
		return false
	if int(timer.duration) != 300 and int(timer.duration) != 1500:
		return false
	if not valid_number(timer.get("completed"),0,100000000) or not valid_real(timer.get("remaining"),0,timer.duration if timer.phase == "focus" else 300):
		return false
	return timer.remaining > 0

func home_action(id: String) -> Dictionary:
	if s.mode != "home":
		return {}
	var result = {"changed":true,"scene":false,"cue":"click"}
	match id:
		"room_entry", "room_bedroom":
			s.room = "entry" if id == "room_entry" else "bedroom"
			result.scene = true
			s.last_line = "她把书翻到了下一页。" if s.room == "bedroom" else "门关着，家里的灯还亮着。"
		"peek":
			if not s.idle.active:
				return {}
			s.room = "peephole"
			result.scene = true
		"start_auto":
			if not s.cards.has("stair") or s.idle.active:
				return {}
			s.idle.active = true
			s.idle.elapsed = 0.0
			s.idle.stop_after = false
			s.room = "entry"
			s.last_line = "他又走进了楼道。回来之前，可以在家里坐一会儿。"
			result.scene = true
			result.cue = "door"
		"recall":
			if not s.idle.active or s.idle.stop_after:
				return {}
			s.idle.stop_after = true
			s.last_line = "等这一趟结束，他就回来。"
		"claim":
			if s.inbox.is_empty():
				return {}
			for item in s.inbox:
				s.bag[item] = int(s.bag.get(item,0)) + int(s.inbox[item])
			s.inbox = {}
			s.claimed_rounds += s.box_rounds
			s.box_rounds = 0
			s.last_line = "东西收好了。他还可以继续探索。" if s.idle.active else "送回来的东西都收好了。"
			result.cue = "paper"
		"music":
			s.music_on = not s.music_on
		"ambience":
			s.ambience_on = not s.ambience_on
		"pomo_toggle":
			s.pomo.running = not s.pomo.running
		"pomo_reset":
			s.pomo.running = false
			s.pomo.phase = "focus"
			s.pomo.remaining = float(s.pomo.duration)
		"pomo_5", "pomo_25":
			s.pomo.duration = 300 if id == "pomo_5" else 1500
			s.pomo.phase = "focus"
			s.pomo.remaining = float(s.pomo.duration)
			s.pomo.running = false
		"talk":
			s.last_line = "箱子有动静了。先把东西收好吧。" if s.box_rounds > 0 else ("不用一直盯着门。他回来之前，我陪你坐一会儿。" if s.idle.active else "门还在。不过，你可以先歇一会儿。")
			result.speech = s.last_line
		_:
			return {}
	return result

func round_seconds() -> float:
	return float(idle_config.round_seconds)

func idle_node_id() -> String:
	var sequence: Array = idle_config.sequence
	var index = mini(sequence.size()-1,int(s.idle.elapsed / (round_seconds() / sequence.size())))
	return sequence[index]

func companion_pose() -> String:
	return "reading" if s.companion_time < 26 else "tea"

func settle_round(round_id: int) -> bool:
	# Reward and cursor advance together in the same saved snapshot; replays are ignored.
	if not s.idle.active or round_id != int(s.idle.next_round) or round_id <= int(s.idle.settled):
		return false
	for drop in idle_config.drops:
		if round_id % int(drop.every) == 0:
			s.inbox[drop.item] = int(s.inbox.get(drop.item,0)) + int(drop.count)
	s.box_rounds += 1
	s.idle.settled = round_id
	s.idle.next_round = round_id + 1
	return true

func advance(seconds: float) -> Dictionary:
	var result = {"rounds":0,"bell":false,"returned":false}
	if not is_finite(seconds) or seconds <= 0 or seconds > 86400:
		return result
	if s.mode == "home":
		s.companion_time = fmod(s.companion_time + seconds,40.0)
	if s.idle.active:
		s.idle.elapsed += seconds
		while s.idle.elapsed >= round_seconds() and s.idle.active:
			s.idle.elapsed -= round_seconds()
			if settle_round(int(s.idle.next_round)):
				result.rounds += 1
			if s.idle.stop_after:
				s.idle.active = false
				s.idle.stop_after = false
				s.idle.elapsed = 0.0
				if s.room == "peephole":
					s.room = "entry"
				s.last_line = "门响了一声。他回来了，东西已经在箱子里。"
				result.returned = true
	if s.pomo.running:
		s.pomo.remaining -= seconds
		while s.pomo.remaining <= 0:
			if s.pomo.phase == "focus":
				s.pomo.completed += 1
				s.pomo.phase = "break"
				s.pomo.remaining += 300.0
			else:
				s.pomo.phase = "focus"
				s.pomo.remaining += float(s.pomo.duration)
			result.bell = true
	return result
