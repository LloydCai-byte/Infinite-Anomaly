extends RefCounted
## All mutations go through this model and are committed as one save snapshot.
const VERSION = 1
var catalog: Array = []
var by_id: Dictionary = {}
var story: Dictionary = {}
var balance: Dictionary = {}
var samples: Dictionary = {}
var s: Dictionary = {}

func _init() -> void:
	catalog = read_json("catalog")
	story = read_json("floor")
	balance = read_json("balance")
	samples = read_json("samples")
	for entry in catalog:
		by_id[entry.id] = entry
	new_game()

func read_json(id: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/containment/" + id + ".json"))

func new_game() -> void:
	s = {"version":VERSION,"mode":"home","room":"entry","case_id":"M01","node":"landing","flags":{},"used":false,"resolved":false,"cards":{},"cases":{},"skills":{},"points":{},"inbox":{},"bag":{},"deaths":0,"runs":0,"completed_runs":0,"box_rounds":0,"claimed_rounds":0,"locked":false,"last_line":"她指了指门边的收容夹：先看清楚，再作决定。","muted":false,"show_hints":true,"music_on":true,"ambience_on":true,"music_volume":0.65,"sound_volume":0.7,"companion_time":0.0,"paused":false,"offline_on":true,"saved_at":Time.get_unix_time_from_system(),"false_ending":false,"true_ending":false,"ending_kind":"","idle":{"active":false,"case_id":"","elapsed":0.0,"settled":0,"next_round":1,"stop_after":false,"sample":0},"pomo":{"running":false,"phase":"focus","remaining":1500.0,"duration":1500,"completed":0},"journal":[]}
	for id in balance.skills:
		s.skills[id] = 1
	for i in range(6):
		s.points[str(i)] = 0
	for item in catalog:
		s.cases[item.id] = {"checkpoints":{},"visited":[],"knowledge":{},"edges":[]}

func current_case() -> Dictionary:
	return by_id[s.case_id]

func node() -> Dictionary:
	return story.nodes.get(s.node,story.nodes.landing)

func actions() -> Array:
	return node().get("spots",[]) if s.mode == "story" else []

func find_action(id: String) -> Dictionary:
	for action in actions():
		if action.id == id:
			return action
		for child in action.get("choices",[]):
			if child.id == id:
				return child
	return {}

func stat_id(action: Dictionary) -> String:
	return current_case().focus if action.get("stat","") == "$focus" else action.get("stat","")

func requirement(action: Dictionary) -> int:
	return int(current_case().threshold) if action.get("stat","") == "$focus" else int(action.get("threshold",0))

func available(action: Dictionary) -> bool:
	return not action.has("stat") or int(s.skills.get(stat_id(action),0)) >= requirement(action)

func change(line: String = "", scene: bool = false) -> Dictionary:
	if line != "":
		s.last_line = line
	return {"changed":true,"scene":scene,"cue":"click"}

func discover(id: String) -> void:
	s.flags[id] = true
	s.cases[s.case_id].knowledge[id] = true

func enter(id: String) -> void:
	var record: Dictionary = s.cases[s.case_id]
	var edge = s.node + ">" + id
	if s.mode == "story" and edge not in record.edges:
		record.edges.append(edge)
	s.node = id
	s.mode = "story"
	s.last_line = node().line
	if id not in record.visited:
		record.visited.append(id)
	if id != "threshold":
		record.checkpoints[id] = {"flags":s.flags.duplicate(true),"node":id,"used":false,"resolved":false}

func begin() -> Dictionary:
	if s.mode != "home" or s.idle.active or s.locked:
		return {}
	if s.cards.size() == catalog.size():
		return begin_ending()
	if s.cards.has(s.case_id):
		choose_case()
	s.flags = {}
	s.used = false
	s.resolved = false
	s.runs += 1
	enter(story.start)
	return change("",true)

func rewind_to(id: String) -> Dictionary:
	if s.mode not in ["story","dead","home"] or s.idle.active or s.locked or tier(s.case_id) == "shiny":
		return {}
	var record: Dictionary = s.cases[s.case_id]
	if not record.checkpoints.has(id):
		return {}
	var checkpoint: Dictionary = record.checkpoints[id]
	s.flags = checkpoint.flags.duplicate(true)
	s.used = false
	s.resolved = false
	s.runs += 1
	enter(id)
	return change("",true)

func fail(line: String) -> Dictionary:
	s.mode = "dead"
	s.deaths += 1
	return change(line,true)

func verified() -> bool:
	return s.flags.has("connection") and (s.flags.has("rule") or s.flags.has("echo") or s.flags.has("trace"))

func contain(target: String) -> Dictionary:
	if s.mode != "story" or s.node != "inspect" or s.used or not verified():
		return {}
	var known = false
	for judgment in story.judgments:
		if judgment.id == target:
			known = true
	if not known:
		return {}
	s.used = true
	if target != "boundary":
		return fail("收容夹合上了，却没有封住那道接缝。楼梯从身后折回来，你失去了退路。\n这次收容机会已用尽。可以回到已到达的时间点。")
	s.resolved = true
	enter("threshold")
	return change("",true)

func finish_case() -> Dictionary:
	if not s.resolved or not s.used or s.node != "threshold":
		return {}
	var first = not s.cards.has(s.case_id)
	if first:
		s.cards[s.case_id] = {"progress":1,"samples":[],"first_at":int(Time.get_unix_time_from_system())}
		add_item(s.inbox,current_case().item,3)
		s.journal.append("已收容：" + current_case().name)
		s.completed_runs += 1
	s.mode = "reward"
	s.room = "entry"
	return change("门开了。她在家里。墙上的「%s」亮了起来。" % current_case().name if first else "她看见你回来，往旁边让了让。收容记录已经保留。",true)

func choose_case() -> void:
	var options: Array = []
	for entry in catalog:
		if not s.cards.has(entry.id) and entry.id != s.case_id:
			options.append(entry.id)
	if not options.is_empty():
		s.case_id = options.pick_random()
	elif not s.cards.has(s.case_id):
		return
	else:
		for entry in catalog:
			if not s.cards.has(entry.id):
				s.case_id = entry.id
				break
	s.node = story.start
	s.flags = {}
	s.used = false
	s.resolved = false

func act(id: String) -> Dictionary:
	if id.begins_with("rewind:"):
		return rewind_to(id.trim_prefix("rewind:"))
	if id.begins_with("contain:"):
		return contain(id.trim_prefix("contain:"))
	if id.begins_with("auto:"):
		return start_auto(id.trim_prefix("auto:"))
	if id.begins_with("replay:") and s.mode == "home" and not s.idle.active:
		var cid = id.trim_prefix("replay:")
		if not s.cards.has(cid) or tier(cid) == "shiny":
			return {}
		s.case_id = cid
		s.flags = {}
		s.used = false
		s.resolved = false
		s.runs += 1
		enter(story.start)
		return change("",true)
	if id == "depart":
		return begin()
	if id == "wake" and s.mode == "dead":
		s.mode = "home"
		s.room = "entry"
		return change("你又回到了家。她放下手里的东西：先缓一会儿，我们再想想。",true)
	if id == "put_away" and s.mode == "reward":
		s.mode = "home"
		return change("收容记录留在墙上。点击它，可以继续处理同类异常。",true)
	if id == "ending_home" and s.mode == "ending":
		s.mode = "home"
		s.room = "entry"
		return change("故事留在记录里。你仍可以继续完成收容。",true)
	if s.mode == "home":
		return home_action(id)
	if s.mode != "story":
		return {}
	var action = find_action(id)
	if action.is_empty() or not available(action) or action.has("choices"):
		return {}
	if action.get("containment",false):
		return {}
	if action.get("verify",false) and not (s.flags.has("rule") or s.flags.has("echo") or s.flags.has("trace")):
		return change("现在只有猜测。先调查纸背、脚步的来源，或者墙角的痕迹。")
	if action.has("evidence"):
		discover(action.evidence)
	if action.has("death"):
		return fail(action.death)
	if action.get("leave",false):
		s.mode = "home"
		s.room = "entry"
		return change("你暂时退回家里。下次可以从已到达的时间点继续。",true)
	if action.get("complete",false):
		return finish_case()
	if action.has("next"):
		enter(action.next)
		return change("",true)
	return change(action.get("text","你记住了这个细节。"))

func home_action(id: String) -> Dictionary:
	if id.begins_with("room_"):
		var room = id.trim_prefix("room_")
		if room not in room_ids():
			return {}
		s.room = room
		return change("屋里很安静。",true)
	if id.begins_with("upgrade:"):
		return upgrade(id.trim_prefix("upgrade:"))
	if id.begins_with("decompose:"):
		var args = id.split(":")
		if args.size() != 3 or not args[2].is_valid_int():
			return {}
		return decompose(args[1],int(args[2]))
	match id:
		"lock":
			if s.idle.active:
				return {}
			s.locked = not s.locked
			if not s.locked:
				choose_case()
			return change("门已反锁。再解锁，就会通向另一个未收容的异常。" if s.locked else "门锁咔哒一声。门外的声音变了。",true)
		"peek":
			if not s.idle.active:
				return {}
			s.room = "peephole"
			return change("",true)
		"recall":
			if not s.idle.active or s.idle.stop_after:
				return {}
			s.idle.stop_after = true
			return change("这一趟结束后，他就回家。")
		"claim":
			if s.inbox.is_empty() and s.box_rounds == 0:
				return {}
			for item in s.inbox:
				add_item(s.bag,item,s.inbox[item])
			s.inbox.clear()
			s.claimed_rounds += s.box_rounds
			s.box_rounds = 0
			return change("收货箱清空了。物品已放进工作台旁的背包。")
		"decompose_all":
			if s.bag.is_empty():
				return {}
			for item in s.bag.keys():
				decompose(item,int(s.bag[item]))
			return change("已按配方分解全部物品。")
		"music": s.music_on = not s.music_on
		"ambience": s.ambience_on = not s.ambience_on
		"pomo_toggle": s.pomo.running = not s.pomo.running
		"pomo_reset":
			s.pomo.running = false
			s.pomo.phase = "focus"
			s.pomo.remaining = float(s.pomo.duration)
		"pomo_5", "pomo_25", "pomo_50":
			s.pomo.duration = {"pomo_5":300,"pomo_25":1500,"pomo_50":3000}[id]
			s.pomo.phase = "focus"
			s.pomo.remaining = float(s.pomo.duration)
			s.pomo.running = false
		"talk": return change(companion_hint())
		_: return {}
	return change()

func room_ids() -> Array:
	return ["entry","entry_wall","hall","hall_table","bedroom","desk","kitchen","kitchen_table","bathroom","bathroom_laundry","balcony","balcony_sky"]

func companion_room() -> String:
	return ["bedroom","kitchen","bathroom_laundry","balcony_sky","hall_table"][int(s.companion_time / 45.0) % 5]

func companion_hint() -> String:
	if s.true_ending:
		return "你可以再坐一会儿。我们留下的这些记录，不会消失。"
	if s.cards.size() == 30:
		return "门外有了新的动静。墙上还有没完成的记录，我们也可以再看看。"
	if s.inbox.size() > 0:
		return "箱子里有新东西。收好以后，放到工作台上试试。"
	var knowledge: Dictionary = s.cases[s.case_id].knowledge
	if knowledge.has("connection"):
		return "你已经知道哪里连错了。把收容夹留给那个位置，别被旁边的人分散注意。"
	if knowledge.has("rule"):
		return "纸上的话是一条线索。再试试声音从哪里传回来，确认它说的是不是事实。"
	if knowledge.has("witness"):
		return "如果他没有动，那重复出现的，也许是你走的那段路。"
	return "不用急着收容。先记住你看见了什么，再看看它们能不能互相对上。"

func add_item(target: Dictionary, id: String, count: int) -> void:
	if count > 0:
		target[id] = int(target.get(id,0)) + count

func decompose(item: String, count: int) -> Dictionary:
	if not balance.items.has(item) or count <= 0 or int(s.bag.get(item,0)) < count:
		return {}
	var recipe: Dictionary = balance.items[item].recipe
	for point in recipe:
		s.points[point] += int(recipe[point]) * count
	s.bag[item] -= count
	if s.bag[item] == 0:
		s.bag.erase(item)
	return change("分解完成，能力点已经收好。")

func cost(id: String) -> Dictionary:
	if not balance.skills.has(id):
		return {}
	var spec: Dictionary = balance.skills[id]
	return {str(int(spec.primary)):int(s.skills[id])*2,str(int(spec.secondary)):int(ceil(s.skills[id]/2.0))}

func can_upgrade(id: String) -> bool:
	if not balance.skills.has(id) or s.skills[id] >= balance.skills[id].cap:
		return false
	for point in cost(id):
		if s.points[point] < cost(id)[point]:
			return false
	return true

func upgrade(id: String) -> Dictionary:
	if not can_upgrade(id):
		return {}
	for point in cost(id):
		s.points[point] -= cost(id)[point]
	s.skills[id] += 1
	return change("%s提升到 %d。对应的行动路线已更新。" % [balance.skills[id].name,s.skills[id]])

func tier(id: String) -> String:
	if not s.cards.has(id):
		return "locked"
	var progress = int(s.cards[id].progress)
	if progress >= int(by_id[id].sample_total):
		return "shiny"
	if progress >= int(ceil(by_id[id].sample_total / 2.0)):
		return "gold"
	return "normal"

func counts() -> Dictionary:
	var result = {"owned":s.cards.size(),"gold":0,"shiny":0}
	for id in s.cards:
		if tier(id) in ["gold","shiny"]:
			result.gold += 1
		if tier(id) == "shiny":
			result.shiny += 1
	return result

func round_seconds() -> float:
	return float(by_id.get(s.idle.case_id,current_case()).round_seconds)

func start_auto(id: String) -> Dictionary:
	if s.mode != "home" or s.idle.active or not s.cards.has(id) or tier(id) == "shiny" or s.locked:
		return {}
	s.idle.active = true
	s.idle.case_id = id
	s.idle.elapsed = 0.0
	s.idle.stop_after = false
	s.idle.sample = int(s.cards[id].progress)
	s.room = "entry"
	return change("他带上收容夹出门了。每一趟的记录与物品会直接送回家。",true)

func idle_node_id() -> String:
	var sequence: Array = story.idle_sequence
	return sequence[mini(sequence.size()-1,int(s.idle.elapsed / (round_seconds()/sequence.size())))]

func sample_description() -> String:
	var n = int(s.idle.sample)
	return "%s · 样本 %02d\n%s，%s。\n%s。" % [by_id.get(s.idle.case_id,current_case()).name,n+1,samples.locations[n%4],samples.conditions[(n/4)%6],samples.methods[(n/6)%4]]

func settle_round(round_id: int) -> bool:
	if not s.idle.active or round_id != int(s.idle.next_round) or round_id <= int(s.idle.settled):
		return false
	var id: String = s.idle.case_id
	if tier(id) == "shiny":
		return false
	var before = tier(id)
	var card: Dictionary = s.cards[id]
	var sample_id = int(s.idle.sample)
	if sample_id in card.samples:
		return false
	card.samples.append(sample_id)
	card.progress = mini(int(by_id[id].sample_total),int(card.progress)+1)
	add_item(s.inbox,by_id[id].item,1 if before == "gold" else 3)
	add_item(s.inbox,"item_%d" % ((int(by_id[id].index)-1)%6),1 if before == "normal" else 0)
	s.box_rounds += 1
	s.idle.settled = round_id
	s.idle.next_round = round_id + 1
	s.idle.sample = int(card.progress)
	return true

func stop_idle() -> void:
	s.idle.active = false
	s.idle.elapsed = 0.0
	s.idle.stop_after = false
	if s.room == "peephole":
		s.room = "entry"

func advance(seconds: float) -> Dictionary:
	var result = {"rounds":0,"bell":false,"returned":false,"shiny":false}
	if not is_finite(seconds) or seconds <= 0 or seconds > 86400 or s.paused:
		return result
	if s.mode == "home":
		s.companion_time = fmod(s.companion_time+seconds,225.0)
	if s.idle.active:
		s.idle.elapsed += seconds
		while s.idle.active and s.idle.elapsed >= round_seconds():
			s.idle.elapsed -= round_seconds()
			if not settle_round(int(s.idle.next_round)):
				stop_idle()
				result.returned = true
				break
			result.rounds += 1
			if tier(s.idle.case_id) == "shiny" or s.idle.stop_after:
				result.shiny = tier(s.idle.case_id) == "shiny"
				stop_idle()
				result.returned = true
				s.last_line = "这一类的记录完整了。她把这张闪光卡的入口合上，等你去看看其他异常。" if result.shiny else "门响了。他回来了，东西都在箱子里。"
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

func catch_up(now: float) -> Dictionary:
	var seconds = clampf(now - float(s.saved_at),0,float(balance.offline_cap_seconds))
	s.saved_at = now
	if not s.offline_on or s.paused:
		return {"rounds":0,"bell":false,"returned":false,"shiny":false}
	# Pomodoro measures deliberate active use; offline time only advances collection.
	var timer_running: bool = s.pomo.running
	s.pomo.running = false
	var result = advance(seconds)
	s.pomo.running = timer_running
	return result

func begin_ending() -> Dictionary:
	var total = counts()
	s.mode = "ending"
	s.room = "entry"
	if total.gold < 30:
		s.ending_kind = "blocked"
	elif total.shiny < 30:
		s.ending_kind = "false"
		s.false_ending = true
	else:
		s.ending_kind = "true"
		s.true_ending = true
	return change("",true)

func export_state() -> Dictionary:
	return s.duplicate(true)

func integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and value >= low and value <= high

func real_number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= low and value <= high

func flags_valid(flags: Variant) -> bool:
	if not flags is Dictionary:
		return false
	for key in flags:
		if not story.evidence.has(key) or flags[key] != true:
			return false
	return true

func restore(value: Dictionary) -> bool:
	# Validate before replacing live state. Invalid primary can fall back to backup.
	for field in s:
		if not value.has(field):
			return false
	if value.version != VERSION or value.mode not in ["home","story","dead","reward","ending"] or value.room not in room_ids()+["peephole"] or not by_id.has(value.case_id) or not story.nodes.has(value.node):
		return false
	for field in ["used","resolved","locked","muted","show_hints","music_on","ambience_on","paused","offline_on","false_ending","true_ending"]:
		if not value[field] is bool:
			return false
	for field in ["cards","cases","skills","points","inbox","bag","idle","pomo"]:
		if not value[field] is Dictionary:
			return false
	for field in ["deaths","runs","completed_runs","box_rounds","claimed_rounds"]:
		if not integer(value[field],0,100000000):
			return false
	if not flags_valid(value.flags) or not value.last_line is String or value.last_line.length() > 2000 or not value.journal is Array or value.journal.size() > 100 or value.ending_kind not in ["","blocked","false","true"]:
		return false
	for id in balance.skills:
		if not integer(value.skills.get(id),1,int(balance.skills[id].cap)):
			return false
	for point in s.points:
		if not integer(value.points.get(point),0,1000000000):
			return false
	for bag in [value.inbox,value.bag]:
		for id in bag:
			if not balance.items.has(id) or not integer(bag[id],1,1000000000):
				return false
	for id in value.cards:
		if not by_id.has(id) or not value.cards[id] is Dictionary:
			return false
		var card: Dictionary = value.cards[id]
		if not integer(card.get("progress"),1,int(by_id[id].sample_total)) or not card.get("samples") is Array or not integer(card.get("first_at"),0,9999999999):
			return false
		if card.samples.size() != int(card.progress)-1:
			return false
		var seen: Dictionary = {}
		for sample in card.samples:
			if not integer(sample,1,int(card.progress)-1) or seen.has(int(sample)):
				return false
			seen[int(sample)] = true
	if value.cases.size() != catalog.size():
		return false
	for id in value.cases:
		if not by_id.has(id) or not value.cases[id] is Dictionary:
			return false
		var record: Dictionary = value.cases[id]
		if not record.get("checkpoints") is Dictionary or not record.get("visited") is Array or not record.get("edges") is Array or not flags_valid(record.get("knowledge")):
			return false
		for visited in record.visited:
			if not visited is String or not story.nodes.has(visited):
				return false
		for edge in record.edges:
			if not edge is String or edge.split(">").size() != 2:
				return false
			for endpoint in edge.split(">"):
				if not story.nodes.has(endpoint):
					return false
		for key in record.checkpoints:
			var cp = record.checkpoints[key]
			if key not in record.visited or key == "threshold" or not cp is Dictionary or cp.get("node") != key or not flags_valid(cp.get("flags")) or cp.get("used") != false or cp.get("resolved") != false:
				return false
	var task: Dictionary = value.idle
	for field in ["active","stop_after"]:
		if not task.get(field) is bool:
			return false
	if not integer(task.get("settled"),0,100000000) or not integer(task.get("next_round"),1,100000001) or task.next_round != task.settled+1 or not integer(task.get("sample"),0,1000000):
		return false
	if task.get("case_id") != "" and not by_id.has(task.get("case_id")):
		return false
	var duration = float(by_id.get(task.get("case_id"),by_id[value.case_id]).round_seconds)
	if not real_number(task.get("elapsed"),0,duration) or task.elapsed >= duration or value.box_rounds + value.claimed_rounds != task.settled:
		return false
	if task.active and (value.mode != "home" or not value.cards.has(task.case_id) or value.cards[task.case_id].progress >= by_id[task.case_id].sample_total or int(task.sample) != int(value.cards[task.case_id].progress) or value.locked):
		return false
	if not task.active and (task.elapsed != 0 or task.stop_after or value.room == "peephole"):
		return false
	if value.mode == "reward" and (not value.resolved or not value.cards.has(value.case_id)):
		return false
	if value.resolved and (not value.used or value.node != "threshold"):
		return false
	if value.completed_runs != value.cards.size():
		return false
	for key in ["music_volume","sound_volume"]:
		if not real_number(value[key],0,1):
			return false
	if not real_number(value.companion_time,0,225) or value.companion_time >= 225 or not real_number(value.saved_at,0,9999999999):
		return false
	var timer: Dictionary = value.pomo
	if not timer.get("running") is bool or timer.get("phase") not in ["focus","break"] or not integer(timer.get("duration"),300,3000):
		return false
	if int(timer.duration) not in [300,1500,3000] or not integer(timer.get("completed"),0,100000000) or not real_number(timer.get("remaining"),0,timer.duration if timer.phase == "focus" else 300) or timer.remaining <= 0:
		return false
	s = value.duplicate(true)
	# JSON numbers are floats in Godot. Restore integer domains before using arrays,
	# membership checks or serializing the next transaction.
	for key in ["version","deaths","runs","completed_runs","box_rounds","claimed_rounds"]:
		s[key] = int(s[key])
	for field in ["skills","points","inbox","bag"]:
		for key in s[field]: s[field][key] = int(s[field][key])
	for key in ["next_round","sample","settled"]: s.idle[key] = int(s.idle[key])
	for key in ["completed","duration"]: s.pomo[key] = int(s.pomo[key])
	for id in s.cards:
		s.cards[id].progress = int(s.cards[id].progress)
		s.cards[id].first_at = int(s.cards[id].first_at)
		for i in range(s.cards[id].samples.size()):
			s.cards[id].samples[i] = int(s.cards[id].samples[i])
	return true
