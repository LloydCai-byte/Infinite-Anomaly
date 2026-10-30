extends SceneTree
const Home=preload("res://scripts/pixel_home/home.gd")
const Rooms=preload("res://scripts/pixel_home/rooms.gd")
var out="res://docs/feedback-revision-20261028/verification/home-runtime/"
var checks=[]
var home
func check(ok:bool,label:String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--feedback-test-output="):out=arg.trim_prefix("--feedback-test-output=").trim_suffix("/")+"/"
	root.size=Vector2i(1600,900);root.content_scale_size=Vector2i(1600,900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out));call_deferred("run")
func capture(name:String) -> void:
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(out+name+".png")==OK,"capture "+name)
func run() -> void:
	home=Home.new();home.profile_override=ProjectSettings.globalize_path(out+"isolated-%d.json"%Time.get_ticks_usec());root.add_child(home)
	await process_frame;await process_frame;home.finish_intro();home.close_dialog();home.set_process(false)
	var fixed=home.NPCS.duplicate(true);var original_inventory=home.gear.s.inventory.duplicate(true)
	for id in Rooms.IDS:
		home.change_room(id,Rooms.data(id).spawn);home.arrival=0;home.backdrop.tick(0)
		check(home.backdrop.room==id and home.backdrop.sprite.texture.get_width()>1000,id+" actual room image loaded")
		check(home.companions().size()=={"living":3,"work":1,"balcony":1}.get(id,0),id+" room routines stay assigned")
		await capture(id)
		var saved=home.Gear.new();saved.open_profile(home.gear.persistence.path)
		check(saved.home.room==id and Vector2(saved.home.position[0],saved.home.position[1]).is_equal_approx(home.player),id+" saved room and position")
		for entry in Rooms.data(id).objects:
			if entry.has("to"):
				home.player=entry.point;home.interact()
				check(home.current_room==entry.to and home.player.is_equal_approx(entry.spawn),id+" actual door interaction to "+entry.to)
				check(not home.blocked(home.player),id+" doorway collision aligned")
				home.change_room(id,Rooms.data(id).spawn)
			elif id!="living" and entry.id not in ["equipment","relic","work_archive"]:
				home.player=entry.point;home.interact()
				check(home.dialog.visible and not home.dialog_text.text.is_empty(),id+" prop dialogue "+entry.id);home.close_dialog()
	for id in ["living","bedroom","balcony"]:
		home.change_room(id,Rooms.data(id).spawn);home.arrival=0;home.interaction_hint.hide()
		home.backdrop.clock=0;home.backdrop.tick(0);home.queue_redraw();await capture(id+"-wind-0")
		home.backdrop.tick(2);await capture(id+"-wind-2")
	check(home.NPCS==fixed,"all five heroes retain their original fixed positions")
	home.change_room("work",Rooms.data("work").spawn);home.open_overlay("equipment");home.backdrop.tick(0)
	check(not home.backdrop.visible and home.battle.screen=="equipment","room backdrop hides behind equipment overlay")
	home.battle.close_equipment();home._process(0);home.backdrop.tick(0)
	check(home.mode=="home" and home.current_room=="work" and home.backdrop.visible,"equipment closes back to same workroom")
	home.change_room("bedroom",Rooms.data("bedroom").spawn);home.start_intro()
	check(home.current_room=="living" and home.cinematic,"replay from bedroom returns to current pixel living room")
	home.finish_intro();home.close_dialog();home.depart(0);home.backdrop.tick(0)
	check(home.mode=="battle" and not home.backdrop.visible,"battle hides all room imagery")
	home.return_home();check(home.mode=="retreat","retreat confirmation remains usable")
	home.finish_return();home.backdrop.tick(0)
	check(home.mode=="home" and home.current_room=="living" and home.backdrop.room=="living","battle return restores living room")
	check(home.gear.s.inventory==original_inventory,"room navigation and overlays preserve equipment")
	var failed=checks.filter(func(c):return not c.pass)
	var file=FileAccess.open(out+"verification.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failed":failed.size(),"normal_profile_used":false},"  "));file.close()
	print("FEEDBACK_HOME_RUNTIME ",checks.size()," checks, ",failed.size()," failures")
	home.queue_free();await process_frame;quit(0 if failed.is_empty() else 1)
