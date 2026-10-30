extends RefCounted
## Bounded runtime textures. Source files are never resized or rewritten.
var limit:int
var max_edge:int
var textures:Dictionary={}
var order:Array=[]
var decodes=0
var resident_bytes=0
func _init(capacity:int=3,edge:int=0)->void:
	limit=maxi(1,capacity);max_edge=maxi(0,edge)
func has(path:String)->bool:return textures.has(path)
func get_texture(path:String)->Texture2D:
	if textures.has(path):
		order.erase(path);order.append(path);return textures[path]
	var source=Image.load_from_file(path)
	if source==null:return null
	if max_edge>0 and maxi(source.get_width(),source.get_height())>max_edge:
		var scale=float(max_edge)/maxi(source.get_width(),source.get_height())
		source.resize(maxi(1,roundi(source.get_width()*scale)),maxi(1,roundi(source.get_height()*scale)),Image.INTERPOLATE_NEAREST)
	source.convert(Image.FORMAT_RGBA8)
	while order.size()>=limit:
		var old=order.pop_front();var texture=textures[old]
		resident_bytes-=int(texture.get_width())*int(texture.get_height())*4;textures.erase(old)
	var result=ImageTexture.create_from_image(source)
	textures[path]=result;order.append(path);decodes+=1;resident_bytes+=source.get_width()*source.get_height()*4
	return result
func clear()->void:
	textures.clear();order.clear();resident_bytes=0
