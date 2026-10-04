extends RefCounted
## Isolated visual trial: no campaign currency, equipment, rewards or save writes.
const SCALE = 900.0 / 724.0
const LENGTH = 10858.0 * SCALE
const FINISH = LENGTH - 690.0
const DURATIONS = {
	"male-heavy": {"idle":1.0, "move":40.0/60, "attack":76.0/60, "hit":106.0/60, "fall":166.0/60},
	"pale-hair-katana": {"idle":1.0, "move":40.0/60, "attack":91.0/60, "hit":106.0/60, "fall":121.0/60},
	"bull-spider": {"idle":2.0, "move":55.0/60, "attack":86.0/60, "hit":66.0/60, "fall":211.0/60}
}
var units: Array = []
var events: Array = []
var elapsed = 0.0
var camera_x = 0.0
var ready_time = 1.2
var result = ""
var paused = false
var speed = 1.0
var invincible = false
var skipped = 0
var seen_states: Dictionary = {}
var seed_value = 20260929

func _init() -> void:
	restart()

func restart() -> void:
	units.clear()
	events.clear()
	seen_states.clear()
	elapsed = 0.0
	camera_x = 0.0
	ready_time = 1.2
	result = ""
	paused = false
	skipped = 0
	for i in range(4):
		var u = make_unit("male-heavy", 0, 490.0-i*87.0, [691.0,754.0,709.0,786.0][i], 650.0, 29.0, false)
		u.role = i
		u.height = [218.0,226.0,213.0,222.0][i]
		u.cooldown = i*0.23
		u.anim_time = i*0.18
		units.append(u)
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	var spots = [1420.0, 1780.0, 2850.0, 3250.0, 4230.0, 5100.0, 5720.0, 6760.0, 7520.0, 8550.0, 9430.0, 10650.0]
	for i in range(spots.size()):
		var bull = i in [5,10]
		var u = make_unit("bull-spider" if bull else "pale-hair-katana", 1, spots[i]+rng.randf_range(-130,130), rng.randf_range(702,764), 430.0 if bull else 185.0, 35.0 if bull else 19.0, false)
		u.anim_time = rng.randf_range(0,1)
		units.append(u)
	units.append(make_unit("bull-spider", 1, FINISH, 750.0, 1600.0, 47.0, true))

func make_unit(kind: String, side: int, x: float, y: float, hp: float, damage: float, boss: bool) -> Dictionary:
	return {"id":units.size(), "kind":kind, "side":side, "x":x, "y":y, "lane":y,
		"hp":hp, "max_hp":hp, "damage":damage, "boss":boss, "role":0,
		"height":310.0 if boss else (265.0 if kind=="bull-spider" else 222.0),
		"anim":"idle", "anim_time":0.0, "cooldown":0.0, "target":-1,
		"hit_sent":false, "flash":0.0, "removed":false, "awake":side==0,"move_distance":0.0}

func alive(side: int) -> Array:
	return units.filter(func(u): return u.side==side and u.hp>0 and not u.removed)

func remaining() -> int:
	return alive(1).size()

func duration(u: Dictionary, animation: String) -> float:
	return DURATIONS[u.kind][animation]

func animate(u: Dictionary, animation: String) -> void:
	if u.anim != animation:
		u.anim = animation
		u.anim_time = 0.0
	seen_states[u.kind+"/"+animation] = true

func nearest(u: Dictionary, candidates: Array) -> Dictionary:
	var target: Dictionary = {}
	var distance = INF
	for v in candidates:
		var d = absf(v.x-u.x) + absf(v.y-u.y)*0.5
		if d < distance:
			distance = d
			target = v
	return target

