extends RefCounted
const C=preload("res://scripts/reboot/catalog.gd")
const W=preload("res://scripts/reboot/war_catalog.gd")
const Story=preload("res://scripts/reboot/story_catalog.gd")
const Art=preload("res://scripts/reboot/art.gd")
var u: RefCounted
var g: Control
var mission_page=0
var card_page=0
var room_group=0
var room_stream=0
var chosen_planet=0
var story_id=""
var story_index=0
var story_replay=false
var module_selected="reflect"
var log_page=0

func _init(ui: RefCounted) -> void:
	u=ui
	g=ui.g

func draw_page(id: String) -> void:
	match id:
		"modules": modules()
		"graduation": graduation()
		"handoff": handoff()
		"story": story()
		"journal": journal()
		"war_map": star_map()
		"war_rooms": rooms()
		"war_formation": formation()
		"war_tech": technology()
		"war_soldiers": soldiers()
		"war_cards": civilizations()
		"war_result": result()
		"war_retreat": retreat()
		"war_ledger": ledger()
		"war_history": historical()
		"war_ending": ending()

func missions() -> void:
	var m=g.model
	var d=C.mission(m.s.selected_mission)
	var p=u.modal("任务门  /  十项试验","不同任务有独立波次与敌人能力；查看情报，整备后出发。")
	u.image(p,Art.background(d.bg),Rect2(40,130,744,332))
	u.image(p,Art.frame(d.enemy,8),Rect2(558,235,206,214),true)
	u.text(p,d.id+"  "+d.name,Rect2(820,125,487,54),32)
	u.text(p,d.desc,Rect2(823,188,477,72),21,u.MUTED)
	u.text(p,"%d 波 · 参考战力 %d\n首领：%s"%[d.waves.size(),d.power,d.boss],Rect2(823,280,477,83),22)
	u.text(p,d.tip,Rect2(823,378,477,77),20,u.ACCENT)
	u.text(p,"奖励 %d 积分 / %d 合金\n解锁：%s"%[d.credits,d.alloy,d.reward],Rect2(823,471,477, seventy()),20,u.GOLD)
	for i in range(5):
		var def=C.MISSIONS[mission_page*5+i]
		u.button(p,"mission_"+def.id,def.id+"\n"+def.name,Rect2(40+i*149,476,139,76),func():m.s.selected_mission=def.id;g.render(),"","primary" if d.id==def.id else "neutral")
	u.button(p,"missions_prev","M01—05",Rect2(40,572,168,52),func():mission_page=0;g.render(),"back","primary" if mission_page==0 else "neutral")
	u.button(p,"missions_next","M06—10",Rect2(221,572,168,52),func():mission_page=1;g.render(),"play","primary" if mission_page==1 else "neutral")
	u.text(p,"%s · 已胜 %d 次\n队伍战力 %d"%[m.quality(d.id),m.s.wins[d.id],m.power()],Rect2(416,565,370,70),20,u.ACCENT)
	var why="小队出战中" if m.active() else ("先完成上一任务" if not m.unlocked(d.id) else ("训练尚未结束" if not m.s.training.is_empty() else ""))
	u.button(p,"prepare",why if why!="" else "准备出发",Rect2(990,577,315, sixty()),func():g.open("ready"),"door","primary",why!="")

func sixty() -> float: return 60.0
func seventy() -> float: return 70.0

func cards() -> void:
	var m=g.model
	var p=u.modal("异常档案  /  %d—%d"%[card_page*5+1,card_page*5+5],"每项 8 次胜利为金卡，25 次为钻石。十张金卡后可主动阅读毕业简报。")
	for i in range(5):
		var d=C.MISSIONS[card_page*5+i]
		var q=m.quality(d.id)
		var c=u.panel(p,Rect2(40+i*258,137,246,383),"card_diamond" if q=="钻石" else ("card_gold" if q=="金卡" else "card"))
		u.image(c,Art.background(d.bg),Rect2(10,11,226,126))
		var fig=u.image(c,Art.frame(d.enemy,8),Rect2(27,49,192,160),true)
		if m.s.wins[d.id]==0: fig.modulate=Color(.09,.12,.12,1)
		u.text(c,d.boss,Rect2(10,219,226,40),23,u.INK,HORIZONTAL_ALIGNMENT_CENTER)
		u.text(c,q+" · %d 胜"%m.s.wins[d.id],Rect2(10,268,226,35),20,u.GOLD,HORIZONTAL_ALIGNMENT_CENTER)
		u.bar(c,Rect2(20,309,206,10),float(m.s.wins[d.id])/(25 if m.s.wins[d.id]>=8 else 8)*100,true)
		u.button(c,"card_"+d.id,"查看档案",Rect2(20,333,206, forty()),func():g.open("card_detail",{"mission":d.id}),"file")
	u.button(p,"cards_prev","前五项",Rect2(40,555,220,56),func():card_page=0;g.render(),"back")
	u.button(p,"cards_next","后五项",Rect2(277,555,220,56),func():card_page=1;g.render(),"play")
	u.button(p,"graduation","毕业简报",Rect2(1001,555,309,56),func():g.open("graduation"),"file","primary",not m.graduate_ready() or m.s.phase=="war")
	u.text(p,"完整记录仍可升至钻石。",Rect2(548,561,408, fifty()),20,u.MUTED)

