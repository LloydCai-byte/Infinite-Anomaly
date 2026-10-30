extends SceneTree
const Home=preload("res://scripts/pixel_home/home.gd")
const Travel=preload("res://scripts/pixel_hyakki/travel.gd")
var out="res://docs/teleport-transition-20261028/verification/"
var checks=[]
var home
var view
var record=false
var frame_index=0
var trace=[]
func check(ok:bool,label:String) -> void:
	checks.append({"pass":ok,"name":label})
	if not ok:push_error(label)
func _initialize() -> void:
	root.size=Vector2i(1600,900);root.content_scale_size=Vector2i(1600,900)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--teleport-output="):out=arg.trim_prefix("--teleport-output=").trim_suffix("/")+"/"
		if arg=="--record-teleport":record=true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out+"frames/"));call_deferred("run")
func shot(name:String) -> void:
	view.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out+name+".png")
func film() -> void:
	if not record:return
	await shot("frames/%04d"%frame_index);frame_index+=1
func clear_scene(stage:int) -> void:
	view.travel.active=false;view.model.stage=stage;view.model.spawn_stage();view.model.phase="fight";view.paused=false
	for unit in view.model.units.slice(5):view.model.damage(-1,unit.uid,100000000,"test")
	view.model.advance(.02);view.end_clock=0;view.prev_phase=view.model.phase;view.build_controls()
func finish_transport() -> void:
	for i in range(100):
		if not view.travel.active:return
		view._process(.04)
