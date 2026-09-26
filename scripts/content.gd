extends RefCounted
## Data is authoritative. Display names are never save keys.

var data: Dictionary = {}

func _init() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/content.json"))
	if parsed is Dictionary:
		data = parsed

func validate() -> Array[String]:
	var errors: Array[String] = []
	for section in ["dungeons", "stages", "farms", "pools", "cards", "collections", "upgrades", "comics"]:
		if not data.has(section):
			errors.append("Missing content section: " + section)
	if not errors.is_empty():
		return errors
	for id in data.stages:
		var stage: Dictionary = data.stages[id]
		if stage.duration <= 0 or not data.comics.has(stage.comic):
			errors.append("Invalid stage duration/comic: " + id)
		if not data.dungeons.has(stage.dungeon):
			errors.append("Unknown dungeon: " + id)
		if stage.card != "" and not data.cards.has(stage.card):
			errors.append("Unknown fixed card: " + id)
		for tag in stage.tags:
			if not data.tags.has(tag):
				errors.append("Unknown tag: " + id)
	for id in data.farms:
		var farm: Dictionary = data.farms[id]
		if farm.duration <= 0 or not data.stages.has(farm.unlock_stage) or not data.pools.has(farm.pool):
			errors.append("Invalid farm: " + id)
	for id in data.pools:
		var pool: Dictionary = data.pools[id]
		if pool.cards.is_empty() or pool.pity < 1:
			errors.append("Invalid pool: " + id)
		for card in pool.cards:
			if not data.cards.has(card):
				errors.append("Unknown pool card: " + card)
	for id in data.collections:
		var seen: Array = []
		for card in data.collections[id].cards:
			if not data.cards.has(card) or card in seen:
				errors.append("Invalid collection card: " + card)
			seen.append(card)
		if not data.comics.has(data.collections[id].ending):
			errors.append("Missing ending: " + id)
	for id in data.dungeons:
		var dungeon: Dictionary = data.dungeons[id]
		if not data.collections.has(dungeon.collection):
			errors.append("Missing collection: " + id)
		var tags: Array = ["anchor"]
		var reachable_credits: int = 0
		var reachable_energy: int = 0
		# A01 is the introductory path; B01 inherits its guaranteed abilities.
		if dungeon.unlock_stage != "":
			if not data.stages.has(dungeon.unlock_stage):
				errors.append("Missing unlock stage: " + id)
			tags.append("silence")
			reachable_credits = 60
			reachable_energy = 20
		for stage_id in dungeon.stages:
			if not data.stages.has(stage_id):
				errors.append("Missing stage: " + stage_id)
				continue
			var stage: Dictionary = data.stages[stage_id]
			for tag in stage.tags:
				if tag not in tags:
					errors.append("Ability dependency deadlock: " + stage_id)
			if stage.power > 2 or (stage.power == 2 and (reachable_credits < 60 or reachable_energy < 20)):
				errors.append("Unreachable power upgrade: " + stage_id)
			reachable_credits += int(stage.credits)
			reachable_energy += int(stage.energy)
			if stage.card != "" and data.cards.has(stage.card):
				var tag: String = data.cards[stage.card].tag
				if tag != "" and tag not in tags:
					tags.append(tag)
		var fixed: Array = ["A01_01"]
		for stage_id in dungeon.stages:
			if data.stages.has(stage_id):
				fixed.append(data.stages[stage_id].card)
		for farm_id in dungeon.farms:
			if not data.farms.has(farm_id):
				errors.append("Missing farm: " + farm_id)
		if not dungeon.farms.is_empty() and data.farms.has(dungeon.farms.back()):
			var end_pool: Array = data.pools[data.farms[dungeon.farms.back()].pool].cards
			for card in data.collections[dungeon.collection].cards:
				if card not in fixed and card not in end_pool:
					errors.append("Unreachable random card: " + card)
	for id in data.upgrades:
		if data.upgrades[id].credits < 0 or data.upgrades[id].energy < 0:
			errors.append("Negative upgrade cost: " + id)
	return errors