func forty() -> float: return 40.0
func fifty() -> float: return 50.0

func facility() -> void:
	var m=g.model
	var p=u.modal("基地设施","T2 提升上限；T3 开放第二能力槽；T4 完成全部培养设施。")
	u.image(p,Art.background("base_t%d"%m.s.tier if m.s.tier>1 else "base"),Rect2(40,137,737,415))
	u.text(p,"基地 T%d"%m.s.tier,Rect2(833,148,453, sixty()),37)
	u.text(p,"当前成长上限  Lv.%d"%m.cap(),Rect2(836,225,444, sixty()),26,u.ACCENT)
	if m.s.tier<4:
		var d=C.FACILITIES[int(m.s.tier)-1]
		u.text(p,"下一代 T%d\n成长上限 Lv.%d\n需要完成 %s\n%d 积分 / %d 合金"%[m.s.tier+1,m.cap()+5,d.mission,d.credits,d.alloy],Rect2(836,315,444,204),25,u.GOLD)
	else: u.text(p,"全部培养设施完成。\n积累十张金卡后读取毕业简报。",Rect2(836,322,444,190),25,u.GOLD)
	if not u.lock_notice(p,579):
		u.button(p,"upgrade_facility","升级至 T%d"%(m.s.tier+1) if m.s.tier<4 else "T4 全部完成",Rect2(970,576,335, sixty()),func():g.perform("facility"),"facility","primary",m.s.tier>=4)

func modules() -> void:
	var m=g.model
	var member=m.s.people[int(m.s.selected_person)]
	var p=u.modal("第二能力槽  /  "+C.PEOPLE[int(m.s.selected_person)].name,"同时装配一项能力。升级与换装都需小队回到房间。")
	var chosen=C.MODULES[0]
	for i in range(4):
		var d=C.MODULES[i]
		if d.id==module_selected: chosen=d
		u.button(p,"module_"+d.id,d.name+"  Lv.%d"%member.modules.get(d.id,0),Rect2(44,148+i*95,390, seventy()),func():module_selected=d.id;g.render(),d.icon,"primary" if d.id==module_selected else "neutral")
	u.image(p,Art.ui("icon_"+chosen.icon),Rect2(516,157,108,108))
	u.text(p,chosen.name,Rect2(659,172,608, seventy()),35)
	u.text(p,chosen.description,Rect2(514,301,763,124),26,u.ACCENT)
	var level=int(member.modules.get(chosen.id,0))
	u.text(p,"解锁：基地 T3 + %s 首胜\n当前装配：%s\n学习 / 升级：%d 积分 / %d 合金"%[chosen.mission,module_name(member.module),180*maxi(1,level),4*maxi(1,level)],Rect2(514,443,765,115),22,u.GOLD)
	var blocked=m.active() or not m.s.training.is_empty() or m.s.tier<3 or m.s.wins[chosen.mission]<1
	u.button(p,"module_upgrade","学习能力" if level==0 else ("升级能力" if level<5 else "能力已满级"),Rect2(528,589,356,56),func():g.perform("module_upgrade",chosen.id),"upgrade","primary",blocked or level>=5)
	u.button(p,"module_equip","已装配" if member.module==chosen.id else "装配到第二槽",Rect2(913,589,382,56),func():g.perform("module_equip",chosen.id),"check","neutral",blocked or level==0 or member.module==chosen.id)

func module_name(id: String) -> String:
	for d in C.MODULES:
		if d.id==id: return d.name
	return "未装配"

