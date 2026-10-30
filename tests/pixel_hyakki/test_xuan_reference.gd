extends SceneTree
const Home=preload("res://scripts/pixel_home/home.gd")
var out="res://docs/xuan-reference-20261029/verification/"
var home
var checks=[]
func check(ok:bool,label:String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
func _initialize() -> void:
	root.size=Vector2i(1600,900);root.content_scale_size=Vector2i(1600,900)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--xuan-output="):out=arg.trim_prefix("--xuan-output=").trim_suffix("/")+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out+"frames"));call_deferred("run")
func shot(name:String) -> void:
	if DisplayServer.get_name()=="headless":return
	home.queue_redraw();await process_frame;await process_frame;await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(out+name+".png")==OK,"GPU capture "+name)
func run() -> void:
	home=Home.new();home.profile_override=ProjectSettings.globalize_path(out+"isolated-%d.json"%Time.get_ticks_usec());root.add_child(home)
	await process_frame;await process_frame;home.finish_intro();home.close_dialog();home.set_process(false)
	home.arrival=0;home.change_room("living",Vector2(800,740));home.arrival=0;home.backdrop.tick(0);home.interaction_hint.hide()
	var atlas=home.life.atlas.xuan;var sheet=home.texture(home.life.texture_path("xuan")).get_image()
	check(atlas.frames.size()==16 and sheet.get_size()==Vector2i(1024,1536),"all sixteen reference poses loaded from original-size sheet")
	check(sheet.get_pixel(0,0).a==0 and sheet.get_pixel(512,370).a==0,"black background has transparent alpha")
	var original_npcs=home.life.atlas.duplicate(true);original_npcs.erase("xuan")
	var prior=JSON.parse_string(FileAccess.get_file_as_string(Home.Life.ART+"frames.json")).actors;prior.erase("xuan")
	check(original_npcs==prior,"five companion sprite sheets and frame data are unchanged")
	var inventory=home.gear.s.inventory.duplicate(true);var actors=home.companions().duplicate(true)
	for direction in range(4):
		var seen={};var inside=true;var consistent=true
		for i in range(4):
			var index=home.life.player_frame(direction,true,float(i)/12.0+.001);seen[index]=true
			var f=atlas.frames[index];var r=f.rect
			inside=inside and Rect2i(Vector2i.ZERO,sheet.get_size()).encloses(Rect2i(r[0],r[1],r[2],r[3]))
			var height=(r[3]-6)*132.0/atlas.direction_heights[direction]
			consistent=consistent and height>130 and height<=132.01
		check(seen.size()==4 and seen.keys().all(func(index):return int(index/4)==direction),"direction %d selects all four correct row poses"%direction)
		check(inside and consistent,"direction %d complete frames keep stable display height"%direction)
		home.player=Vector2(840,685);home.facing=direction;home.moving=false;home.life_clock=0
		await shot("idle-%d"%direction)
		var begin=Vector2(850,670);var delta=[Vector2(0,1),Vector2(-1,0),Vector2(1,0),Vector2(0,-1)][direction]
		home.player=begin;home.path=PackedVector2Array([begin+delta*140]);home.walk_clock=0
		for i in range(4):
			home._process(1.0/24);home._process(1.0/24);home.interaction_hint.hide()
			await shot("frames/%d-%d"%[direction,i])
		check(home.facing==direction and home.moving and not home.blocked(home.player),"direction %d actual movement and facing work"%direction)
		check(absf(home.player.distance_to(begin)-120)<1,"direction %d walking speed remains 360 pixels per second"%direction)
	check(home.companions()==actors and home.gear.s.inventory==inventory,"appearance update preserves NPC placement and inventory")
	home.moving=false;home.path.clear();home.facing=0;home.player=Vector2(840,685)
	home.open_overlay("equipment");home.battle.close_equipment();home._process(0)
	check(home.mode=="home" and home.player==Vector2(840,685),"equipment closes to the same Xuan location")
	await shot("living-final")
	var failed=checks.filter(func(c):return not c.pass)
	var f=FileAccess.open(out+"verification.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failed":failed.size(),"normal_profile_used":false,"version":ProjectSettings.get_setting("application/config/version")},"  "));f.close()
	print("XUAN_REFERENCE ",checks.size()," checks, ",failed.size()," failures");home.queue_free();await process_frame;quit(0 if failed.is_empty() else 1)
