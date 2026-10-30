extends SceneTree
const Home=preload("res://scripts/pixel_home/home.gd")
var out="res://docs/xuan-motion-20261029/verification/"
var home
var checks=[]
class ScaleLineup extends Node2D:
	var owner_home
	func texture(p:String):return owner_home.texture(p)
	func _draw():
		draw_rect(Rect2(340,630,950,180),Color("263a47"))
		draw_line(Vector2(350,790),Vector2(1280,790),Color("899a94"),1)
		for i in range(4):owner_home.life.draw_actor(self,"xuan",i*9+8,Vector2(400+i*140,790))
		owner_home.life.draw_actor(self,"qiqi",0,Vector2(1000,790))
		owner_home.life.draw_actor(self,"wang",0,Vector2(1160,790))
func check(ok:bool,label:String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
func _initialize() -> void:
	root.size=Vector2i(1600,900);root.content_scale_size=Vector2i(1600,900)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--xuan-output="):out=arg.trim_prefix("--xuan-output=").trim_suffix("/")+"/"
	for folder in ["poses","walk"]:DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out+folder))
	call_deferred("run")
func shot(name:String) -> void:
	if DisplayServer.get_name()=="headless":return
	home.queue_redraw();await process_frame;await process_frame;await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(out+name+".png")==OK,"GPU capture "+name)
func run() -> void:
	home=Home.new();home.profile_override=ProjectSettings.globalize_path(out+"isolated-%d.json"%Time.get_ticks_usec());root.add_child(home)
	await process_frame;await process_frame;home.finish_intro();home.close_dialog();home.set_process(false)
	home.change_room("living",Vector2(840,685));home.arrival=0;home.backdrop.tick(0);home.path.clear();home.interaction_hint.hide()
	var atlas=home.life.atlas.xuan;var sheet=home.texture(home.life.texture_path("xuan")).get_image()
	check(atlas.frames.size()==36 and sheet.get_size()==Vector2i(1440,640),"four complete directions: eight authored walks plus neutral idle")
	check(not atlas.has("direction_heights") and atlas.reference_height==132,"one scale shared across directions, no per-frame height normalization")
	var previous=JSON.parse_string(FileAccess.get_file_as_string(Home.Life.ART+"frames.json")).actors
	for id in ["fenfen","qiqi","wang","gao","dadong"]:check(home.life.atlas[id]==previous[id],id+" original art, anchor and scale preserved")
	var heights=[];var crowns=[]
	for direction in range(4):
		var seen={};var hashes={};var tops=[]
		for c in range(9):
			var index=direction*9+c;var f=atlas.frames[index];var r=f.rect
			var region=sheet.get_region(Rect2i(r[0],r[1],r[2],r[3]));var box=region.get_used_rect()
			# Alpha includes fringe pixels; meaningful crown/body bounds use opaque sprite pixels.
			var low=160;var high=0
			for y in range(160):
				for x in range(160):
					if region.get_pixel(x,y).a>.5:low=mini(low,y);high=maxi(high,y)
			heights.append(high-low+1);tops.append(low)
			check(box.position.x>0 and box.end.x<160 and box.position.y>0 and box.end.y<160,"complete uncropped alpha frame %d"%index)
			check(is_equal_approx(float(f.pivot[0]),80.0) and is_equal_approx(float(f.pivot[1]),146.0),"stable floor anchor frame %d"%index)
			if c<8:
				seen[home.life.player_frame(direction,true,float(c)/18+.0001)]=true
				hashes[region.get_data().hex_encode()]=true
			home.facing=direction;home.moving=c<8;home.walk_clock=float(c)/18+.0001;await shot("poses/%d-%d"%[direction,c])
		check(seen.size()==8 and hashes.size()==8,"direction %d has eight distinct sequential poses"%direction)
		check(tops.max()-tops.min()<=2,"direction %d crown stays within two pixels through walk cycle"%direction)
		check(home.life.player_frame(direction,false,99)==direction*9+8,"direction %d stopped pose has both feet planted"%direction)
		crowns.append(tops[8])
	check(heights.min()>=129 and heights.max()<=136,"actual opaque heights stay in teammate 132px scale: 129..136 incl stepping")
	check(crowns.max()-crowns.min()<=2,"turning keeps crown height stable")
	# Real home movement, not a standalone atlas frame-number test.
	for fps in [30,60,120]:
		home.player=Vector2(760,705);home.path=PackedVector2Array([Vector2(1100,705)]);home.walk_clock=0
		for i in range(fps/2):home._process(1.0/fps)
		check(absf(home.player.x-940)<.02 and absf(home.walk_clock-.5)<.001,"movement and gait agree at %d fps"%fps)
	home.player=Vector2(850,710);home.path.clear();home.walk_clock=.21;home._process(.05)
	check(not home.moving and home.walk_clock==0 and home.life.player_frame(home.facing,home.moving,home.walk_clock)%9==8,"release movement settles to neutral without continuing walk")
	check(is_equal_approx(home.life.player_stride_seconds(6,360),1.0/60),"partial collision travel advances only the distance travelled")
	home.player=Vector2(1030,690);home.path=PackedVector2Array([Vector2(1100,690)]);home.walk_clock=0
	for i in range(20):home._process(1.0/30)
	var wall_position=home.player
	for i in range(5):home._process(1.0/30)
	check(home.player==wall_position and not home.moving and home.walk_clock==0,"blocked chair stops both actual movement and walk playback")
	var initial=home.player;var clock=home.walk_clock
	home.open_overlay("equipment");home._process(.2)
	check(home.player==initial and home.walk_clock==clock,"equipment overlay freezes movement and gait")
	home.battle.close_equipment();home._process(0)
	check(home.mode=="home","equipment returns to home")
	for direction in range(4):
		home.player=Vector2(840,690);home.facing=direction;home.path.clear();home.moving=false;home.walk_clock=0
		await shot("idle-%d"%direction)
	var lineup=ScaleLineup.new();lineup.owner_home=home;home.add_child(lineup);await shot("scale-lineup");lineup.queue_free();await process_frame
	home.player=Vector2(780,760);home.walk_clock=0;home.path=PackedVector2Array([Vector2(970,760),Vector2(970,520),Vector2(780,520),Vector2(780,760)])
	var travelled_directions={}
	for i in range(100):
		home._process(1.0/30);home.interaction_hint.hide()
		if home.moving:travelled_directions[home.facing]=true
		await shot("walk/%03d"%i)
	check(travelled_directions.size()==4 and home.path.is_empty() and home.player.distance_to(Vector2(780,760))<6,"actual room loop completes in all four directions without furniture collision")
	home.path.clear();home._process(.05);await shot("living-final")
	var failed=checks.filter(func(c):return not c.pass)
	var f=FileAccess.open(out+"verification.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failed":failed.size(),"normal_profile_used":false,"version":ProjectSettings.get_setting("application/config/version"),"heights":heights},"  "));f.close()
	print("XUAN_MOTION ",checks.size()," checks, ",failed.size()," failures");home.queue_free();await process_frame;quit(0 if failed.is_empty() else 1)