func graduation() -> void:
	var m=g.model
	var p=u.modal("毕业简报","十张金卡是训练完成条件。阅读简报不会立即切换阶段。")
	u.image(p,Art.background("zero"),Rect2(40,134,718,403))
	u.image(p,Art.ui("emblem"),Rect2(887,140,165,165))
	var gold=0
	for d in C.MISSIONS:
		if m.s.wins[d.id]>=8: gold+=1
	u.text(p,"训练档案  %d / 10"%gold,Rect2(803,337,500,55),33,u.GOLD)
	u.text(p,"完整试验的权限记录等待阅读。\n确认接管前，可以继续留在房间整备。",Rect2(805,413,486,119),23,u.MUTED)
	u.button(p,"read_graduation","阅读毕业简报",Rect2(918,578,386, sixty()),func():begin_story("graduation"),"file","primary",not m.graduate_ready())

func handoff() -> void:
	var m=g.model
	var confirm=bool(g.payload.get("confirm",false))
	var p=u.modal("确认进入真实战争" if confirm else "房间网络交接","原四人将作为真实战士部署。此阶段不存在重建死者的操作。")
	for i in range(4):
		var c=u.panel(p,Rect2(43+i*322,137,306,280),"card")
		u.image(c,Art.frame(C.PEOPLE[i].id,0),Rect2(80,8,150,184),true)
		u.text(c,C.PEOPLE[i].name+" · "+C.PEOPLE[i].role,Rect2(16,203,274,36),22,u.INK,HORIZONTAL_ALIGNMENT_CENTER)
		u.text(c,"战力 %d"%m.stats(i).power,Rect2(16,242,274, thirty()),19,u.ACCENT,HORIZONTAL_ALIGNMENT_CENTER)
	u.text(p,"房间卸下这四个人后空载返航，再培养四名新人。\n百万房间持续往返。真实阵亡永久保留；历史模拟只重放训练记录。",Rect2(62,437,1217,92),25,u.GOLD,HORIZONTAL_ALIGNMENT_CENTER)
	u.button(p,"handoff_back","继续留在训练室",Rect2(217,566,422,65),g.go_base,"back")
	u.button(p,"handoff_confirm","确认部署四名战士" if confirm else "查看最终交接确认",Rect2(698,566,446,65),func():
		if confirm: g.perform("graduate")
		else: g.open("handoff",{"confirm":true}),"door","danger" if confirm else "primary")

func thirty() -> float: return 30.0

func begin_story(id: String,replay=false) -> void:
	story_id=id
	story_index=0
	story_replay=replay
	g.open("story")

func story() -> void:
	if not Story.STORIES.has(story_id): return
	var lines=Story.STORIES[story_id]
	var line=lines[mini(story_index,lines.size()-1)]
	var p=u.modal(Story.TITLES[story_id],"记录 %d / %d  ·  阅读期间战斗与运输暂停"%[story_index+1,lines.size()])
	var person=-1
	for i in range(4):
		if C.PEOPLE[i].name==line[0]: person=i
	if person>=0: u.image(p,Art.frame(C.PEOPLE[person].id,13),Rect2(63,149,298,420),true)
	else: u.image(p,Art.ui("emblem"),Rect2(103,214,224,224))
	u.text(p,line[0],Rect2(418,185,850, sixty()),36,u.ACCENT)
	u.text(p,line[1],Rect2(421,279,849,198),30)
	u.button(p,"story_next","完成阅读" if story_index==lines.size()-1 else "继续  ·  空格",Rect2(959,571,344, sixty()),next_story,"play","primary")

func next_story() -> void:
	var lines=Story.STORIES[story_id]
	if story_index<lines.size()-1:
		story_index+=1
		g.render()
		return
	var m=g.model
	if not story_replay:
		var seen=m.s.war.story_seen if m.in_war() else m.s.story_seen
		if not seen.has(story_id): seen.append(story_id)
		var queue=m.s.war.story_queue if m.in_war() else m.s.story_queue
		queue.erase(story_id)
		if story_id=="graduation": m.s.reveal_read=true
		if story_id=="sector_12": m.s.war.ending_read=true
		if not g.commit(): return
	if story_id=="graduation" and not story_replay:
		g.page="handoff"
		g.payload={"confirm":false}
		g.history.clear()
	elif story_id=="sector_12" and not story_replay:
		g.page="war_ending"
		g.history.clear()
	else:
		g.page=""
		g.history.clear()
	g.render()

