extends SceneTree
const Home=preload("res://scripts/pixel_home/home.gd")
const Typography=preload("res://scripts/pixel_home/typography.gd")
const Gear=preload("res://scripts/pixel_home/gear.gd")
var home
var checks=[]
var out="res://docs/feedback-ui-unify-20261030/runtime/"
func check(ok:bool,label:String)->void:
	checks.append({"pass":ok,"name":label})
	if not ok:push_error(label)
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--unify-output="):out=arg.trim_prefix("--unify-output=").trim_suffix("/")+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	root.size=Vector2i(1600,900);root.content_scale_size=Vector2i(1600,900);call_deferred("run")
func shot(name:String)->void:
	if DisplayServer.get_name()=="headless":return
	home.queue_redraw();home.battle.queue_redraw();await process_frame;await process_frame;await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(out+name+".png")==OK,"capture "+name)
func click(button:Button)->void:
	await process_frame
	var p=button.get_global_rect().get_center()
	var move=InputEventMouseMotion.new();move.position=p;move.global_position=p;root.push_input(move)
	for pressed in [true,false]:
		var e=InputEventMouseButton.new();e.position=p;e.global_position=p;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=pressed;root.push_input(e);await process_frame
func inspect_fonts(node:Node)->void:
	if node is Label or node is Button or node is LineEdit:
		check(node.get_theme_font("font")==Typography.regular() or node.get_theme_font("font")==Typography.bold(),"bundled font: "+str(node.get_path()))
	if node is RichTextLabel:check(node.get_theme_font("normal_font")==Typography.regular(),"bundled rich text font")
	for child in node.get_children():inspect_fonts(child)
func glyph_coverage(folder:String,characters:Dictionary)->void:
	for file in DirAccess.get_files_at(folder):
		if file.get_extension() not in ["gd","json"]:continue
		var text=FileAccess.get_file_as_string(folder+"/"+file)
		for i in range(text.length()):
			var code=text.unicode_at(i)
			if code>32 and code!=65279:characters[code]=true
	for child in DirAccess.get_directories_at(folder):glyph_coverage(folder+"/"+child,characters)
