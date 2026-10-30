extends Node2D
## Background-only motion. Actors, furniture outside these regions and collision stay fixed.
const Rooms=preload("res://scripts/pixel_home/rooms.gd")
const EFFECT=preload("res://scripts/pixel_home/ambient.gdshader")
var host
var room=""
var clock=0.0
var sprite:Sprite2D
var effect:ShaderMaterial
var void_effect:ShaderMaterial

func _init(owner_home=null) -> void:host=owner_home
func _ready() -> void:
	z_index=-10;texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var void_plane=ColorRect.new();void_plane.size=Vector2(1600,900);void_plane.mouse_filter=Control.MOUSE_FILTER_IGNORE
	void_effect=ShaderMaterial.new();void_effect.shader=preload("res://scripts/pixel_home/void.gdshader");void_plane.material=void_effect;add_child(void_plane)
	effect=ShaderMaterial.new();effect.shader=EFFECT
	sprite=Sprite2D.new();sprite.material=effect;add_child(sprite)
	sync_room();queue_redraw()

static func regions(id:String) -> Array:
	match id:
		"balcony":return [Rect2(654,795,125,80),Rect2(),Rect2()]
		_:return [Rect2(),Rect2(),Rect2()]

func sync_room() -> void:
	if sprite==null or room==host.current_room:return
	room=host.current_room;sprite.texture=host.texture(Rooms.image_path(room))
	var rect=Rooms.image_rect(room);sprite.position=rect.get_center();sprite.scale=rect.size/sprite.texture.get_size()
	var masks=regions(room)
	for i in range(3):
		var r:Rect2=masks[i];var size=sprite.texture.get_size()
		effect.set_shader_parameter(["cloth_a","cloth_b","sunlight"][i],Vector4(r.position.x/size.x,r.position.y/size.y,r.size.x/size.x,r.size.y/size.y))
	effect.set_shader_parameter("cloth_pixels",2.5 if room=="living" else 3.0)

func tick(delta:float) -> void:
	visible=host.mode in ["home","overlay"]
	if not visible:return
	sync_room();clock+=delta;effect.set_shader_parameter("breeze_time",clock);void_effect.set_shader_parameter("flow_time",clock)
	position=host.intro.shake if host.intro!=null else Vector2.ZERO

func _draw() -> void:draw_rect(Rect2(-8,-8,1616,916),Color("17232f"))