func journal() -> void:
	var m=g.model
	var p=u.modal("广播与远征记录","已发生的故事可以重读；不会改变士兵生死、奖励或阶段进度。")
	var keys=m.s.story_seen.duplicate()
	if m.s.phase=="war":
		for id in m.s.war.story_seen:
			if not keys.has(id): keys.append(id)
	for id in m.s.story_queue:
		if not keys.has(id): keys.append(id)
	if m.in_war():
		for id in m.s.war.story_queue:
			if not keys.has(id): keys.append(id)
	for i in range(keys.size()):
		var id=keys[i]
		var seen=id in m.s.story_seen or (m.s.phase=="war" and id in m.s.war.story_seen)
		u.button(p,"journal_"+id,Story.TITLES.get(id,id),Rect2(47+(i%2)*650,143+int(i/2)*100,615,76),func():begin_story(id,seen),"file")
	if keys.is_empty(): u.text(p,"完成任务后，新的广播记录会保存在这里。",Rect2(163,281,1034,101),28,u.MUTED,HORIZONTAL_ALIGNMENT_CENTER)

func war_main() -> void:
	var m=g.model
	var w=m.war_model()
	var s=m.s.war
	var d=W.planet(s.planet if s.active else maxi(0,s.occupied-1))
	u.image(g.ui_root,Art.ui("topbar"),Rect2(0,0,1600,96))
	u.text(g.ui_root,d.id+"  "+d.name if s.active else ("轨道集结" if s.occupied==0 else "驻守  /  "+d.name),Rect2(43,9,510, forty()),28)
	u.live.war_stage=u.text(g.ui_root,"",Rect2(46,51,616, thirty()),18,u.ACCENT)
	u.live.war_resources=u.text(g.ui_root,"",Rect2(686,16,700,56),23,u.GOLD,HORIZONTAL_ALIGNMENT_RIGHT)
	u.button(g.ui_root,"menu","",Rect2(1491,17,60,53),func():g.open("pause"),"settings")
	u.panel(g.ui_root,Rect2(26,100,555,106),"card")
	u.panel(g.ui_root,Rect2(1103,100,468,106),"card")
	u.live.war_hull=u.bar(g.ui_root,Rect2(42,112,308,13),s.hull/10)
	u.live.war_status=u.text(g.ui_root,"",Rect2(43,139,554, sixty()),22,u.INK)
	u.live.war_enemy=u.bar(g.ui_root,Rect2(1210,112,341,13),100,true)
	u.live.war_enemy_label=u.text(g.ui_root,"",Rect2(1120,140,426,60),22,u.GOLD,HORIZONTAL_ALIGNMENT_RIGHT)
	u.button(g.ui_root,"war_speed","× %d"%m.s.speed,Rect2(1352,224,181, fifty()),func():g.perform("speed"),"speed")
	u.button(g.ui_root,"war_auto","自动推进：开" if s.auto_push else "自动推进：关",Rect2(1246,287,288, fifty()),func():g.war_action("auto_push"),"play")
	u.button(g.ui_root,"war_boost","火力 +30%  /  200",Rect2(48,214,304, fifty()),func():g.war_action("boost"),"cannon","primary",not s.active)
	u.button(g.ui_root,"war_repair","锚点修复  /  150",Rect2(48,277,304, fifty()),func():g.war_action("repair"),"medical","neutral",not s.active)
	u.image(g.ui_root,Art.ui("bottom_bar"),Rect2(0,749,1600,151))
	u.live.war_summary=u.text(g.ui_root,"",Rect2(48,756,1125,39),21,u.ACCENT)
	u.button(g.ui_root,"war_retreat","撤退",Rect2(1310,747,236, forty()),func():g.open("war_retreat"),"back","danger",not s.active)
	var items=[["星图","map","war_map"],["房间网络","home","war_rooms"],["生产编制","team","war_formation"],["科技","skill","war_tech"],["士兵记录","file","war_soldiers"],["文明卡","cards","war_cards"]]
	for i in range(6):
		var item=items[i]
		u.button(g.ui_root,item[2],item[0],Rect2(40+i*255,808,239, sixty()),func():g.open(item[2]),item[1],"primary" if i==0 else "neutral")
	if not s.active:
		u.button(g.ui_root,"war_continue","查看远征结局" if s.ending else "选择下一星区",Rect2(615,617,369,66),func():g.open("war_ending" if s.ending else "war_map"),"map","primary")
	if not s.story_queue.is_empty():
		u.button(g.ui_root,"war_pending_story","新记录",Rect2(667,215,253,53),func():begin_story(s.story_queue[0]),"file","primary")

