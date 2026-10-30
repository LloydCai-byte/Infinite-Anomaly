extends SceneTree
const Home=preload("res://scripts/pixel_home/home.gd")
const Gear=preload("res://scripts/pixel_home/gear.gd")
const Legacy=preload("res://scripts/pixel_hyakki/progression/gear.gd")
const Save=preload("res://scripts/reboot/save_store.gd")
var doc="res://docs/hub-cosmos-campaign-20261028/"
var checks=[]
var home

func check(ok:bool,label:String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--home-test-output="):doc=arg.trim_prefix("--home-test-output=").trim_suffix("/")+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(doc))
	call_deferred("run")

func run() -> void:
	var profile=doc+"test-home-isolated.json"
	var old=Legacy.new(123);old.s.level=11;old.s.gold=789;old.s.inventory[0].locked=true
	var save=Save.new(profile);check(save.save(old.snapshot()),"write isolated existing growth save")
	var original_hash=FileAccess.get_sha256(save.path)
	var migrated=Gear.new(99);migrated.open_profile(profile)
	check(migrated.s==old.s and migrated.growth==old.growth,"home migration retains every existing gear and growth field")
	check(FileAccess.get_sha256(migrated.home_migration_backup)==original_hash,"exact independent pre-home backup")
	check(FileAccess.get_sha256(save.path)==original_hash,"opening old save does not write it")
	migrated.home.intro_done=true;migrated.home.visits=4;migrated.remember_interaction("fenfen");check(migrated.persist(),"home and inventory save atomically")
	var again=Gear.new(2);again.open_profile(profile)
	check(again.snapshot()==migrated.snapshot(),"disk round trip preserves home, gear and growth")
	var bad=again.snapshot();bad.home.position=[NAN,1.0];var intact=again.snapshot()
	check(not again.restore(bad) and again.snapshot()==intact,"invalid home data rejected without touching equipment")
	var recovered_path=doc+"test-home-recovery.json"
	var recovery_save=Save.new(recovered_path);check(recovery_save.save(old.snapshot()),"recovery fixture saves growth baseline")
	var recovery_hash=FileAccess.get_sha256(recovery_save.path)
	DirAccess.copy_absolute(recovery_save.path,recovery_save.path+".bak")
	var corrupt=FileAccess.open(recovery_save.path,FileAccess.WRITE);corrupt.store_string("not a valid save");corrupt.close()
	var recovery=Gear.new(999);recovery.open_profile(recovered_path)
	check(recovery.s==old.s and FileAccess.get_sha256(recovery.home_migration_backup)==recovery_hash,"backup recovery preserves exact restored legacy snapshot before home migration")
	home=Home.new();root.add_child(home)
	await process_frame;await process_frame
	home.finish_intro();home.player=Vector2(800,740);home.arrival=0
	check(home.gear is Gear,"runtime uses additive home save model")
	check(home.NPCS.size()==5 and home.NPCS.all(func(n):return n.id!="xuan"),"five battle heroes are stationary NPCs, not Xuan")
	var initial=home.player
	var key=InputEventKey.new();key.physical_keycode=KEY_D;key.keycode=KEY_D;key.pressed=true;Input.parse_input_event(key)
	for i in range(12):await process_frame
	key.pressed=false;Input.parse_input_event(key);await process_frame
	check(home.player.x>initial.x,"physical movement controls Xuan")
	check(home.blocked(Vector2(560,520)),"coffee table blocks movement")
	check(home.blocked(Vector2(200,500)),"sofa blocks movement")
	check(home.blocked(home.companions()[0].foot),"seated companion remains inside occupied sofa")
	for obj in home.OBJECTS:
		home.player=Vector2(800,740);home.move_to(obj.point+Vector2(0,32))
		check(home.path.size()>1,"walkable route to "+obj.id)
	home.player=home.companions()[0].point;home.interact()
	check(home.dialog.visible and home.dialog_title.text=="粉粉","Xuan talks to fixed Fenfen")
	home.close_dialog();home.open_overlay("equipment");await process_frame
	check(home.battle.screen=="equipment" and home.mode=="overlay","home opens existing full equipment UI")
	home.battle.close_equipment();await process_frame
	check(home.mode=="home" and not home.battle.visible,"equipment returns to home instead of battle")
	home.open_overlay("growth");await process_frame;home.battle.close_growth();await process_frame
	check(home.mode=="home","growth dossier returns to home")
	var inventory=home.gear.s.inventory.duplicate(true);var visits=home.gear.home.visits
	home.depart(0);await process_frame
	check(home.mode=="battle" and home.battle.model.phase=="fight","black door starts existing first level")
	home.return_home();await process_frame
	check(home.mode=="retreat" and home.battle.paused,"in-battle return pauses and offers withdrawal")
	home.finish_return();await process_frame
	check(home.mode=="home" and home.gear.home.visits==visits+1,"return increments visit only after departure")
	check(home.gear.s.inventory==inventory,"return retains all equipment")
	home.finish_return();check(home.gear.home.visits==visits+1,"duplicate return cannot inflate visits")
	if not home.gear.events.pending.is_empty():home.gear.claim_event();home.event_open=false;home.close_dialog()
	home.depart(1);check(home.battle.model.level_index()==1,"second level remains available");home.finish_return()
	home.player=Vector2(800,740);home.arrival=0
	await process_frame;await process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(doc+"home-runtime.png")
	var failures=checks.filter(func(c):return not c.pass)
	var file=FileAccess.open(doc+"home-verification.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"controlled_character":"xuan","normal_player_save_used":false},"\t"));file.close()
	print("HOME_VERIFICATION %d checks %d failures"%[checks.size(),failures.size()]);home.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
