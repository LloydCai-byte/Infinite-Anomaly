extends SceneTree
const Store=preload("res://scripts/reboot/save_store.gd")
var game: Control
var checks=0
var failures=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;printerr("WAR PERSIST FAIL: "+label)
func advance(seconds: float) -> void:
	for i in range(ceili(seconds/.1)): game.model.tick(.1);game.model.events.clear()
func _initialize() -> void: call_deferred("run")
func run() -> void:
	game=load("res://scenes/reboot/main.tscn").instantiate();root.add_child(game);game.set_process(false)
	var args=OS.get_cmdline_user_args()
	var oracle=Store.new("user://war-oracle.json")
	if "write" in args:
		check(game.model.import_state(str_to_var(FileAccess.get_file_as_string("res://.local/war-production/graduated-natural.save"))),"load earned graduation state")
		game.slot=3;game.store=game.slot_store(3);advance(40)
		var w=game.model.war_model()
		for a in w.s.army:
			if a.named and a.id=="qiaoyue": w.damage_army(1e9,[a]);break
		w.update_originals()
		check(game.commit(),"save active war and named casualty")
		advance(21.7);check(oracle.save(game.model.s),"write deterministic war oracle")
	elif "read" in args:
		check(game.load_game(3) and game.view=="war","restart routes to war scene")
		check(game.model.s.war.originals[0].status=="阵亡","named casualty survives process restart")
		advance(21.7)
		check(game.model.s.war==oracle.load_primary().war,"army, identities, room clocks, rewards remain bit-identical")
		check(game.model.war_model().conservation(),"restart preserves population accounting")
		game.model.war_model().finish("retreat");check(game.commit(),"save withdrawal")
	elif "again" in args:
		check(game.load_game(3) and game.page=="war_result","withdrawal settlement reloads")
		var dead=game.model.s.war.dead;var before=game.model.s.war.generated
		advance(65)
		check(game.model.s.war.dead==dead and game.model.s.war.originals[0].status=="阵亡","garrison never resurrects casualty")
		check(game.model.s.war.generated>before and game.model.war_model().conservation(),"new generations continue after restart")
	print("WAR_PERSIST ",args,": ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
