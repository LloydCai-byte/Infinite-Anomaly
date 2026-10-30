extends SceneTree
const Home=preload("res://scripts/pixel_home/home.gd")
const Rooms=preload("res://scripts/pixel_home/rooms.gd")
var out="res://docs/home-life-20261029/verification/"
var home
var checks=[]
func check(ok:bool,label:String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
func _initialize() -> void:
	root.size=Vector2i(1600,900);root.content_scale_size=Vector2i(1600,900)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--feedback-test-output="):out=arg.trim_prefix("--feedback-test-output=").trim_suffix("/")+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out));call_deferred("run")
func shot(name:String) -> void:
	if DisplayServer.get_name()=="headless":return
	home.queue_redraw();await process_frame;await process_frame;await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(out+name+".png")==OK,"GPU capture "+name)
func run() -> void:
	home=Home.new();home.profile_override=ProjectSettings.globalize_path(out+"isolated-%d.json"%Time.get_ticks_usec());root.add_child(home)
	await process_frame;await process_frame;home.finish_intro();home.close_dialog();home.set_process(false)
	var inventory=home.gear.s.inventory.duplicate(true)
	var expected={"living":["fenfen","qiqi","wang"],"balcony":["gao"],"work":["dadong"]}
	for room in Rooms.IDS:
		home.change_room(room,Rooms.data(room).spawn);home.arrival=0;home.backdrop.tick(0)
		check(home.companions().map(func(n):return n.id)==expected.get(room,[]),room+" companion allocation")
		check(not home.blocked(home.player),room+" spawn remains usable")
		for entry in home.OBJECTS:
			home.move_to(entry.point)
			check(not home.path.is_empty(),room+" reachable object "+entry.id)
		for actor in home.companions():
			home.player=Rooms.data(room).spawn;home.move_to(actor.point)
			check(not home.path.is_empty() and not home.blocked(actor.point),actor.id+" reachable talk position")
			home.player=actor.point;home.interact()
			check(home.dialog.visible and home.dialog_title.text==actor.name,actor.id+" actual interaction selects intended companion")
			home.close_dialog()
			var frames_seen={}
			for i in range(240):frames_seen[home.life.frame_index(actor.id,float(i)/30.0)]=true
			check(frames_seen.size()==4,actor.id+" all four authored poses play")
			check(home.blocked(actor.foot),actor.id+" occupied space blocks player")
		if expected.has(room):
			home.player=Rooms.to_screen(room,{"living":Vector2(890,665),"work":Vector2(720,555),"balcony":Vector2(800,640)}[room])
			home.path=PackedVector2Array();home.interaction_hint.hide()
			for t in [0.0,2.9,4.8]:
				home.life_clock=t;await shot(room+"-"+str(t).replace(".","-"))
	# Two speakers take turns, rather than making synchronized gestures.
	check(home.life.frame_index("qiqi",2)==1 and home.life.frame_index("wang",2)==0,"Qiqi speaks while Wang listens")
	check(home.life.frame_index("qiqi",5)==3 and home.life.frame_index("wang",5)==2,"Wang responds while Qiqi listens")
	home.change_room("living",Vector2(800,740));home.arrival=0;home.backdrop.tick(0)
	home.player=Vector2(800,740);home.move_to(Vector2(980,740));var initial=home.player;var before_clock=home.life_clock
	for i in range(12):home._process(.05)
	check(home.player.x>initial.x+120 and home.life_clock>before_clock,"Xuan walking and NPC animation clocks advance together")
	for direction in range(4):
		home.facing=direction;home.moving=true;home.walk_clock=.2;await shot("xuan-direction-"+str(direction))
	check(home.life.atlas.xuan.frames.size()==36,"four Xuan directions each have eight walk poses and one planted idle")
	# Saved positions from the former NPC layout must remain recoverable.
	for room in expected:
		home.change_room(room,Rooms.data(room).spawn)
		var occupied=home.companions()[0].foot
		home.change_room(room,occupied)
		check(not home.blocked(home.player),room+" occupied saved arrival falls back to clear spawn")
	home.change_room("work",Rooms.data("work").spawn);home.open_overlay("equipment")
	check(home.mode=="overlay" and home.battle.screen=="equipment","new room routine preserves working equipment overlay")
	home.battle.close_equipment();home._process(0)
	check(home.mode=="home" and home.current_room=="work","equipment returns to workroom")
	home.start_intro();home.intro.tick(5.5)
	check(home.cinematic and home.dialog.visible,"opening still plays after room allocation")
	home.finish_intro();check(not home.cinematic and not home.script_walk,"opening skip releases player control")
	check(home.gear.s.inventory==inventory,"home changes preserve equipment data")
	var failed=checks.filter(func(c):return not c.pass)
	var file=FileAccess.open(out+"verification.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failed":failed.size(),"normal_profile_used":false},"  "));file.close()
	print("HOME_LIFE ",checks.size()," checks, ",failed.size()," failures");home.queue_free();await process_frame;quit(0 if failed.is_empty() else 1)
