extends SceneTree
const Home=preload("res://scripts/pixel_home/home.gd")
const Rooms=preload("res://scripts/pixel_home/rooms.gd")
const Gear=preload("res://scripts/pixel_home/gear.gd")
const Save=preload("res://scripts/reboot/save_store.gd")
var checks=[]
var out="res://docs/feedback-revision-20261028/verification/rooms/"
func check(ok:bool,label:String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--feedback-test-output="):out=arg.trim_prefix("--feedback-test-output=").trim_suffix("/")+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var home=Home.new();var links=0
	for room in Rooms.IDS:
		home.current_room=room;home.player=Rooms.data(room).spawn;home.build_grid()
		check(not home.blocked(home.player),room+" spawn is walkable")
		check(home.companions().size()=={"living":3,"work":1,"balcony":1}.get(room,0),room+" assigned companions remain in their rooms")
		for entry in home.OBJECTS:
			home.move_to(entry.point)
			check(home.path.size()>0,room+" walkable path to "+entry.id)
			if entry.has("to"):
				links+=1;check(Rooms.data(entry.to).objects.any(func(other):return other.get("to","")==room),room+" reciprocal door to "+entry.to)
				var visitor=Home.new();visitor.current_room=entry.to
				check(not visitor.blocked(entry.spawn),room+" doorway arrival in "+entry.to+" is unobstructed");visitor.free()
	check(links==12,"six physical connections, no passage through private rooms")
	var gear=Gear.new(51);var old=gear.snapshot();old.home.erase("room")
	var profile=out+"legacy-030.json";var save=Save.new(profile);check(save.save(old),"isolated 0.30 fixture saved")
	var hash=FileAccess.get_sha256(save.path);var migrated=Gear.new();migrated.open_profile(profile)
	check(migrated.home.room=="living" and FileAccess.get_sha256(save.path)==hash,"old profile defaults to living without writing source")
	check(FileAccess.get_sha256(migrated.home_migration_backup)==hash,"pre-room migration preserves exact old snapshot")
	for room in Rooms.IDS:
		migrated.home.room=room;var point=Rooms.data(room).spawn;migrated.home.position=[point.x,point.y]
		check(migrated.persist(),room+" position saves")
		var reloaded=Gear.new();reloaded.open_profile(profile)
		check(reloaded.home.room==room and reloaded.home.position==migrated.home.position,room+" position round trip")
	var invalid=migrated.snapshot();invalid.home.room="unknown";var before=migrated.snapshot()
	check(not migrated.restore(invalid) and migrated.snapshot()==before,"unknown room rejected atomically")
	home.free();var failed=checks.filter(func(c):return not c.pass)
	var file=FileAccess.open(out+"data-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failed":failed.size()},"  "));file.close()
	print("FEEDBACK_ROOMS ",checks.size()," checks, ",failed.size()," failures");quit(0 if failed.is_empty() else 1)