func refresh() -> void:
	if not g.model.in_war(): return
	var s=g.model.s.war
	var w=g.model.war_model()
	var live=u.live
	if live.has("war_resources"): live.war_resources.text="战备物资  %s   /   研究点  %s"%[W.number(s.supplies),W.number(s.science)]
	if live.has("war_hull"): live.war_hull.value=s.hull/10
	if live.has("war_stage"): live.war_stage.text="战斗段 %d / %d · 永久伤亡"%[mini(s.stage+1,W.planet(s.planet).stages),W.planet(s.planet).stages] if s.active else "已控制 %d / 12 战略星区 · 培养运输继续"%s.occupied
	if live.has("war_status"): live.war_status.text="登陆锚点  %d / 1000\n在役战力  %s 人"%[ceili(s.hull),W.number(w.soldiers())]
	if live.has("war_enemy"): live.war_enemy.value=s.enemy_hp/maxf(1,s.enemy_max)*100
	if live.has("war_enemy_label"): live.war_enemy_label.text="敌军  %s\n%s"%[W.number(s.enemy_count),"增援接战中" if s.phase=="fight" else ("接战倒计时 %.1f 秒"%s.wait if s.active else "全军驻守")]
	if live.has("war_summary"): live.war_summary.text="百万房间 · 运送中 %s 人 · 累计阵亡 %s · 画面为当前军团抽样"%[W.number(w.held()),W.number(s.dead)]
	if live.has("room_progress"):
		var stream=s.streams[room_stream]
		live.room_progress.value=100*(1-stream.remaining/maxf(1,stream.duration))
		live.room_phase.text="%s  ·  %.1f 秒\n本批携员 %s · 第 %d 批"%[W.phase_name(stream.phase),maxf(0,stream.remaining),W.number(stream.held),stream.cycle]
		live.room_art.texture=Art.frame("room_transport",1 if stream.phase=="unloading" else (2 if stream.phase=="returning" else 0))
	if live.has("war_autocount"): live.war_autocount.text="%d 秒后自动推进，任意点击可取消。"%ceili(g.auto_timer) if g.auto_timer>0 else "存活部队驻守，空房继续培养与运输。"
	if live.has("soldier_people"):
		for i in range(4):
			var d=s.originals[i]
			var row=live.soldier_people[i]
			row.art.texture=Art.frame(C.PEOPLE[i].id,15 if d.status=="阵亡" else 0)
			row.art.modulate=Color(.5,.55,.53,1) if d.status=="阵亡" else Color.WHITE
			row.name.text=d.name+" · "+d.status
			row.name.add_theme_color_override("font_color",u.GOLD if d.status=="阵亡" else u.ACCENT)
			row.bar.value=d.current_hp/d.hp*100
			row.hp.text="%d / %d"%[ceili(d.current_hp),ceili(d.hp)]
		var counts=w.roles()
		live.soldier_counts.text="在役：盾卫 %s · 射手 %s · 炮兵 %s · 医疗 %s"%[W.number(counts[0]),W.number(counts[1]),W.number(counts[2]),W.number(counts[3])]
		live.soldier_totals.text="累计培养 %s  =  在役 %s  +  待命 / 在途 %s  +  永久阵亡 %s"%[W.number(s.generated),W.number(w.soldiers()),W.number(w.held()),W.number(s.dead)]
	if live.has("war_science"): live.war_science.text="拥有 %s 研究点 · %d / 12 星区提供每分钟 %d 研究点"%[W.number(s.science),s.occupied,int(s.occupied)*3]

func star_map() -> void:
	var s=g.model.s.war
	var p=u.modal("星际航图","十二战略枢纽代表各自文明的星域。沿占领航路前进，驻守每分钟产出物资与研究点。")
	for i in range(12):
		var d=W.planet(i)
		var col=i%4
		var row=int(i/4)
		var c=u.panel(p,Rect2(40+col*322,133+row*132,309,121),"card_gold" if i<s.occupied else "card")
		u.image(c,Art.background(d.bg),Rect2(8,8,106, sixty()))
		u.text(c,d.id+" "+d.name,Rect2(124,9,173, fifty()),19,u.ACCENT if i<s.occupied else u.INK)
		u.button(c,"planet_%d"%i,"已控制" if i<s.occupied else ("选定航路" if i==s.occupied else "未连通"),Rect2(14, seventy(),281, forty()),func():chosen_planet=i;g.render(),"check" if i<s.occupied else "map","primary" if i==chosen_planet else "neutral",i>s.occupied)
	var d=W.planet(chosen_planet)
	u.text(p,d.tip+"\n建议集结 %s 人 · 现有 %s 人"%[W.number(W.recommended(chosen_planet)),W.number(g.model.war_model().soldiers())],Rect2(42,536,807,104),20,u.MUTED)
	var title="正在交战" if s.active else ("全部星域已控制" if s.occupied>=12 else "进攻  "+W.planet(s.occupied).name)
	u.button(p,"planet_launch",title,Rect2(903,568,405, sixty()),func():g.war_action("launch",s.occupied),"door","primary",s.active or s.occupied>=12)

