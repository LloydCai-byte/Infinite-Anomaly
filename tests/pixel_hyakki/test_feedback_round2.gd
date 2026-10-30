extends SceneTree
const Home=preload("res://scripts/pixel_home/home.gd")
const Rooms=preload("res://scripts/pixel_home/rooms.gd")
const Hud=preload("res://scripts/pixel_hyakki/battle_hud.gd")
var out="res://docs/feedback-round2-20261028/verification/"
var home
var checks=[]
func check(ok:bool,label:String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--round2-output="):out=arg.trim_prefix("--round2-output=").trim_suffix("/")+"/"
	root.size=Vector2i(1600,900);root.content_scale_size=Vector2i(1600,900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out));call_deferred("run")
func shot(name:String) -> Image:
	home.queue_redraw();home.battle.queue_redraw();await process_frame;await process_frame;await RenderingServer.frame_post_draw
	var im=root.get_texture().get_image();im.save_png(out+name+".png");return im
func run() -> void:
	home=Home.new();home.profile_override=ProjectSettings.globalize_path(out+"isolated.json");root.add_child(home)
	await process_frame;await process_frame;home.finish_intro();home.close_dialog();home.set_process(false)
	var original=home.gear.s.inventory.duplicate(true)
	for id in Rooms.IDS:
		home.change_room(id,Rooms.data(id).spawn);home.arrival=0;home.backdrop.tick(0);home.interaction_hint.hide()
		check(not home.blocked(home.player),id+" spawn walkable")
		check(home.companions().size()=={"living":3,"work":1,"balcony":1}.get(id,0),id+" heroes have room routines; Xuan moves")
		check(home.backdrop.sprite.texture.get_image().get_pixel(0,0).a<=.01,id+" exterior alpha at most 1 percent reveals shared void")
		await shot("room-"+id)
		for entry in home.OBJECTS:
			home.move_to(entry.point);check(home.path.size()>0,id+" path to "+entry.id)
			if entry.has("to"):
				home.player=entry.point;home.interact();check(home.current_room==entry.to and home.player.is_equal_approx(entry.spawn),id+" door to "+entry.to)
				home.change_room(id,Rooms.data(id).spawn);home.close_dialog()
	check(not Rooms.data("bedroom").objects.any(func(p):return p.id=="bed_window"),"removed bedroom window has no ghost interaction")
	home.change_room("living",Rooms.data("living").spawn);home.arrival=0;home.player=Vector2(800,740);home.path=PackedVector2Array([Vector2(1100,740)])
	var initial=home.player
	for i in range(10):home._process(.05)
	check(is_equal_approx(home.player.distance_to(initial),180.0),"click walking now 360 px/s, exactly twice prior speed")
	for i in range(40):home._process(.016)
	check(home.player.distance_to(Vector2(1100,740))<6,"faster navigation stops at destination without oscillation")
	home.player=Vector2(420,560);home.move_checked(Vector2(-400,0))
	check(not home.blocked(home.player) and home.player.x>270,"large movement subdivided and cannot tunnel through sofa")
	home.change_room("work",Rooms.data("work").spawn);home.arrival=0;home.backdrop.tick(0)
	home.open_overlay("equipment");home.backdrop.tick(0)
	check(home.backdrop.visible and home.battle.get_meta("home_backdrop",false),"equipment floats over actual workroom")
	var ui=home.battle.equipment_ui;check(ui.r(54,190,449,714).position.x>100 and ui.r(1168,190,449,714).end.x<1500,"equipment leaves visible room margin")
	await shot("equipment-home")
	ui.controls.hero_4.pressed.emit();check(ui.hero==4,"floating tabs usable")
	ui.controls.back.pressed.emit();home._process(0);home.backdrop.tick(0)
	check(home.mode=="home" and home.current_room=="work","close overlay returns to same room and position")
	check(home.gear.s.inventory==original,"UI and room visits preserve inventory")
	home.change_room("living",Rooms.data("living").spawn);home.arrival=0;home.backdrop.tick(0);home.open_overlay("equipment");home.backdrop.tick(0);await shot("equipment-living")
	home.battle.close_equipment();home._process(0)
	home.change_room("living",Rooms.data("living").spawn);home.depart(0);home.backdrop.tick(0)
	var view=home.battle;var model=view.model;view.set_process(false);view.paused=true
	await shot("battle-hyakki")
	for charge in [0.0,1.0,.5]:
		for unit in model.units:unit.charge=charge
		var entries=Hud.timeline_layout(model);var valid=entries.size()==10
		for i in range(entries.size()):
			valid=valid and entries[i].rect.position.x>=918 and entries[i].rect.end.x<=1536 and entries[i].y==67
			if i>0:valid=valid and not entries[i].rect.intersects(entries[i-1].rect)
		check(valid,"all ten enemies and allies share one nonoverlapping rail at "+str(charge))
	model.units[9].hp=0;check(Hud.timeline_layout(model).size()==9,"dead actor disappears from shared timeline")
	view.begin_level(1);view.paused=true;await shot("battle-sleeping-beast")
	check(view.ChapterHud.theme(view.travel.read_header(model)).marker=="claw","second chapter has separate motif")
	view.begin_level(0);view.paused=true;model.stage=3;model.spawn_stage();model.finish("clear");view.advance_selected()
	var stage=model.stage;var clock=model.time
	view.paused=false;view._process(view.travel.duration*.1);view._process(view.travel.duration*.1);view._process(view.travel.duration*.1);view._process(view.travel.duration*.1);view._process(view.travel.duration*.1)
	check(model.stage==stage+1 and view.travel.cover_alpha()==1 and model.time==clock,"single background swap only at full black; combat frozen")
	var covered=await shot("fade-black")
	check(covered.get_pixel(800,450).r==0 and covered.get_pixel(80,50).r==0 and covered.get_pixel(1100,70).r==0 and covered.get_pixel(600,870).r==0,"black screen covers text and interface as well as scene")
	view.paused=true;var fraction=view.travel.fraction();view._process(.1);check(view.travel.fraction()==fraction,"pause freezes black transition")
	view.open_equipment();await shot("equipment-battle");view._process(.1)
	check(view.travel.fraction()==fraction and view.screen=="equipment","equipment remains accessible and freezes fade")
	view.close_equipment();view.paused=false
	for i in range(12):view._process(.05)
	check(not view.travel.active and model.time>clock,"combat resumes after fade")
	view.begin_level(0);view.paused=true;root.size=Vector2i(1280,720);view.open_equipment();await shot("equipment-1280")
	view.close_equipment();await shot("battle-1280")
	var failed=checks.filter(func(c):return not c.pass)
	var file=FileAccess.open(out+"verification.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failed":failed.size(),"normal_profile_used":false},"  "));file.close()
	print("ROUND2 ",checks.size()," checks, ",failed.size()," failures");home.queue_free();await process_frame;quit(0 if failed.is_empty() else 1)
