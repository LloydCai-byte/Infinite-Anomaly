extends RefCounted
const Loot=preload("res://scripts/earth/loot.gd")
const C=preload("res://scripts/earth/catalog.gd")
var g: Control

func _init(game: Control) -> void:g=game

func draw() -> void:
	g.text("装备 / 战利品",Rect2(50,25,750,65),39)
	g.text("词条提升属性 · 异常装备召唤独立支援",Rect2(850,38,700,44),23,g.GOLD)
	g.member_tabs()
	var p=g.model.stats(g.selected)
	g.panel(Rect2(45,210,360,556))
	g.text(C.PEOPLE[g.selected].name,Rect2(70,230,290,45),29,g.GOLD)
	g.text("生命 %.0f   攻击 %.1f\n防御 %.1f   间隔 %.2f 秒"%[p.hp,p.atk,p.armor,p.interval],Rect2(70,282,305,83),20)
	for i in range(3):
		var slot=Loot.SLOTS[i]
		var id=g.model.s.equipped[g.selected].get(slot,0)
		var item=g.model.item_by_id(id)
		var y=393+i*108
		g.text(Loot.SLOT_NAMES[slot],Rect2(70,y,280,28),19,g.MUTED)
		g.button("slot_"+slot,Loot.name_of(item) if not item.is_empty() else "空置",Rect2(65,y+34,320,55),func():g.loot_selected=id;g.draw_view(),item.is_empty())
	g.panel(Rect2(425,210,535,556))
	g.text("携行仓库",Rect2(450,228,460,40),27,g.GOLD)
	var items=g.model.s.inventory.duplicate()
	items.reverse()
	var pages=maxi(1,ceili(items.size()/6.0))
	g.loot_page=clampi(g.loot_page,0,pages-1)
	if items.is_empty():g.text("完成一次异常挑战后，\n装备会出现在这里。\n\n首关首次肃清：棱镜头盔\n穿戴后可召唤折光精灵。",Rect2(460,325,460,270),25,g.MUTED)
	for i in range(6):
		var offset=g.loot_page*6+i
		if offset>=items.size():break
		var item=items[offset]
		var owner=g.model.item_owner(item.id)
		var tag=" · "+C.PEOPLE[owner].name if owner>=0 else ""
		var b=g.button("item_%d"%item.id,"%s · %s  [%s]%s"%[Loot.QUALITY[item.quality-1],Loot.name_of(item),Loot.SLOT_NAMES[Loot.BASES[item.base].slot],tag],Rect2(445,288+i*67,493,57),func():g.loot_selected=item.id;g.draw_view(),false,"primary" if item.id==g.loot_selected else "neutral")
		b.add_theme_font_size_override("font_size",18)
		b.add_theme_color_override("font_color",Loot.COLORS[item.quality-1])
	g.button("loot_prev","上一页",Rect2(449,705,137,43),func():g.loot_page-=1;g.draw_view(),g.loot_page==0)
	g.text("%d / %d"%[g.loot_page+1,pages],Rect2(608,706,155,42),20)
	g.button("loot_next","下一页",Rect2(795,705,137,43),func():g.loot_page+=1;g.draw_view(),g.loot_page>=pages-1)
	g.panel(Rect2(980,210,575,556))
	var item=g.model.item_by_id(g.loot_selected)
	if item.is_empty():
		g.text("选中一件装备",Rect2(1010,244,500,55),30,g.GOLD)
		g.text("查看词条与召唤效果，\n再决定交给哪位战士。",Rect2(1010,335,500,160),26,g.MUTED)
	else:
		var base=Loot.BASES[item.base]
		g.picture(g.Art.texture("equipment."+str(item.base)),Rect2(1004,228,90,90),true)
		g.text(Loot.name_of(item),Rect2(1104,231,400,50),31,Loot.COLORS[item.quality-1])
		g.text("%s · %s · 等级 %d"%[Loot.QUALITY[item.quality-1],Loot.SLOT_NAMES[base.slot],item.level],Rect2(1104,287,400,35),20,g.MUTED)
		g.text(Loot.affix_text(item),Rect2(1010,334,490,101),24)
		g.text(Loot.special_text(item),Rect2(1010,441,492,117),23,g.GOLD)
		var old=g.model.item_by_id(g.model.s.equipped[g.selected].get(base.slot,0))
		g.text("当前槽位："+(Loot.name_of(old)+"\n"+Loot.affix_text(old) if not old.is_empty() else "空置"),Rect2(1010,565,492,96),18,g.MUTED)
		var owner=g.model.item_owner(item.id)
		g.button("equip_loot","已穿戴 · 卸下" if owner==g.selected else ("从"+C.PEOPLE[owner].name+"转交" if owner>=0 else "穿戴给"+C.PEOPLE[g.selected].name),Rect2(1008,686,520,57),func():
			g.transact(func():return g.model.unequip_item(g.selected,base.slot) if owner==g.selected else g.model.equip_item(g.selected,item.id)),false,"primary")
	g.text("更换属性装备不会改变战斗服与配套武器。",Rect2(50,790,1120,47),22,g.MUTED)
	g.button("back","返回结算" if g.equipment_return=="result" else "返回小队" if g.equipment_return=="squad" else "返回培养",Rect2(1270,824,277,54),func():g.navigate(g.equipment_return))
