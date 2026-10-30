extends SceneTree
const Gear=preload("res://scripts/pixel_home/gear.gd")
var checks=[]
func check(ok:bool,label:String)->void:
	checks.append({"pass":ok,"name":label})
	if not ok:push_error(label)
func _initialize()->void:
	var g=Gear.new(631);var folder="user://confirmed-salvage-%d/"%Time.get_ticks_usec();DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder));g.open_profile(folder+"save.json")
	for i in range(8):g.award(20,0,2)
	var plan=g.salvage_plan(2,3);var before=g.snapshot()
	check(g.salvage_selection(plan.ids,plan.gold+1).count==0 and g.snapshot()==before,"changed quoted value cannot salvage or pay")
	check(g.salvage_selection([plan.ids[0],plan.ids[0]],plan.gold).count==0 and g.snapshot()==before,"duplicate IDs rejected without mutation")
	g.item_by_id(plan.ids[0]).locked=true;var locked=g.snapshot()
	check(g.salvage_selection(plan.ids,plan.gold).count==0 and g.snapshot()==locked,"newly locked item cancels entire confirmed batch")
	g.item_by_id(plan.ids[0]).locked=false
	var refreshed=g.salvage_plan(2,3);before=g.snapshot();DirAccess.make_dir_recursive_absolute(g.persistence.path+".tmp")
	check(g.salvage_selection(refreshed.ids,refreshed.gold).count==0 and g.snapshot()==before,"save failure restores every confirmed item and coin")
	DirAccess.remove_absolute(g.persistence.path+".tmp")
	var count=g.s.inventory.size();var gold=g.s.gold;var result=g.salvage_selection(refreshed.ids,refreshed.gold)
	check(result.count==3 and g.s.inventory.size()==count-3 and g.s.gold==gold+refreshed.gold,"three confirmed identities removed with exact quoted payout")
	var after=g.snapshot();check(g.salvage_selection(refreshed.ids,refreshed.gold).count==0 and g.snapshot()==after,"double confirmation cannot credit again")
	var reload=Gear.new(1);reload.open_profile(g.persistence.path);check(reload.snapshot()==g.snapshot(),"confirmed salvage survives reload exactly")
	var file=FileAccess.open("user://portal-polish-salvage-report.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks},"\t"));file.close()
	print("CONFIRMED_SALVAGE ",checks.size()," checks");quit(1 if checks.any(func(row):return not row.pass) else 0)
