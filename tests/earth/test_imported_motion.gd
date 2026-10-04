extends SceneTree
func _initialize() -> void:
	var sprites=load("res://tests/earth/fixtures/sprite_frames.tres") as SpriteFrames
	var ok=sprites!=null
	var count=0
	if ok:
		for action in ["idle","move","attack","hit","fall"]:
			ok=ok and sprites.has_animation(action) and sprites.get_frame_count(action)==30 and sprites.get_animation_speed(action)==60
			ok=ok and sprites.get_animation_loop(action)==(action in ["idle","move"])
			for i in range(sprites.get_frame_count(action)):
				var tex=sprites.get_frame_texture(action,i) as AtlasTexture
				ok=ok and tex!=null and tex.get_size()==Vector2(432,248) and tex.atlas!=null
				count+=1
	print("EARTH IMPORT VALIDATION ",count," frames: ","PASS" if ok else "FAIL")
	quit(0 if ok else 1)