func rooms() -> void:
	var s=g.model.s.war
	var p=u.modal("房间网络  /  1,000,000 间","每间四个席位。卸载后空房离开；上一批存活不阻塞下一批。")
	for i in range(4):
		u.button(p,"room_group_%d"%i,"第 %d 网络群"%(i+1),Rect2(42+i*324,134,305,51),func():room_group=i;room_stream=1+i*4;g.render(),"home","primary" if i==room_group else "neutral")
	u.live.room_art=u.image(p,Art.frame("room_transport",0),Rect2(67,213,517,281),true)
	var stream=s.streams[room_stream]
	u.text(p,"R-%06d"%stream.first if stream.rooms==1 else "R-%06d — R-%06d"%[stream.first,stream.first+stream.rooms-1],Rect2(620,208,678,48),29,u.ACCENT)
	u.live.room_phase=u.text(p,"",Rect2(622,286,671,113),27)
	u.live.room_progress=u.bar(p,Rect2(623,423,659,17),0,true)
	u.text(p,"投送目的地：%s\n编制与培养属性已封存；下一批才应用新设置。"%(W.planet(s.planet).name if s.active else ("轨道安全区" if s.occupied==0 else W.planet(s.occupied-1).name)),Rect2(622,465,664,94),21,u.MUTED)
	for i in range(4):
		var idx=1+room_group*4+i
		u.button(p,"room_stream_%d"%i,"时序 %d"%(i+1),Rect2(48+i*140,543,128,48),func():room_stream=idx;g.render(),"","primary" if room_stream==idx else "neutral")
	u.button(p,"room_original","查看原始房间 R-000001",Rect2(47,611,533, forty()),func():room_group=0;room_stream=0;g.render(),"eye")
	u.button(p,"room_auto","连续投送：开" if s.auto_send[room_group] else "完成后待命",Rect2(622,593,312,57),func():g.war_action("auto_send",room_group),"play","primary")
	u.button(p,"room_ledger","投送批次日志",Rect2(954,593,342,57),func():g.open("war_ledger"),"file")

func formation() -> void:
	var s=g.model.s.war
	var p=u.modal("生产编制","每间始终培养四名新人，可重复职业。改编只影响下一次开始的培养批次。")
	for i in range(4):
		u.button(p,"formation_group_%d"%i,"第 %d 网络群"%(i+1),Rect2(42+i*324,134,306,51),func():room_group=i;g.render(),"home","primary" if i==room_group else "neutral")
	for slot in range(4):
		var role=int(s.formations[room_group][slot])
		var d=W.ROLES[role]
		var c=u.panel(p,Rect2(42+slot*324,203,306,359),"card")
		u.image(c,Art.frame(d.asset,0),Rect2(65,15,177,204),true)
		u.text(c,"席位 %d · %s"%[slot+1,d.name],Rect2(18,239,270, forty()),25,u.INK,HORIZONTAL_ALIGNMENT_CENTER)
		u.button(c,"formation_slot_%d"%slot,"更换职业",Rect2(23,293,260, fifty()),func():g.war_action("formation",{"group":room_group,"slot":slot,"role":(role+1)%4}),d.icon)
	u.text(p,"盾卫承伤 · 射手持续火力 · 炮兵穿甲 · 医疗降低战损\n新兵身份 = 房间编号 / 批次 / 席位。改编不会改造已经投送的战士。",Rect2(48,579,1253, seventy()),22,u.ACCENT)

func technology() -> void:
	var s=g.model.s.war
	var p=u.modal("远征科技","研究点来自星区战果与驻守。升级应用于新培养的士兵或下一趟航程。")
	for i in range(4):
		var d=W.TECH[i]
		var level=int(s.tech[d.id])
		var c=u.panel(p,Rect2(42+(i%2)*647,140+int(i/2)*234,624,215),"card")
		u.image(c,Art.ui("icon_"+d.icon),Rect2(22,24, sixty(),sixty()))
		u.text(c,d.name+"  Lv.%d / 20"%level,Rect2(108,23,490, fifty()),28)
		u.text(c,d.desc,Rect2(24,94,570,57),21,u.ACCENT)
		u.button(c,"tech_"+d.id,"研究  /  %d 点"%(40+60*level) if level<20 else "已完成",Rect2(283,155,314, fifty()),func():g.war_action("tech",d.id),"upgrade","primary",level>=20)
	u.live.war_science=u.text(p,"",Rect2(49,622,1254, thirty()),21,u.GOLD)