func run() -> void:
	home=Home.new();home.profile_override=ProjectSettings.globalize_path(out+"isolated-%d.json"%Time.get_ticks_usec());root.add_child(home)
	await process_frame;await process_frame;home.finish_intro();home.close_dialog();home.depart(0)
	view=home.battle;view.set_process(false);view.event_audio=false;home.set_process(false)
	clear_scene(3);var model=view.model;var formation=model.units.slice(0,5).map(func(u):return u.home)
	var old_title=model.stage_title();var old_image=model.scene_info().image;var combat_time=model.time;var attacks=model.attacks
	await shot("01-before")
	for i in range(10):await film()
	view.advance_selected();var t=view.travel
	check(t.active and model.stage==3,"request begins teleport without advancing the old scene")
	check(t.duration==1.2,"ordinary teleport lasts 1.2 seconds")
	check(not view.controls.has("next"),"next button cannot be pressed repeatedly in transit")
	view.advance_selected();check(model.stage==3 and t.elapsed==0,"duplicate advance cannot skip or restart")
	check(t.header(model).title==old_title and t.image_path(model)==old_image,"departure retains old title and background")
	var old_hud=view.hud_model();var mutated=old_hud.units[0].hp;model.units[0].hp-=1
	check(old_hud.units[0].hp==mutated,"departure HUD is an independent frozen snapshot");model.units[0].hp+=1
	var swaps=0;var previous_stage=model.stage;var covered=false;var unmoved=true;var frozen_clock=true;var no_early_title=true;var no_early_enemy=true
	for frame in range(29):
		view._process(1.0/24)
		if model.stage!=previous_stage:
			previous_stage=model.stage;swaps+=1;covered=is_equal_approx(t.cover_alpha(),1.0) and t.actor_alpha(0)==0
		if t.active:
			unmoved=unmoved and t.display_units(model).slice(0,5).map(func(u):return u.pos)==formation
			frozen_clock=frozen_clock and model.time==combat_time and model.attacks==attacks
			if not t.arrived:no_early_title=no_early_title and t.header(model).title==old_title and view.hud_model()==old_hud
			if t.fraction()<.76:no_early_enemy=no_early_enemy and t.actor_alpha(1)==0
		trace.append({"time":t.elapsed,"stage":model.stage,"cover":t.cover_alpha(),"hero_alpha":t.actor_alpha(0),"enemy_alpha":t.actor_alpha(1),"arrived":t.arrived})
		if frame in [3,10,14,19,25]:await shot("step-%02d"%frame)
		await film()
	check(swaps==1 and model.stage==4,"background and encounter advance exactly once")
	check(covered,"scene replacement occurs only with complete opaque cover and absent heroes")
	check(unmoved,"all five feet stay in approved formation throughout teleport")
	check(frozen_clock,"battle clock and attacks frozen throughout teleport")
	check(no_early_title,"old title and timeline stay frozen until arrival")
	check(no_early_enemy,"next enemies are invisible before reveal")
	check(not t.active and t.header(model).title==model.stage_title(),"arrival finishes with new title")
	check(model.time==combat_time,"arrival frame does not sneak in a combat tick")
	for i in range(12):view._process(1.0/24);await film()
	check(model.time>combat_time,"combat resumes after completed arrival")
	await shot("02-arrived")
	clear_scene(4);view.advance_selected();view._process(.1);view.toggle_pause()
	var paused_at=t.elapsed;var index=model.stage
	for i in range(20):view._process(.1)
	check(t.elapsed==paused_at and model.stage==index,"pause freezes departure and cannot change scene")
	await shot("03-paused-departure")
	view.toggle_pause();view.open_equipment();view._process(.1)
	check(t.elapsed==paused_at,"equipment modal freezes teleport");view.close_equipment()
	while not t.switched:view._process(.04)
	view.toggle_pause();paused_at=t.elapsed;index=model.stage
	for i in range(20):view._process(.1)
	check(t.elapsed==paused_at and model.stage==index,"pause also freezes the covered midpoint")
	await shot("04-paused-covered");view.toggle_pause();finish_transport()
	for multiplier in [1.0,2.0,3.0]:
		clear_scene(2);view.speed=multiplier;view.advance_selected()
		for i in range(10):view._process(.1)
		check(t.active and is_equal_approx(t.elapsed,1.0),"speed %s preserves readable one-second progress"%multiplier)
		finish_transport()
	clear_scene(8);view.advance_selected();check(t.duration==1.5,"boss arrival uses slightly longer staging");finish_transport()
	clear_scene(9);view.repeat_run=false;view.advance_selected();check(t.duration==1.5,"chapter crossing uses longer staging");finish_transport()
	check(model.level_index()==1 and model.scene_index()==0,"chapter crossing arrives at next chapter first scene")
	clear_scene(9);view.repeat_run=true;view.run_start_level=0;view.advance_selected();view.advance_selected()
	check(t.active and model.stage==9 and t.repeat_level==0,"repeat uses covered teleport rather than immediate reset")
	finish_transport();check(model.stage==0 and model.depth==view.selected_depth,"repeat returns to selected chapter without changing difficulty")
	view.repeat_run=false;clear_scene(3);view.advance_selected();view.begin_level(0)
	check(not t.active and model.stage==0,"explicit new departure cancels pending teleport")
	check(not t.begin(model),"live combat cannot enter teleport")
	clear_scene(19);check(not t.begin(model),"final victory has no nonexistent next scene")
	check(view.streams.teleport_out.data.size()>10000 and view.streams.teleport_arrive.data.size()>10000,"two short synthesized transport sounds are bundled in code")
	view.sound_enabled=false;var audio_index=view.audio_index;view.play_sound("teleport_out")
	check(view.audio_index==audio_index,"mute suppresses teleport sound")
	clear_scene(3);view.advance_selected();view._process(.1);view.paused=true;root.size=Vector2i(1280,720);await shot("05-paused-1280")
	home.finish_return();check(not view.travel.active and home.mode=="home","return home cancels transport without stranding actors")
	var failed=checks.filter(func(c):return not c.pass)
	var f=FileAccess.open(out+"verification.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failed,"normal_player_profile_used":false,"frames":frame_index,"trace":trace},"  "));f.close()
	print("TELEPORT ",checks.size()," checks, ",failed.size()," failures")
	home.queue_free();await process_frame;quit(0 if failed.is_empty() else 1)
