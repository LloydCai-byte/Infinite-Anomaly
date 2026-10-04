extends SceneTree
const C=preload("res://scripts/earth/catalog.gd")
# Planning metadata only: does not create paid generation tasks or completed assets.
func _initialize() -> void:
	var items=[]
	var out="res://art/earth-production/integration-080/action-queue"
	DirAccess.make_dir_recursive_absolute(out)
	for p in range(C.PEOPLE.size()):
		var person=C.PEOPLE[p]
		for suit in C.SUITS:
			var id="%s-t%d"%[person.id,suit.tier]
			var spec={"source":"art/earth-production/motion/incoming/"+id+".mp4","output":"assets/earth/actors/%s/t%d"%[person.id,suit.tier],"cuts_reviewed":false,"stride_pixels":0,"canvas":[432,248],"pivot":[216,235],"native_height":224,"actions":{"idle":{"start":0,"end":0},"move":{"start":0,"end":0},"attack":{"start":0,"end":0},"hit":{"start":0,"end":0},"fall":{"start":0,"end":0}}}
			var file=FileAccess.open(out+"/"+id+"-import.json",FileAccess.WRITE);file.store_string(JSON.stringify(spec,"  "));file.close()
			items.append({"id":id,"person":person.name,"reference":"art/storyboards/opening-20261001-cel-final-v01/references/"+person.id+".png","suit":suit.name,"weapon":suit.weapons[p],"look":suit.look,"actions":["idle","move","attack","hit","fall"],"status":"待动作源视频；未创建付费任务","identity":"粉色发尾" if person.id=="fenfen" else "保留最新人设的脸、眼镜、体格、发型；换装只改变整套衣服与武器","import_spec":out.trim_prefix("res://")+"/"+id+"-import.json"})
	var file=FileAccess.open(out+"/queue.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"appearance_versions":15,"action_groups":75,"items":items,"payment_gate":"旧粉粉T1 12秒报价约2400积分，尚未获具体费用确认；资料需先更新为粉色发尾，再请求单条确认。","native_generated_assets":0},"  "));file.close()
	print("ACTION QUEUE: ",items.size()," suit versions, 75 action groups, no generation requests")
	quit()
