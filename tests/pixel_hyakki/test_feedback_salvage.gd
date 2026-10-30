extends SceneTree
const Gear=preload("res://scripts/pixel_home/gear.gd")
const SalvagePanel=preload("res://scripts/pixel_home/salvage_ui.gd")
var checks=[]
func check(ok:bool,label:String)->void:
	checks.append({"pass":ok,"name":label})
	if not ok:push_error(label)
func _initialize()->void:
	var g=Gear.new(427);var folder="user://feedback-salvage-%d/"%Time.get_ticks_usec();DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder));g.open_profile(folder+"save.json")
	check(g.salvage_rules.auto_max_quality==-1,"auto salvage defaults off")
	var legacy=g.snapshot();legacy.erase("salvage_rules");check(g.restore(legacy) and g.salvage_rules.auto_max_quality==-1,"old saves default off")
	for quality in range(6):
		for i in range(5):g.award(20,0,quality)
	var locked=g.award(20,0,0);locked.locked=true
	var worn=[]
	for slots in g.s.equipped:
		for id in slots.values():worn.append(id)
	var plan=g.salvage_plan(0,2);var gold=g.s.gold;var n=g.s.inventory.size()
	check(plan.ids.size()==2 and locked.id not in plan.ids,"quantity and lock protection")
	check(plan.ids.all(func(id):return id not in worn),"all heroes equipped items protected")
	var result=g.salvage_batch(0,2)
	check(result.count==2 and g.s.inventory.size()==n-2 and g.s.gold==gold+plan.gold,"batch credits exact coins once")
	check(g.persistence.load_primary()==g.snapshot(),"batch saves atomically")
	var remaining=g.salvage_plan(0);result=g.salvage_batch(0)
	check(result.count==remaining.ids.size() and not g.item_by_id(locked.id).is_empty(),"one click handles all eligible quality and keeps locked")
	check(g.salvage_batch(0).count==0,"repeated one click does not pay twice")
	var snapshot=g.snapshot();DirAccess.make_dir_recursive_absolute(g.persistence.path+".tmp")
	var single=g.salvage_plan(1,1).ids[0]
	check(g.salvage_one(single).count==0 and g.snapshot()==snapshot,"failed single item save restores item and coins")
	check(g.salvage_batch(1).count==0 and g.snapshot()==snapshot,"failed batch save restores all equipment and coins")
	check(not g.set_auto_salvage(2) and g.snapshot()==snapshot,"failed setting save rolls back")
	DirAccess.remove_absolute(g.persistence.path+".tmp")
	check(g.salvage_one(single).count==1 and g.item_by_id(single).is_empty(),"single item uses atomic save")
	var old_ids=g.s.inventory.map(func(item):return item.id);check(g.set_auto_salvage(2),"save inclusive quality threshold")
	check(g.s.inventory.map(func(item):return item.id)==old_ids,"setting never processes preexisting bag")
	var new_ids=[]
	for quality in range(6):new_ids.append(g.award(20,0,quality).id)
	g.b={"loot":new_ids.duplicate(),"gold":0,"drop_events":new_ids.map(func(id):return {"id":id,"enemy":5})}
	gold=g.s.gold;g.salvage_new_drops(new_ids)
	check(new_ids.slice(0,3).all(func(id):return g.item_by_id(id).is_empty()),"normal magic rare inclusive auto threshold")
	check(new_ids.slice(3).all(func(id):return not g.item_by_id(id).is_empty()),"higher quality kept")
	check(old_ids.all(func(id):return not g.item_by_id(id).is_empty()),"existing inventory untouched by new loot rule")
	check(g.b.loot==new_ids.slice(3) and g.b.drop_events.size()==3,"no removed IDs reach loot renderer")
	check(g.s.gold==gold+g.b.auto_salvage_gold and g.salvage_rules.auto_count==3,"auto coins one credit")
	gold=g.s.gold;g.salvage_new_drops(new_ids);check(g.s.gold==gold,"replay removed drop IDs cannot pay again")
	g.b={};check(g.persist(),"auto receipt persisted")
	var reload=Gear.new(1);reload.open_profile(g.persistence.path);check(reload.snapshot()==g.snapshot(),"auto settings counters and inventory restore exactly")
	var bad=g.snapshot();bad.salvage_rules.auto_max_quality=6;check(not g.restore(bad),"invalid quality rejects save")
	var report={"checks":checks,"failures":checks.filter(func(c):return not c.pass)}
	var out=FileAccess.open("user://feedback-salvage-report.json",FileAccess.WRITE);out.store_string(JSON.stringify(report,"\t"));out.close()
	print("FEEDBACK_SALVAGE ",checks.size()," checks ",report.failures.size()," failures");quit(0 if report.failures.is_empty() else 1)
