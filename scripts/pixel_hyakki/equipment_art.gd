extends RefCounted
const G=preload("res://scripts/turnbased/gear.gd")
const ICONS="res://art/pixel-equipment-20261025/icons/"
var cache={}
var reference_skin=false
var reference_texture:Texture2D
# Equipment artwork from the user's exact UI reference. These are atlas regions,
# not regenerated replacements; the source file remains byte-for-byte unchanged.
const REFERENCE_ICONS=[
	Rect2(686,371,63,52),Rect2(860,625,65,57),Rect2(1038,627,64,55),Rect2(948,370,65,54),
	Rect2(685,457,65,48),Rect2(1039,453,59,59),Rect2(948,452,65,61),Rect2(1271,329,101,88),
	Rect2(1125,626,72,58),Rect2(857,377,71,39),Rect2(773,373,63,51),Rect2(1047,542,57,55),
	Rect2(598,370,64,51),Rect2(777,453,58,53),Rect2(603,541,55,51),Rect2(777,541,57,53)]
# Bottom-left is reserved for live item level text in the reference grid.
# Exclude that corner when sampling icons so reference levels never leak into UI.
const REFERENCE_EXCLUDE=[Vector2(19,49),Vector2(20,47),Vector2(20,45),Vector2(18,49),Vector2.ZERO,Vector2(19,53),Vector2(19,54),Vector2.ZERO,Vector2(24,46),Vector2.ZERO,Vector2(19,47),Vector2(13,47),Vector2(20,50),Vector2.ZERO,Vector2(14,49),Vector2(17,49)]

static func index(item:Dictionary)->int:
	var base=G.bases[item.base]
	if base.type=="weapon":return [7,8,9,10,11][base.hero]
	if base.has("set"):return 12+G.SET_TYPES.find(base.type)
	return ["head","armor","gloves","boots","belt","necklace","ring"].find(base.type)

func source(item:Dictionary)->Dictionary:
	var key=index(item)
	if reference_skin:
		if reference_texture==null:reference_texture=ImageTexture.create_from_image(Image.load_from_file("res://art/equipment-reference-20261028/reference.png"))
		return {"texture":reference_texture,"bounds":REFERENCE_ICONS[key]}
	if not cache.has(key):
		var im=Image.load_from_file(ICONS+"%02d.png"%key)
		cache[key]={"texture":ImageTexture.create_from_image(im),"bounds":Rect2(im.get_used_rect())}
	return cache[key]

func destination(item:Dictionary,area:Rect2)->Rect2:
	var bounds=source(item).bounds
	var scale=minf(area.size.x/bounds.size.x,area.size.y/bounds.size.y)
	var size=(bounds.size*scale).round()
	return Rect2((area.get_center()-size*.5).round(),size)

func draw(canvas:CanvasItem,item:Dictionary,area:Rect2,modulate:Color=Color.WHITE)->void:
	if item.is_empty():return
	var data=source(item)
	var dest=destination(item,area)
	var cut=REFERENCE_EXCLUDE[index(item)] if reference_skin else Vector2.ZERO
	if cut==Vector2.ZERO:
		canvas.draw_texture_rect_region(data.texture,dest,data.bounds,modulate);return
	var factor=dest.size/data.bounds.size
	for region in [Rect2(Vector2.ZERO,Vector2(data.bounds.size.x,cut.y)),Rect2(cut,Vector2(data.bounds.size.x-cut.x,data.bounds.size.y-cut.y))]:
		canvas.draw_texture_rect_region(data.texture,Rect2(dest.position+region.position*factor,region.size*factor),Rect2(data.bounds.position+region.position,region.size),modulate)