func tick(delta: float) -> void:
	if paused: return
	elapsed += delta
	for u in units:
		if u.removed: continue
		u.anim_time += delta
		u.flash = maxf(0.0, u.flash-delta)
		u.cooldown = maxf(0.0, u.cooldown-delta)
		seen_states[u.kind+"/"+u.anim] = true
	if result != "": return
	if ready_time > 0:
		ready_time -= delta
		return
	var allies = alive(0)
	var enemies = alive(1)
	if allies.is_empty():
		result = "defeat"
		return
	if enemies.is_empty():
		result = "victory"
		for u in allies: animate(u,"idle")
		return
	var lead = 0.0
	for u in allies: lead = maxf(lead,u.x)
	for u in units:
		if u.removed or u.hp<=0: continue
		if u.anim=="attack":
			var contact = 0.34 if u.kind=="male-heavy" else (0.60 if u.kind=="pale-hair-katana" else 0.47)
			if not u.hit_sent and u.anim_time>=contact:
				u.hit_sent = true
				var target = units[u.target] if u.target>=0 else {}
				if not target.is_empty() and target.hp>0 and not target.removed and absf(target.x-u.x)<245.0:
					hit(u,target)
			if u.anim_time>=duration(u,"attack"):
				animate(u,"hit" if u.get("pending_hit",false) else "idle")
				u.pending_hit = false
				u.cooldown = 0.18
			continue
		if u.anim=="hit":
			if u.anim_time>=duration(u,"hit"): animate(u,"idle")
			else: continue
		var candidates = alive(1-u.side)
		if candidates.is_empty(): continue
		var target = nearest(u,candidates)
		var dx: float = target.x-u.x
		u.facing = 1.0 if dx>=0 else -1.0
		if u.side==1 and not u.awake:
			u.awake = absf(dx)<620.0
			if not u.awake: continue
		var reach = 128.0 if u.kind!="bull-spider" else (194.0 if u.boss else 166.0)
		if u.side==0: reach = [120.0,154.0,193.0,232.0][u.role]
		if absf(dx)<=reach+8.0:
			if u.cooldown<=0:
				animate(u,"attack")
				u.target = target.id
				u.hit_sent = false
			continue
		animate(u,"move")
		var walk_speed = 238.0 if u.side==0 else (78.0 if u.kind=="bull-spider" else 128.0)
		if u.side==0 and dx>720.0: walk_speed *= 1.0+(lead-u.x)/1300.0
		var previous_x=float(u.x)
		u.x = move_toward(u.x,target.x-signf(dx)*reach,walk_speed*delta)
		u.move_distance += absf(u.x-previous_x)
		# Keep separate shallow lanes so reused teammates remain readable.
		var desired_y: float = u.lane
		if absf(dx)<570.0 and u.side==0:
			desired_y = [682.0,721.0,759.0,794.0][u.role]
		u.y = move_toward(u.y,desired_y,55.0*delta)
	var camera_target = clampf(lead-500.0,0.0,LENGTH-1600.0)
	camera_x = lerpf(camera_x,maxf(camera_x,camera_target),1.0-exp(-delta*5.0))

func hit(attacker: Dictionary, target: Dictionary) -> void:
	if target.side==0 and invincible:
		events.append({"type":"immune","x":target.x,"y":target.y-target.height*0.75,"value":0})
		return
	target.hp = maxf(0.0,target.hp-attacker.damage)
	target.flash = 0.08
	events.append({"type":"hit","x":target.x,"y":target.y-target.height*0.75,"value":int(attacker.damage),"side":target.side})
	if target.hp<=0:
		animate(target,"fall")
	elif target.anim=="attack":
		# Finish the strike, then show the recoil; don't repeatedly restart either clip.
		target.pending_hit = true
	elif target.anim not in ["attack","hit"]:
		animate(target,"hit")

func jump_to_boss() -> void:
	result = ""
	paused = false
	ready_time = 0.6
	events.clear()
	for u in units:
		if u.side==1 and not u.boss:
			if not u.removed and u.hp>0: skipped += 1
			u.removed = true
		elif u.side==0:
			u.hp = u.max_hp
			u.x = FINISH-680.0-u.role*83.0
			u.y = u.lane
			animate(u,"idle")
			u.cooldown = u.role*0.2
		else:
			u.hp = u.max_hp
			u.x = FINISH
			u.awake = false
			animate(u,"idle")
	camera_x = clampf(FINISH-1190.0,0,LENGTH-1600.0)
