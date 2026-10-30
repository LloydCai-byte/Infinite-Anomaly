extends SceneTree
const Gear=preload("res://scripts/pixel_home/gear.gd")
const Battle=preload("res://scripts/pixel_home/battle.gd")
const Cosmos=preload("res://scripts/pixel_home/cosmos.gd")
const Home=preload("res://scripts/pixel_home/home.gd")
class FailingGear extends Gear:
	var fail=false
	func persist() -> bool:
		if fail:last_error="isolated simulated disk failure";return false
		return super.persist()
var checks=[]
var doc="res://docs/hub-cosmos-campaign-20261028/cosmic-loadout-test/"
var definitions:Array
var home
var measurements=[]

func check(ok:bool,label:String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)

func _initialize() -> void:
	if DisplayServer.get_name()=="headless":printerr("Real UI-input suite: omit --headless.");quit(2);return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--home-test-output="):doc=arg.trim_prefix("--home-test-output=").trim_suffix("/")+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(doc));call_deferred("run")

func graduate(g) -> void:
	for id in range(1,301):g.record_level_result(id,3,10,0,90,true)
	check(g.finish_graduation(),"isolated graduation fixture unlocks only after both campaign gates")

func model_for(g):
	var m=Battle.new();m.configure_levels(definitions);m.attach(g);m.reset();m.start();return m

func click(key:String) -> void:
	await process_frame;await process_frame
	var button=home.cosmos_ui.controls[key];var point=button.get_global_rect().get_center()
	var motion=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;root.push_input(motion)
	var event=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;root.push_input(event)
	event=event.duplicate();event.pressed=false;root.push_input(event);await process_frame;await process_frame

func capture(name:String) -> void:
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(doc+name+".png")

