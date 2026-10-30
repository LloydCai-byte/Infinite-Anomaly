extends RefCounted

static func initial()->Dictionary:
	return {"schema":1,"auto_max_quality":-1,"auto_count":0,"auto_gold":0}

static func valid(value:Variant)->bool:
	if not value is Dictionary or value.get("schema")!=1:return false
	for key in ["auto_max_quality","auto_count","auto_gold"]:
		if not value.get(key) is int:return false
	return value.auto_max_quality>=-1 and value.auto_max_quality<=5 and value.auto_count>=0 and value.auto_gold>=0

static func plan(gear,quality:int,quantity:int=-1)->Dictionary:
	var result={"ids":[],"gold":0}
	if quality<0 or quality>5 or quantity==0:return result
	var worn={}
	for slots in gear.s.equipped:
		for id in slots.values():worn[int(id)]=true
	# Oldest matching unequipped items first; every quality is selected explicitly.
	var candidates=gear.s.inventory.filter(func(item):return item.quality==quality and not item.get("locked",false) and not worn.has(item.id))
	candidates.sort_custom(func(a,b):return a.id<b.id)
	for item in candidates:
		if quantity>=0 and result.ids.size()>=quantity:break
		result.ids.append(item.id);result.gold+=gear.salvage_gold(item)
	return result

static func remove(gear,ids:Array)->int:
	var chosen={};var worn={};var gold=0;var keep=[]
	for id in ids:chosen[int(id)]=true
	for slots in gear.s.equipped:
		for id in slots.values():worn[int(id)]=true
	for item in gear.s.inventory:
		if chosen.has(item.id) and not item.get("locked",false) and not worn.has(item.id):gold+=gear.salvage_gold(item)
		else:keep.append(item)
	gear.s.inventory=keep;gear.s.gold+=gold
	gear.item_index.clear();gear.indexed_items=0
	return gold