func run()->void:
	home=Home.new();home.profile_override=ProjectSettings.globalize_path(out+"isolated-%d.json"%Time.get_ticks_usec());root.add_child(home)
	await process_frame;await process_frame;home.finish_intro();home.close_dialog();home.arrival=0;home.set_process(false)
	var view=home.battle;view.set_process(false);view.sound_enabled=false
	var g=home.gear;var model=view.model
	check(home.font==view.font and home.font==Typography.regular(),"home and battle share same bundled regular font")
	check(view.equipment_ui.title_font==Typography.bold(),"equipment titles use same bundled family bold")
	var characters={}
	for path in ["res://scripts/pixel_home","res://scripts/pixel_hyakki","res://assets/pixel_campaign"]:glyph_coverage(path,characters)
	var missing=[]
	for code in characters:
		if not Typography.regular().has_char(code) or not Typography.bold().has_char(code):missing.append(String.chr(code))
	check(missing.is_empty(),"bundled family covers runtime text corpus: "+str(characters.size())+" unique characters; missing "+str(missing))
	check(not home.replay_button.visible,"no replay opening button after intro")
	await shot("01-home")
	home.open_campaign();await process_frame;await process_frame;var menu=home.campaign_ui
	check(menu.index_label.text=="001" and not menu.title.visible and not menu.detail.visible,"portal shows only room number and no scene or theme names")
	check(not menu.reward.visible and menu.reward.text.is_empty(),"blue-box reward explanation removed")
	check(menu.active_card_ids.size()>0,"actual card rewards remain")
	check(menu.index_label.horizontal_alignment==HORIZONTAL_ALIGNMENT_CENTER and menu.index_label.vertical_alignment==VERTICAL_ALIGNMENT_CENTER,"main room number centered in both axes")
	check(menu.depth_label.horizontal_alignment==HORIZONTAL_ALIGNMENT_CENTER and menu.depth_label.vertical_alignment==VERTICAL_ALIGNMENT_CENTER,"difficulty centered in both axes")
	for i in range(menu.cards.size()):
		var label=menu.cards[i].get_node("RoomNumber")
		check(label.text=="%03d"%menu.card_ids[i] and label.horizontal_alignment==HORIZONTAL_ALIGNMENT_CENTER and label.vertical_alignment==VERTICAL_ALIGNMENT_CENTER,"thumbnail contains centered number only")
	for key in ["minus","plus","previous","next"]:
		var b=menu.controls[key];var symbols=b.get_children().filter(func(c):return c.get_script()==preload("res://scripts/pixel_home/portal_symbol.gd"))
		check(symbols.size()==1 and symbols[0].size.is_equal_approx(b.size),"symbol fills button for geometric centering: "+key)
	check(menu.controls.back.icon_alignment==HORIZONTAL_ALIGNMENT_CENTER and menu.controls.back.vertical_icon_alignment==VERTICAL_ALIGNMENT_CENTER,"home icon centered")
	menu.set_depth(1);await click(menu.controls.plus);check(menu.depth_value==2,"centered plus increments difficulty")
	await click(menu.controls.minus);check(menu.depth_value==1,"centered minus decrements difficulty")
	menu.choose(10);check(menu.start.disabled,"unreached covered room remains locked")
	menu.choose(1);inspect_fonts(home);await shot("02-portal-1600")
	root.size=Vector2i(1280,720);await process_frame;await shot("03-portal-1280");root.size=Vector2i(1600,900);await process_frame
	await click(menu.controls.back);check(home.mode=="home" and home.campaign_ui==null,"portal home icon returns directly home")
	home.depart(0);await process_frame;view.set_process(false);view.paused=true;view.enemy_arrival.active=false
	check(home.mode=="battle" and model.phase=="fight","entered live battle")
	model.damage(0,model.units[5].uid,model.units[5].max_hp+100,"test")
	var gold=g.s.gold;var inventory=g.s.inventory.duplicate(true);var growth=g.growth.duplicate(true);var visits=g.home.visits
	await shot("04-battle")
	await click(view.controls.home)
	check(home.mode=="home" and not view.visible,"battle home button returns on one mouse click")
	check(home.dialog_title.text!="撤回主神空间","no retreat confirmation dialog")
	check(not home.replay_button.is_visible_in_tree(),"replay button does not leak onto return screen")
	check(g.s.gold==gold and g.s.inventory==inventory and g.growth==growth,"direct return retains kill gold equipment and growth")
	check(g.home.visits==visits+1 and g.events.ticket.is_empty(),"direct return consumes trip ticket exactly once")
	var restored=Gear.new(71);restored.open_profile(home.profile_override)
	check(restored.s.gold==gold and restored.s.inventory==inventory and restored.growth==growth,"retained rewards reload from isolated save")
	home.return_home();check(g.home.visits==visits+1,"duplicate home event does not consume another trip")
	home.close_dialog();g.events.pending={};g.persist();home.depart(0);await process_frame;view.set_process(false);view.paused=true
	check(model.scene_index()==0,"unfinished room restarts from first wave")
	# Deny the temporary file using an isolated directory. No normal save is touched.
	var temp_path=home.profile_override+".tmp";DirAccess.make_dir_recursive_absolute(temp_path)
	var ticket=g.events.ticket.duplicate(true);visits=g.home.visits
	await click(view.controls.home)
	check(home.mode=="retreat" and view.paused and home.dialog_title.text=="返家记录未保存","save failure holds battle with explicit retry")
	check(g.events.ticket==ticket and g.home.visits==visits,"failed return preserves ticket and visit count")
	check(not home.replay_button.visible and not home.interaction_hint.visible,"save-failure overlay has no home-only controls")
	DirAccess.remove_absolute(temp_path);home.finish_return()
	check(home.mode=="home" and g.home.visits==visits+1,"retry returns once after storage recovers")
	home.close_dialog();home.arrival=0;home.open_overlay("equipment");await process_frame;inspect_fonts(view.equipment_ui);check(view.equipment_ui.is_visible_in_tree(),"equipment is actually visible");await shot("05-equipment");view.close_equipment();home._process(.001)
	home.open_overlay("growth");await process_frame;inspect_fonts(view.growth_ui);check(view.growth_ui.is_visible_in_tree(),"growth is actually visible");await shot("06-growth")
	view.growth_ui.tab=2;view.growth_ui.refresh();await process_frame;await shot("07-room-records");view.close_growth();home._process(.001)
	var failures=checks.filter(func(row):return not row.pass)
	var f=FileAccess.open(out+"verification.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures,"source_revision":110,"normal_profile_used":false},"\t"));f.close()
	print("UI_UNIFY ",checks.size()," checks ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