func soldiers() -> void:
	var s=g.model.s.war
	var w=g.model.war_model()
	var p=u.modal("士兵与永久伤亡","四名原始战士保留独立身份；新的批次不会继承死者身份。")
	u.live.soldier_people=[]
	for i in range(4):
		var d=s.originals[i]
		var c=u.panel(p,Rect2(43+i*323,137,308,337),"card")
		var art=u.image(c,Art.frame(C.PEOPLE[i].id,15 if d.status=="阵亡" else 0),Rect2( seventy(),12,170,197),true)
		if d.status=="阵亡": art.modulate=Color(.5,.55,.53,1)
		var name_label=u.text(c,"",Rect2(15,221,278, forty()),24,u.ACCENT,HORIZONTAL_ALIGNMENT_CENTER)
		var bar=u.bar(c,Rect2(25,282,258,12),0)
		var hp=u.text(c,"",Rect2(20,303,270,27),18,u.MUTED,HORIZONTAL_ALIGNMENT_CENTER)
		u.live.soldier_people.append({"art":art,"name":name_label,"bar":bar,"hp":hp})
	u.live.soldier_counts=u.text(p,"",Rect2(48,497,1255,48),24,u.ACCENT)
	u.live.soldier_totals=u.text(p,"",Rect2(48,558,1256, sixty()),22,u.GOLD)
	u.button(p,"soldier_records","阵亡记录与投送日志",Rect2(929,623,377, forty()),func():g.open("war_ledger"),"file")

func civilizations() -> void:
	var s=g.model.s.war
	var p=u.modal("文明档案  /  %d — 12"%s.cards.size(),"每个文明卡对应已经控制的战略星域。重复打开不会再次领取奖励。")
	for i in range(12):
		var d=W.planet(i)
		var owned=s.cards.has(d.id)
		var c=u.panel(p,Rect2(40+(i%6)*216,135+int(i/6)*246,205,233),"card_gold" if owned else "card")
		u.image(c,Art.background(d.bg),Rect2(9,9,187,104))
		var figure=u.image(c,Art.frame(d.enemy,8),Rect2(44,35,118,111),true)
		if not owned: figure.modulate=Color(.08,.1,.1,1)
		u.text(c,d.civ if owned else "未知文明",Rect2(12,157,181, forty()),21,u.GOLD if owned else u.MUTED,HORIZONTAL_ALIGNMENT_CENTER)
		u.text(c,d.id+" · "+("已征服" if owned else "未接触"),Rect2(12,198,181,26),18,u.ACCENT,HORIZONTAL_ALIGNMENT_CENTER)

func result() -> void:
	var s=g.model.s.war
	var r=s.result
	if r.is_empty(): return
	var d=W.planet(r.planet)
	var victory=r.outcome=="victory"
	var p=u.modal("星区已控制" if victory else ("撤退完成" if r.outcome=="retreat" else "登陆锚点失守"),"已取得的战果保留。死者不会复原，空房返航不会带回已部署战士。")
	u.image(p,Art.background(d.bg),Rect2(42,138,612,343))
	u.text(p,d.name+" / "+d.civ,Rect2(690,149,614, seventy()),29)
	u.text(p,"本次阵亡  %s\n存活部队  %s\n完成作战段  %d / %d\n获得 %d 物资 / %d 研究点"%[W.number(r.dead),W.number(r.survivors),r.completed,d.stages,r.supplies,r.science],Rect2(691,259,614,210),25,u.GOLD)
	u.live.war_autocount=u.text(p,"",Rect2(48,503,1258, fifty()),22,u.ACCENT)
	u.button(p,"war_result_return","返回驻守区" if s.occupied>0 else "返回轨道集结",Rect2(43,587,365, sixty()),g.close_war_result,"home","primary")
	u.button(p,"war_result_memorial","查看伤亡",Rect2(437,587,358, sixty()),func():g.open("war_soldiers"),"file")
	u.button(p,"war_result_next","下一星区" if victory else "重新组织进攻",Rect2(916,587,389, sixty()),func():g.war_action("launch",s.occupied),"door","neutral",s.occupied>=12)

