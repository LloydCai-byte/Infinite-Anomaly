extends "res://scripts/turnbased/model.gd"
const Save=preload("res://scripts/reboot/save_store.gd")
var persistence
var persistence_enabled=true
var last_error=""

func _init(seed_value:int=0)->void:
	super(seed_value)
	s["retired_materials"]=0;s["loot_log"]=[]

func restore(data:Dictionary)->bool:
	if not data.get("state") is Dictionary:return false
	var copy=data.duplicate(true);var state=copy.state
	if not state.get("materials") is int or state.materials<0:return false
	if not state.get("retired_materials",0) is int or state.get("retired_materials",0)<0:return false
	state["retired_materials"]=state.get("retired_materials",0)+state.materials;state.materials=0
	if not state.has("loot_log"):state["loot_log"]=[]
	if not state.loot_log is Array:return false
	for entry in state.loot_log:
		if not entry is Dictionary or not entry.get("id") is int or not entry.get("name") is String or not entry.get("quality") is int or not entry.get("enemy") is String:return false
	return super.restore(copy)

func salvage(id:int)->bool:
	var item=item_by_id(id)
	if item.is_empty() or item.get("locked",false) or owner(id)>=0:return false
	s.gold+=salvage_gold(item);s.inventory.erase(item);return true

func salvage_gold(item:Dictionary)->int:return 8+int(item.level)*2

func equipped_look(hero:int) -> int:
	if hero<0 or hero>=5:return -1
	var theme=-1
	for slot in G.SET_TYPES:
		var item=item_by_id(s.equipped[hero].get(slot,0))
		if item.is_empty():return -1
		var current=int(G.bases[item.base].get("set",-1))
		if current<0 or (theme>=0 and theme!=current):return -1
		theme=current
	return theme

func equipped_looks() -> Array:
	var result=[]
	for hero in range(5):result.append(equipped_look(hero))
	return result

# Archived manual choices remain readable in old saves; active appearance is derived.
func set_look(_hero:int,_theme:int) -> bool:return false

# Removed as a progression route, not merely hidden in the UI.
func forge(_theme:int)->Dictionary:return {}

func reward(enemy:Dictionary)->void:
	var count=b.loot.size()
	super.reward(enemy)
	for id in b.loot.slice(count):
		var item=item_by_id(id)
		item["origin"]={"type":"monster","enemy":enemy.name,"theme":b.theme,"scene":b.scene}
		s.loot_log.append({"id":id,"name":G.name_of(item),"quality":int(item.quality),"enemy":enemy.name})
		if s.loot_log.size()>40:s.loot_log.pop_front()
		if not b.has("drop_events"):b["drop_events"]=[]
		b.drop_events.append({"id":id,"enemy":enemy.id})

func open_profile(path:String="user://pixel-equipment.json")->void:
	persistence=Save.new(path)
	var data=persistence.load_primary()
	if data.is_empty() or not restore(data):
		data=persistence.load_backup()
		if not data.is_empty() and restore(data):return
		if persistence.exists():last_error="装备存档读取失败，已保留原文件。";persistence_enabled=false

func persist()->bool:
	if not persistence_enabled:return false
	if persistence==null:return true
	var ok=persistence.save(snapshot())
	last_error="" if ok else persistence.error
	return ok

func preview(id:int,hero:int,slot:String)->Dictionary:
	var item=item_by_id(id)
	if item.is_empty() or not G.can_equip(item,hero,slot):return {}
	var before=stats(hero);var saved=s.equipped.duplicate(true)
	equip(id,hero,slot);var after=stats(hero);s.equipped=saved
	var delta={}
	for key in G.AFFIX:delta[key]=after[key]-before[key]
	return {"before":before,"after":after,"delta":delta}
