from pathlib import Path
p=Path(__file__).resolve().parents[1]/'scripts/earth/main.gd'
s=p.read_text(encoding='utf-8')
start=s.index('func missions_screen() -> void:')
end=s.index('\nfunc deploy(',start)
s=s[:start]+'''func missions_screen() -> void:
	panel(Rect2(28,22,1544,856))
	text("异境之门",Rect2(60,42,560,69),43,GOLD)
	text("BOUNDARY / %03d"%selected_stage,Rect2(66,114,580,32),18,MUTED)
	text("异常记录 %d / 300 · 已开放 %d"%[model.s.wins.size(),model.s.max_stage],Rect2(897,59,620,43),23,GOLD)
	var m=C.mission(selected_stage)
	var portal=PortalView.new()
	portal.position=Vector2(42,153);portal.size=Vector2(690,630)
	portal.destination=Art.texture("battle.street.1" if m.bg=="street" else "battle."+m.bg)
	portal.opening=.20;portal.locked=selected_stage>model.s.max_stage
	ui.add_child(portal)
	text("%03d / %s"%[selected_stage,C.AREAS[(selected_stage-1)%10][0]],Rect2(700,169,800,58),32)
	text("首领：%s · 特征：%s"%[m.boss,m.mechanic],Rect2(700,236,800,43),22,GOLD)
	text(C.mechanic_tip(m.mechanic),Rect2(700,284,800,60),20,MUTED)
	for i in range(10):
		var stage=mission_page*10+i+1
		var count=int(model.s.wins.get(str(stage),0))
		var label="锁定" if stage>model.s.max_stage else "已肃清 ×%d"%count if count>0 else "未探索"
		button("mission%d"%stage,"%03d  %s / %s"%[stage,C.AREAS[i][0],label],Rect2(697+(i%2)*421,358+int(i/2)*68,402,57),func():selected_stage=stage;draw_view(),false,"primary" if stage==selected_stage else "neutral").add_theme_font_size_override("font_size",18)
	text("胜利：%d 积分 / %d 合金 / %d 核心 + 1 件装备"%[m.credits,m.alloy,m.cores],Rect2(698,709,800,43),21,GOLD)
	button("previous_page","上一组",Rect2(701,772,165,49),func():mission_page-=1;selected_stage=mission_page*10+1;draw_view(),mission_page==0)
	button("next_page","下一组",Rect2(885,772,165,49),func():mission_page+=1;selected_stage=mission_page*10+1;draw_view(),mission_page==29)
	text("第 %d / 30 组"%(mission_page+1),Rect2(1074,778,208,35),18,MUTED)
	var unlocked=selected_stage<=model.s.max_stage
	text("已对准目标世界" if unlocked else "需先肃清第 %d 关"%(selected_stage-1),Rect2(72,773,545,37),22,GOLD)
	button("open_portal","开启异境" if unlocked else "尚未连接",Rect2(155,695,409,68),func():open_portal(portal),not unlocked,"primary")
	button("support","支援装置",Rect2(61,823,264,40),func():navigate("support"))
	button("back","关闭异境之门",Rect2(1298,814,225,49),func():navigate("base"))

func open_portal(portal: Control) -> void:
	if portal_opening or selected_stage>model.s.max_stage:return
	portal_opening=true
	for b in buttons.values():b.disabled=true
	var stage=selected_stage
	var tween=create_tween()
	tween.tween_property(portal,"opening",1.0,.65).set_trans(Tween.TRANS_CUBIC)
	tween.tween_interval(.25)
	tween.tween_callback(func():
		portal_opening=false
		deploy(stage))
''' + s[end:]
start=s.index('func result_screen() -> void:')
end=s.index('\nfunc sixty()',start)
s=s[:start]+'''func result_screen() -> void:
	var r=model.s.result
	if r.is_empty():navigate("base");return
	panel(Rect2(245,103,1110,728))
	var title={"victory":"异常肃清","recall":"小队已召回","defeat":"小队失去战斗能力"}[r.reason]
	text(title,Rect2(290,132,1020,72),43,GOLD)
	text("%03d / %s"%[r.stage,C.mission(r.stage).name],Rect2(294,210,1010,49),29)
	text("%d 积分   /   %d 合金   /   %d 核心"%[r.credits,r.alloy,r.cores],Rect2(294,274,1010,49),28)
	text("用时 %.1f 秒 · 击败 %d · 伤害 %.0f · 治疗 %.0f"%[r.time,r.killed,r.damage,r.healing],Rect2(294,330,1010,39),21,MUTED)
	var drops=r.get("loot",[])
	if not drops.is_empty():
		var item=drops[0]
		text("战利品 / %s · %s"%[Loot.QUALITY[item.quality-1],Loot.name_of(item)],Rect2(294,384,1010,47),28,Loot.COLORS[item.quality-1])
		text(Loot.affix_text(item).replace("\\n","   /   "),Rect2(294,436,1010,44),22)
		text(Loot.special_text(item),Rect2(294,485,1010,67),23,GOLD)
	else:text("本次带回已击败目标的资源。肃清首领可获得装备。",Rect2(294,405,1010,90),25,MUTED)
	var unlocks="解锁："+" / ".join(r.get("unlocks",[])) if not r.get("unlocks",[]).is_empty() else "继续挑战会恢复队伍状态；战利品已保存。"
	text(unlocks,Rect2(294,566,1010,48),21,GOLD)
	var can_next=r.reason=="victory" and r.stage<C.STAGE_COUNT
	button("continue_next","继续下一异常" if can_next else "已到本阶段终点" if r.stage==C.STAGE_COUNT else "胜利后开放下一关",Rect2(292,636,487,63),func():continue_after_result(r.stage+1),not can_next,"primary")
	button("repeat","再次挑战本关",Rect2(805,636,487,63),func():continue_after_result(r.stage))
	button("loot","整理战利品",Rect2(292,732,313,58),func():open_equipment("result"))
	button("return_grow","返家培养",Rect2(635,732,313,58),func():return_from_result("growth"))
	button("return","返回房间",Rect2(979,732,313,58),func():return_from_result())
''' +s[end:]
s=s.replace('var labels={"level":"个人成长","equipment":"属性装备","talent":"个人天赋"}','var labels={"level":"个人成长","equipment":"模组强化","talent":"个人天赋"}')
s=s.replace('属性装备上限','模组强化上限')
s=s.replace('func growth_screen() -> void:\n','func growth_screen() -> void:\n\tbutton("equipment","装备与词条",Rect2(50,827,345,54),func():open_equipment("growth"),false,"primary")\n')
s=s.replace('击败持有装置的异常 → 解锁购置 → 升级 → 战场支援','空间装置与穿戴装备的召唤支援可同时生效。')
s=s.replace('func support_screen() -> void:\n','func support_screen() -> void:\n\tbutton("equipment","查看装备召唤",Rect2(50,827,330,54),func():open_equipment("squad"))\n')
p.write_text(s,encoding='utf-8')

h=p.with_name('home.gd')
s=h.read_text(encoding='utf-8').replace('收集阵里多出的东西，或许能改变下一场战斗。','门外带回的装备，或许能改变下一场战斗。').replace('打印舱可以制造整套装备。右边那些东西，最好先看清来历。','打印舱可以制造整套战斗服。外门连接的世界，最好先看清再进入。')
h.write_text(s,encoding='utf-8')
print('Portal, results, equipment entry points updated.')
