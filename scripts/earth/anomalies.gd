extends RefCounted
static var entries: Dictionary={}

static func initialize() -> void:
	if not entries.is_empty():return
	var source=JSON.parse_string(FileAccess.get_file_as_string("res://assets/earth/anomalies/catalog.json"))
	for e in source.entries:entries[int(e.stage)]=e

static func has_stage(stage: int) -> bool:
	return stage in [301,302]

static func info(stage: int) -> Dictionary:
	initialize()
	return entries.get(stage,{})

static func mission(stage: int) -> Dictionary:
	var e=info(stage)
	return {"stage":stage,"chapter":1,"name":e.name,"bg":e.key,"enemy":e.key,"boss":e.enemies[4].name,"mechanic":"怪谈清剿","schedule":[5,5,5,5,5],"encounters":5,"count":5,"factor":1.0 if stage==301 else 1.15,"credits":270 if stage==301 else 305,"alloy":6,"cores":1,"reward_stage":4 if stage==301 else 5,"anomaly":e.key,"world_width":e.world_width}

static func encounter_x(stage: int,index: int) -> float:
	return info(stage).scenes[clampi(index,0,4)].encounter_x

static func background(stage: int) -> Texture2D:
	return load(info(stage).scenes[0].path)
