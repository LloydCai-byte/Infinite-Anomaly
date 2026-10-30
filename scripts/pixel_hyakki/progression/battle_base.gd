extends "res://scripts/pixel_hyakki/equipped_battle.gd"

var depth = 1
var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/pixel_campaign/progression.json"))
var action_rate = 1.0
var burn_power = {}

func encounter_rating() -> int:
	return 1+scene_index()+int(cfg.encounter.world_offset)*level_index()+int(cfg.encounter.depth_stride)*(depth-1)

func spawn_stage() -> void:
	super.spawn_stage()
	# The superclass constructor calls this override before derived fields init.
	if gear == null:return
	var r = encounter_rating()-1
	for u in units.slice(5):
		u.max_hp = roundi(u.max_hp*pow(1.0+cfg.encounter.hp_step*r,cfg.encounter.hp_exponent))
		u.hp = u.max_hp
		u.power = roundi(u.power*pow(1.0+cfg.encounter.attack_step*r,cfg.encounter.attack_exponent))
	apply_loadout();burn_power = {}

func bridge() -> void:
	super.bridge();gear.rating = encounter_rating()

func begin_action(index:int) -> void:
	var base_speed = [26.0,22.0,25.0,29.0,23.0][index] if index < 5 else [20.0,24.0,16.0,25.0,22.0][index-5]+encounter_tier()
	action_rate = clampf(pow(units[index].agility/base_speed,cfg.combat.animation_speed_exponent),cfg.combat.animation_rate_min,cfg.combat.animation_rate_max)
	super.begin_action(index)

func update_action(dt:float) -> void:
	if not action.is_empty() and action.ranged:units[action.actor].anim_time += dt*(action_rate-1.0)
	super.update_action(dt*action_rate)

func damage(source:int,target:int,amount:int,kind:String) -> void:
	if source >= 0 and kind == "fire":burn_power[target] = maxi(1,roundi(units[source].power*cfg.combat.burn_attack_ratio))
	if kind == "burn":amount = burn_power.get(target,amount)
	super.damage(source,target,amount,kind)
