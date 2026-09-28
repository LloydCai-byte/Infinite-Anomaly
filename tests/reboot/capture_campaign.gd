extends SceneTree
const C=preload("res://scripts/reboot/catalog.gd")
var game: Control
var suffix=""
func _initialize() -> void: call_deferred("run")
func shot(name: String) -> void:
	game.render()
	await process_frame
	await RenderingServer.frame_post_draw
	var path="res://art/reboot-war/captures/"+name+suffix+".png"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	get_root().get_texture().get_image().save_png(path)
func run() -> void:
	suffix="-720p" if "--small" in OS.get_cmdline_user_args() else ""
	root.size=Vector2i(1280,720) if suffix!="" else Vector2i(1600,900)
	game=load("res://scenes/reboot/main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.world.set_process(false);game.transient=true
	game.model.s.intro_done=true;game.model.s.tier=4
	game.model.s.credits=5200;game.model.s.alloy=240
	for d in C.MISSIONS: game.model.s.wins[d.id]=8
	for i in range(4):
		game.model.s.people[i].body=15;game.model.s.people[i].skill=5
		game.model.item(game.model.s.people[i].weapon).level=15;game.model.item(game.model.s.people[i].armor).level=15
		game.model.s.people[i].modules={"reflect":3,"regen":3,"beam":3,"barrier":2};game.model.s.people[i].module="regen"
	game.view="base";game.page=""
	await shot("01-base-t4")
	game.ui.campaign.mission_page=1;game.model.s.selected_mission="M10";game.page="missions"
	await shot("02-missions-late")
	game.ui.campaign.card_page=1;game.page="cards";await shot("03-cards-late")
	game.page="modules";await shot("04-second-ability")
	game.ui.recipe_mk=4;game.page="printer";await shot("05-mk4-printer")
	game.page="graduation";await shot("06-graduation")
	game.ui.campaign.story_id="graduation";game.ui.campaign.story_index=6;game.page="story";await shot("07-room-identity")
	game.page="handoff";game.payload={"confirm":true};await shot("08-handoff")
	game.page="";game.perform("depart","M07")
	for i in range(330): game.model.tick(.05)
	game.world.clock=3;game.model.events.clear();await shot("09-pumps-combat")
	game.model.recall();game.model.s.reveal_read=true;game.perform("graduate")
	var war=game.model.war_model()
	for i in range(320): war.tick(.1)
	game.model.events.clear();game.world.clock=13.5
	await shot("10-war-battle")
	for page in ["war_map","war_rooms","war_formation","war_tech","war_soldiers","war_cards","war_ledger","war_retreat"]:
		game.page=page;await shot("11-"+page)
	war.action("retreat");game.page="war_result";await shot("12-war-retreat-result")
	game.page="war_history";await shot("13-history")
	game.model.s.settings.large=true
	for page in ["war_map","war_rooms","war_tech","war_soldiers"]:
		game.page=page;await shot("14-large-"+page)
	game.model.s.settings.large=false
	# The final ledger uses the saved state of an actually completed campaign.
	var verified="res://.local/war-production/completed-campaign.save"
	if not FileAccess.file_exists(verified): push_error("Run campaign test before final captures");quit(1);return
	game.model.import_state(str_to_var(FileAccess.get_file_as_string(verified)))
	war=game.model.war_model()
	game.page="war_ending";await shot("15-ending")
	game.page="war_cards";await shot("16-all-civilizations")
	game.page="war_soldiers";await shot("18-final-memorial")
	game.page="";war.s.active=true;war.s.stage=7;war.spawn_stage()
	game.world.clock=14;await shot("17-final-battle")
	print("CAMPAIGN_CAPTURE complete",suffix)
	quit()