func retreat() -> void:
	var s=g.model.s.war
	var p=u.modal("撤退确认","确认期间暂停。已阵亡的士兵不会恢复；在途房间改投安全集结区。")
	u.image(p,Art.frame("room_transport",2),Rect2(102,152,400,289),true)
	u.text(p,"退守："+("轨道安全区" if s.occupied==0 else W.planet(s.occupied-1).name),Rect2(562,189,720, seventy()),34,u.GOLD)
	u.text(p,"保留本次已获得的 %d 物资 / %d 研究点。\n士兵生命与伤亡继续保留，驻守会治疗活着的人。\n基础培养免费，兵力耗尽后仍能重新集结。"%[s.reward_supplies,s.reward_science],Rect2(565,305,709,170),24,u.MUTED)
	u.button(p,"war_retreat_cancel","继续作战",Rect2(310,562,340,65),g.back,"play")
	u.button(p,"war_retreat_confirm","确认撤退",Rect2(720,562,340,65),func():g.war_action("retreat"),"back","danger")

func ledger() -> void:
	var s=g.model.s.war
	var p=u.modal("运输与阵亡记录","新兵编号由房间范围、批次与四个席位组成。保留最近 80 组运输记录，累计人数永久保留。")
	var rows=[]
	for d in s.memorial: rows.append("永久阵亡  %s  /  %s  第 %d 段  /  %.1f 秒"%[d.name,W.planet(d.planet).name,d.stage,d.time])
	for d in s.ledger: rows.append("R-%06d—%06d  /  第 %d 批  /  卸载 %s 人  /  %s"%[d.first,d.last,d.cycle,W.number(d.count),"轨道集结" if d.destination==0 else W.planet(d.destination-1).name])
	var pages=maxi(1,ceili(rows.size()/7.0))
	log_page=clampi(log_page,0,pages-1)
	for i in range(7):
		var idx=log_page*7+i
		if idx>=rows.size(): break
		u.text(p,rows[idx],Rect2( fifty(),135+i*59,1263, fifty()),21,u.GOLD if idx<s.memorial.size() else u.INK)
	u.text(p,"%d / %d 页 · 累计 %s 人阵亡"%[log_page+1,pages,W.number(s.dead)],Rect2( fifty(),583,700, fifty()),22,u.GOLD)
	u.button(p,"ledger_prev","上一页",Rect2(899,578,185,56),func():log_page=maxi(0,log_page-1);g.render(),"back", "neutral",log_page==0)
	u.button(p,"ledger_next","下一页",Rect2(1102,578,205,56),func():log_page=mini(pages-1,log_page+1);g.render(),"play","neutral",log_page>=pages-1)

func historical() -> void:
	var p=u.modal("历史模拟","重放第一阶段的训练记录。真实战争、培养与运输都会暂停。")
	u.image(p,Art.background("base"),Rect2(43,138,675,380))
	u.text(p,"记录可以重放。\n真实战士不会重生。",Rect2(766,180,537,153),35,u.GOLD)
	u.text(p,"历史训练奖励留在训练档案。\n原四人的真实战场记录、生命与装备不会被覆盖。",Rect2(767,380,527,126),24,u.MUTED)
	u.button(p,"enter_history","进入历史模拟",Rect2(910,578,397, sixty()),func():g.perform("history",true),"eye","primary",g.model.s.war.active)

func ending() -> void:
	var s=g.model.s.war
	var totals=s.get("ending_stats",{"time":s.time,"landed":s.landed,"dead":s.dead})
	var p=u.modal("远征完成  /  人类统治网络","十二战略星区全部连通。档案与驻守继续开放。")
	u.image(p,Art.background("p12"),Rect2(42,137,690,388))
	u.text(p,"房间记得他们。",Rect2(775,155,533, seventy()),37,u.GOLD)
	u.text(p,"控制星区  12 / 12\n文明档案  %d / 12\n累计投送  %s\n永久阵亡  %s\n远征用时  %d 分钟"%[s.cards.size(),W.number(totals.landed),W.number(totals.dead),int(totals.time)/60],Rect2(778,261,524,249),25,u.ACCENT)
	u.button(p,"ending_story","阅读结局",Rect2(43,579,354, sixty()),func():begin_story("sector_12",s.ending_read),"file","primary")
	u.button(p,"ending_memorial","查看战士记录",Rect2(440,579,371, sixty()),func():g.open("war_soldiers"),"team")
	u.button(p,"ending_history","重访训练房间",Rect2(945,579,358, sixty()),func():g.open("war_history"),"home")