func run() -> void:
	definitions=JSON.parse_string(FileAccess.get_file_as_string("res://assets/pixel_campaign/first_two.json")).levels
	var cfg=Cosmos.catalog();check(cfg.skills.size()==5 and cfg.skills.all(func(row):return row.size()==3),"five heroes each have three authored cosmic skills")
	var ids={}
	for row in cfg.skills:
		for skill in row:ids[skill.id]=true
	check(ids.size()==15,"fifteen skills have distinct stable identities")
	var g=Gear.new(77);var original=g.snapshot();check(not g.cosmos.unlocked,"Earth starts with cosmic systems locked")
	check(not g.equip_core(1,0) and not g.choose_cosmic_skill(0,0),"locked preparation cannot equip or activate skills")
	check(g.snapshot()==original,"rejected locked operations do not mutate gear")
	graduate(g)
	check(g.cosmos.inventory.size()==5 and g.cosmos.stardust==10,"graduation grants five starter cores and ten stardust")
	var once=g.cosmos.duplicate(true);Cosmos.unlock(g.cosmos)
	check(g.cosmos==once,"starter package cannot be claimed twice")
	check(g.s==original.state,"unlock preserves every original equipment and progression field")
	check(g.equip_core(1,0) and g.cosmos.slots[0]==1,"core equips to one hero")
	check(g.equip_core(1,2) and g.cosmos.slots[0]==0 and g.cosmos.slots[2]==1,"transfer removes previous owner without duplicating equipment")
	check(not g.salvage_core(1),"equipped cores cannot be salvaged")
	g.equip_core(0,2);g.lock_core(1);check(not g.salvage_core(1),"locked cores cannot be salvaged")
	g.lock_core(1);var dust=g.cosmos.stardust
	check(g.salvage_core(1) and Cosmos.item(g.cosmos,1).is_empty() and g.cosmos.stardust==dust+4,"salvage removes exactly one core and grants correct dust")
	check(not g.salvage_core(1) and g.cosmos.stardust==dust+4,"repeated salvage grants nothing")
	check(not g.upgrade_core(2),"insufficient dust blocks upgrade without spending")
	g.cosmos.stardust=50;var roll=Cosmos.item(g.cosmos,2).roll
	check(g.upgrade_core(2) and Cosmos.item(g.cosmos,2).rank==2 and g.cosmos.stardust==35,"rank two costs fifteen dust")
	check(g.upgrade_core(2) and Cosmos.item(g.cosmos,2).rank==3 and g.cosmos.stardust==0 and Cosmos.item(g.cosmos,2).roll==roll,"rank three costs thirty-five and preserves item roll")
	check(not g.upgrade_core(2),"rank cap rejects further spending")
	check(not g.choose_cosmic_skill(0,1),"alternative skill locked before thirty unique planets")
	for id in range(301,331):g.record_level_result(id,1,10,1,90,true)
	check(g.cosmos.mastery==30 and g.choose_cosmic_skill(0,1) and not g.choose_cosmic_skill(0,2),"thirty distinct planet clears unlock second option only")
	for i in range(20):g.record_level_result(301,1,10,1,90,true)
	check(g.cosmos.mastery==30,"repeating a planet does not inflate mastery")
	for id in range(331,421):g.record_level_result(id,1,10,1,90,true)
	check(g.cosmos.mastery==120 and g.choose_cosmic_skill(0,2),"one hundred twenty unique planets unlock third option")
	g.open_profile(doc+"cosmic-state.json");g.cosmos=once.duplicate(true);g.cosmos.mastery=120;g.cosmos.stardust=60;g.equip_core(2,1);g.choose_cosmic_skill(0,2);g.lock_core(1)
	check(g.persist(),"cosmic inventory, skills and resources save in the existing atomic snapshot")
	var reload=Gear.new(2);reload.open_profile(doc+"cosmic-state.json")
	check(reload.snapshot()==g.snapshot(),"disk reload preserves all old and new equipment exactly")
	var old=g.snapshot();old.erase("cosmos");var save=Gear.Save.new(doc+"before-cosmos.json");save.save(old);var hash_before=FileAccess.get_sha256(save.path)
	var upgraded=Gear.new(3);upgraded.open_profile(doc+"before-cosmos.json")
	check(upgraded.home_migration_backup.contains(".before-cosmos-") and FileAccess.get_sha256(upgraded.home_migration_backup)==hash_before,"0.25 migration makes independent exact pre-cosmos backup")
	check(FileAccess.get_sha256(save.path)==hash_before and upgraded.s==g.s and upgraded.campaign==g.campaign,"migration leaves original file, equipment and campaign intact")
	check(upgraded.cosmos.unlocked and upgraded.cosmos.inventory.size()==5 and upgraded.cosmos.mastery==120,"already-graduated old save receives one coherent starter state")
	var invalid=reload.snapshot();invalid.cosmos.slots=[1,1,0,0,0];var unchanged=reload.snapshot()
	check(not reload.restore(invalid) and reload.snapshot()==unchanged,"duplicate core ownership rejected without partial mutation")
	invalid=reload.snapshot();invalid.cosmos.inventory[0].roll=999
	check(not reload.restore(invalid),"out-of-range core rolls rejected")
	invalid=reload.snapshot();invalid.cosmos.skills[0]=9
	check(not reload.restore(invalid),"invalid skill choices rejected")
	var failed=FailingGear.new(89);graduate(failed);failed.cosmos.stardust=90
	for operation in ["equip","upgrade","lock","salvage","skill"]:
		failed.cosmos.mastery=120;var before=failed.snapshot();failed.fail=true;var ok=false
		match operation:
			"equip":ok=failed.equip_core(1,0)
			"upgrade":ok=failed.upgrade_core(1)
			"lock":ok=failed.lock_core(1)
			"salvage":ok=failed.salvage_core(1)
			"skill":ok=failed.choose_cosmic_skill(0,2)
		check(not ok and failed.snapshot()==before,"failed save atomically rolls back "+operation);failed.fail=false
	var combat=Gear.new(91);graduate(combat);var m=model_for(combat);var basic=m.preview_stats(0)
	combat.equip_core(1,0);var attack=m.preview_stats(0)
	check(attack.atk>basic.atk and attack.elite>basic.elite and attack.hp==basic.hp,"lance trades no defense for real attack and boss damage")
	combat.equip_core(2,0);var tank=m.preview_stats(0)
	check(tank.hp>basic.hp and tank.shield>basic.shield and tank.atk==basic.atk and tank.shield<=tank.hp*.35,"aegis provides actual health and capped shield instead of attack")
	combat.equip_core(4,0);var support=m.preview_stats(0)
	check(support.speed>basic.speed and support.heal>basic.heal and support.atk==basic.atk,"relay increases actual action speed and healing")
	combat.equip_core(0,0);check(m.preview_stats(0)==basic,"unequipping removes every core bonus")
	# Exercise all skill handlers through the real action entry point, not descriptions.
	combat.cosmos.mastery=120;combat.s.level=30
	for hero in range(5):
		for choice in range(3):
			combat.choose_cosmic_skill(hero,choice);m=model_for(combat)
			for enemy in m.units.slice(5):enemy.hp=100000;enemy.max_hp=100000
			for ally in m.units.slice(0,5):ally.hp=roundi(ally.max_hp*.3);ally.charge=ally.uid*.1;m.shields[ally.uid]=0
			if hero==1 and choice==2:m.shields[hero]=200
			for i in range(2):m.action={};m.begin_action(hero)
			check(m.cosmic_triggers[hero]==0,"no early proc: "+cfg.skills[hero][choice].id)
			var hp_before=m.units.map(func(u):return u.hp);var armor_before=m.stats_live[5].armor;var charges=m.units.slice(0,5).map(func(u):return u.charge)
			m.action={};m.begin_action(hero)
			var skill=cfg.skills[hero][choice];var damage=0;var healing=0;var shield=0
			for i in range(5,10):damage+=hp_before[i]-m.units[i].hp
			for i in range(5):healing+=m.units[i].hp-hp_before[i];shield+=m.shields[i]
			var changed=damage>0 or healing>0 or shield>0 or m.units.slice(0,5).map(func(u):return u.charge)!=charges
			check(m.cosmic_triggers[hero]==1 and changed,"third action executes real effect: "+skill.id)
			measurements.append({"skill":skill.id,"damage":damage,"healing":healing,"shield":shield,"charges_before":charges,"charges_after":m.units.slice(0,5).map(func(u):return u.charge)})
			if skill.effect=="break":check(m.stats_live[m.action.target].armor<armor_before,"armor break affects live mitigation: "+skill.id)
			if skill.effect=="shield_all":check(m.shields.slice(0,5).all(func(value):return value>0),"fleet wall protects all five living teammates")
			if skill.effect=="heal_all":check(range(5).all(func(i):return m.units[i].hp>hp_before[i]),"area repair restores all five actual health values")
			if skill.effect=="rescue":check(shield>0 and healing>200,"rescue adds its own large heal and shield beyond normal support")
			if skill.effect=="charge":check(is_equal_approx(m.units[0].charge,charges[0]+.18) and is_equal_approx(m.units[1].charge,charges[1]+.18) and m.units[2].charge==charges[2],"relay advances exactly two lagging teammates by eighteen percent")
			if skill.effect=="shield_strike":check(is_equal_approx(m.shields[hero],100),"counterpressure spends half of actual shield")
			if skill.effect=="freeze":
				check(m.cosmic_chill.size()==5 and m.units[5].agility<m.stats_live[5].speed,"cold trap slows actual enemy ATB speed")
				m.action={};m.begin_action(5);check(not m.cosmic_chill.has(5) and m.units[5].agility==m.stats_live[5].speed,"cold slow clears at next action start")
			m.action={};m.begin_action(hero);check(m.cosmic_triggers[hero]==1,"fourth action cannot retrigger: "+skill.id)
	combat.cosmos.skills=[0,0,0,0,0];m=model_for(combat)
	for enemy in m.units.slice(5):enemy.hp=1000000;enemy.max_hp=1000000;enemy.power=0;m.stats_live[enemy.uid].atk=0
	while m.time<65:m.advance(.25)
	check(m.cosmic_triggers.all(func(count):return count>0),"natural ATB combat triggers every hero's selected cosmic skill")
	m.stats_live[5].armor=m.base_armor[5]*.3;var broken=m.stats_live[5].armor;m.damage(1,5,1,"physical")
	check(m.stats_live[5].armor<=broken,"legacy armor-break branch never restores stronger cosmic armor reduction")
	check(m.units.slice(0,5).all(func(u):return u.hp>0),"natural integration keeps the real five-hero formation alive")
	# Planet fixtures are explicitly isolated surrogates for reward wiring, not authored planet content.
	var planet_defs=definitions.duplicate(true);planet_defs[0].id=301
	m=Battle.new();m.configure_levels(planet_defs);m.attach(combat);m.reset();m.start();m.bridge()
	var enemy=m.gear.b.units[7].duplicate(true);enemy.boss=true
	var inventory_size=combat.cosmos.inventory.size();var dust_before=combat.cosmos.stardust
	combat.reward(enemy)
	check(combat.cosmos.inventory.size()==inventory_size+1 and combat.cosmos.stardust==dust_before+3,"planet boss kill grants real core and three dust")
	check(combat.cosmos.inventory.back().rank==3 and combat.cosmos.inventory.back().origin=="planet:301","planet drops use mastery tier and stable origin")
	m.bridge();combat.cosmos.misses=7;enemy=m.gear.b.units[5].duplicate(true);enemy.boss=false;inventory_size=combat.cosmos.inventory.size();combat.reward(enemy)
	check(combat.cosmos.inventory.size()==inventory_size+1 and combat.cosmos.misses==0,"eighth eligible planet kill guarantees a core and resets pity")
	m.resolve_event({"hits":[],"heals":[]},0,"test")
	check(m.cosmic_run_loot.size()==1 and m.history.any(func(entry):return entry.begins_with("星核入库")),"battle communicates actual core drop")
	m=model_for(combat);m.bridge();enemy=m.gear.b.units[5].duplicate(true);enemy.boss=false
	inventory_size=combat.cosmos.inventory.size();dust_before=combat.cosmos.stardust;combat.reward(enemy)
	check(combat.cosmos.inventory.size()==inventory_size and combat.cosmos.stardust==dust_before,"returning to Earth cannot farm planet resources")
	combat.b={}
	home=Home.new();root.add_child(home);await process_frame;await process_frame
	home.finish_intro();home.close_dialog();home.gear.events=Gear.Events.initial(19);home.gear.campaign=combat.campaign.duplicate(true);home.gear.cosmos=Cosmos.from_campaign(home.gear.campaign);home.gear.cosmos.stardust=60
	while home.gear.story_waiting():home.gear.prepare_story();home.gear.complete_story(home.gear.narrative.pending.id)
	home.open_cosmos();await process_frame
	check(home.mode=="cosmos" and home.cosmos_ui.controls.size()>10,"actual preparation screen opens in home")
	await click("core_1");await click("equip")
	check(home.gear.cosmos.slots[0]==1,"mouse equips actual core")
	await click("hero_2");await click("equip")
	check(home.gear.cosmos.slots[0]==0 and home.gear.cosmos.slots[2]==1,"mouse transfer moves ownership")
	await click("upgrade");check(Cosmos.item(home.gear.cosmos,1).rank==2 and home.gear.cosmos.stardust==45,"mouse upgrade changes rank and currency")
	await click("lock");check(Cosmos.item(home.gear.cosmos,1).locked and home.cosmos_ui.controls.salvage.disabled,"UI locks prevent salvage")
	await click("unequip");await click("lock");await click("salvage")
	check(not Cosmos.item(home.gear.cosmos,1).is_empty(),"first salvage click only requests confirmation")
	await click("salvage");check(Cosmos.item(home.gear.cosmos,1).is_empty() and home.gear.cosmos.stardust==55,"second mouse confirmation salvages once")
	home.gear.cosmos.mastery=120;home.cosmos_ui.refresh();await click("skill_2")
	check(home.gear.cosmos.skills[2]==2,"mouse selects real unlocked skill")
	await click("core_2");await capture("01-cosmic-preparation")
	check(home.cosmos_ui.layer.get_children().filter(func(c):return c is Label).all(func(c):return c.position.x+c.size.x<=1555),"all preparation labels remain inside screen bounds")
	await click("hero_3");await click("skill_1");await capture("02-cosmic-support-skills")
	home.close_cosmos();check(home.mode=="home" and home.ui.visible,"close returns to Xuan's room")
	var ui_snapshot=home.gear.snapshot();var disk=Gear.new(99);disk.open_profile(home.gear.persistence.path)
	check(disk.snapshot()==ui_snapshot,"all mouse actions survive disk reload exactly")
	var failures=checks.filter(func(c):return not c.pass);var file=FileAccess.open(doc+"verification.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"skill_measurements":measurements,"normal_player_save_used":false,"planet_art_produced":false},"\t"));file.close()
	print("COSMIC_LOADOUT %d checks %d failures"%[checks.size(),failures.size()]);home.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
