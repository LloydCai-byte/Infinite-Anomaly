extends RefCounted

const SKILLS = {"perception":"感知", "combat":"战斗", "survival":"生存"}
const COSTS = [6,10,18,24,30,36]
const CHAPTERS = ["第一章 · 楼层之外", "第二章 · 无人居住", "第三章 · 最后一名住户"]
const ROOM_NAMES = {"entry":"玄关", "hall":"过厅", "kitchen":"厨房", "bathroom":"浴室", "bedroom":"卧室", "desk":"书桌", "balcony":"阳台"}

static func read() -> Array:
	var value = JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign.json"))
	return value if value is Array else []

static func asset(group: String, id: String) -> String:
	return "res://assets/v3/%s/%s.png" % [group,id]
