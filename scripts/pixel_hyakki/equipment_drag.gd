extends Node2D
const SNAP_DISTANCE=4.0
var ui
var item_id=0
var start=Vector2.ZERO
var pointer=Vector2.ZERO
var active=false
var hover_slot=""

func setup(owner_ui) -> void:
	ui=owner_ui;texture_filter=TEXTURE_FILTER_NEAREST
	visibility_changed.connect(func():if not is_visible_in_tree():cancel())
	get_window().focus_exited.connect(cancel)

func cancel() -> void:
	item_id=0;active=false;hover_slot="";queue_redraw()

func eligible_slots(id:int) -> Array:
	var item=ui.gear.item_by_id(id);var result=[]
	if item.is_empty():return result
	for slot in ui.G.SLOTS:
		if ui.G.can_equip(item,ui.hero,slot):result.append(slot)
	return result

func slot_at(point:Vector2,id:int) -> String:
	var closest="";var best=SNAP_DISTANCE+0.01
	for slot in eligible_slots(id):
		var rect=ui.slot_rect(ui.G.SLOTS.find(slot))
		var distance=point.distance_to(point.clamp(rect.position,rect.end))
		if distance<best:best=distance;closest=slot
	return closest

func item_at(point:Vector2) -> int:
	for i in range(9):
		if ui.slot_rect(i).has_point(point):return int(ui.gear.s.equipped[ui.hero].get(ui.G.SLOTS[i],0))
	var items=ui.items()
	for n in range(ui.page_size()):
		if ui.page*ui.page_size()+n<items.size() and ui.cell_rect(n).has_point(point):return items[ui.page*ui.page_size()+n].id
	return 0

func drop_at(point:Vector2) -> bool:
	var id=item_id;var slot=slot_at(point,id);cancel()
	if slot=="":ui.message("未穿戴：请放到高亮的对应部位");ui.refresh();return false
	if not ui.gear.equip(id,ui.hero,slot):ui.message("这件装备无法穿戴到这里");ui.refresh();return false
	ui.selected=id;ui.target_slot=slot;ui.confirm_salvage=false
	ui.changed("已穿戴到"+ui.G.SLOT_NAMES[ui.G.SLOTS.find(slot)]);return true

func _input(event:InputEvent) -> void:
	if ui==null or not is_visible_in_tree() or ui.host.screen!="equipment":return
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE and item_id>0:
		cancel();ui.refresh();get_viewport().set_input_as_handled();return
	if event is InputEventMouseMotion or event is InputEventMouseButton:pointer=get_global_transform_with_canvas().affine_inverse()*event.position
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:item_id=item_at(pointer);start=pointer
		elif active:drop_at(pointer);get_viewport().set_input_as_handled()
		else:cancel()
	elif event is InputEventMouseMotion and item_id>0:
		if not active and pointer.distance_to(start)>=7:active=true
		if active:
			hover_slot=slot_at(pointer,item_id);queue_redraw();get_viewport().set_input_as_handled()

func _process(_dt:float) -> void:
	if active:queue_redraw()

func _draw() -> void:
	if not active or ui==null:return
	var item=ui.gear.item_by_id(item_id)
	if item.is_empty():return
	for slot in eligible_slots(item_id):
		var rect=ui.slot_rect(ui.G.SLOTS.find(slot));var hover=slot==hover_slot
		draw_rect(rect,Color(.5,.85,.7,.2 if hover else .08))
		draw_rect(rect.grow(3),Color("f5dca1") if hover else Color("88d2ba"),false,3 if hover else 2)
	var center=pointer if hover_slot=="" else ui.slot_rect(ui.G.SLOTS.find(hover_slot)).get_center()
	var ghost=Rect2(center-Vector2(31,31),Vector2(62,62))
	draw_rect(ghost.grow(3),Color(.06,.12,.17,.92));draw_rect(ghost.grow(3),Color("e7ca91"),false,2)
	ui.art.draw(self,item,ghost.grow(-3))
