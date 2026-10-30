extends RefCounted
## Approved content is added explicitly. Planned rows never generate playable levels.
const REGISTRY="res://assets/pixel_campaign/content_registry.json"
const BASE="res://assets/pixel_campaign/first_two.json"
const FINALE_REGISTRY="res://assets/pixel_campaign/finale_registry.json"
const CLIPS=["idle","walk","attack","hurt","die"]
const ROLES={"melee":"kappa","heavy":"oni","ranged":"tengu","flame":"wang"}
static var image_sizes:Dictionary={}

static func number(value:Variant,minimum:float,maximum:float,whole:bool=false) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=minimum and value<=maximum and (not whole or floorf(value)==value)

static func asset(path:Variant) -> bool:
	return path is String and path.begins_with("res://") and not ".." in path and not "\\" in path and path.get_extension().to_lower() in ["png","webp"] and FileAccess.file_exists(path)

static func image_size(path:String) -> Vector2i:
	if not image_sizes.has(path):
		var image=Image.load_from_file(path);image_sizes[path]=Vector2i.ZERO if image==null else image.get_size()
	return image_sizes[path]

static func text_ok(value:Variant) -> bool:return value is String and not value.strip_edges().is_empty()

static func validate_pack(value:Variant,finale:bool=false) -> Dictionary:
	var fail=func(message):return {"ok":false,"error":message,"files":[]}
	if not value is Dictionary or value.get("schema")!=1:return fail.call("内容包版本无效")
	if not value.get("level") is Dictionary or not value.get("enemies") is Dictionary or not value.get("visuals") is Dictionary:return fail.call("缺少关卡、敌人或动画资料")
	var level=value.level
	if not number(level.get("id"),601 if finale else 3,601 if finale else 600,true):return fail.call("关卡编号无效，不能覆盖前两关")
	if not text_ok(level.get("title")) or not text_ok(level.get("world_key")):return fail.call("缺少关卡标题或稳定标识")
	if level.get("phase")!=("finale" if finale else "cosmos" if level.id>300 else "earth"):return fail.call("篇章与关卡编号不匹配")
	if not number(level.get("rating_base"),1,10000,true):return fail.call("缺少有效战斗强度基准")
	if not level.get("scenes") is Array or level.scenes.size()!=(4 if finale else 10):return fail.call("场景数量无效")
	var files=[];var scene_ids={}
	for scene in level.scenes:
		if not scene is Dictionary or not text_ok(scene.get("id")) or not text_ok(scene.get("title")):return fail.call("场景标识或标题缺失")
		if scene_ids.has(scene.id):return fail.call("场景标识重复")
		scene_ids[scene.id]=true
		if not asset(scene.get("image")):return fail.call("场景图片缺失")
		var size=image_size(scene.image)
		if size.x<320 or size.y<180 or absf(float(size.x)/size.y-16.0/9.0)>.08:return fail.call("场景须为有效的16:9横版图片")
		files.append(scene.image)
		if not scene.get("enemies") is Array or scene.enemies.size()!=5:return fail.call("每景需要五个敌人位置")
		for id in scene.enemies:
			if not id is String or not value.enemies.has(id):return fail.call("场景引用了未定义敌人")
		if not scene.get("boss_slots",[]) is Array:return fail.call("首领位置无效")
		if finale and scene.get("boss_slots",[]).size()!=1:return fail.call("中枢每战须有一位首领")
		var bosses={}
		for slot in scene.get("boss_slots",[]):
			if not number(slot,0,4,true) or bosses.has(int(slot)):return fail.call("首领位置须为不重复的0—4")
			bosses[int(slot)]=true
	for id in value.enemies:
		var enemy=value.enemies[id]
		if not text_ok(id) or not enemy is Dictionary or not text_ok(enemy.get("name")) or not text_ok(enemy.get("skill")):return fail.call("敌人名称或动作名称缺失")
		if enemy.get("role") not in ROLES or not value.visuals.has(enemy.get("visual","")):return fail.call("敌人战斗类型或独立外观无效")
		if not number(enemy.get("hp_base"),1,1000000) or not number(enemy.get("attack_base"),1,100000):return fail.call("敌人基础生命/攻击无效")
		if not number(enemy.get("speed"),1,100) or not number(enemy.get("armor"),0,10000) or not number(enemy.get("resist"),0,65):return fail.call("敌人速度或防御参数无效")
	for id in value.visuals:
		var visual=value.visuals[id]
		if not text_ok(id) or not id.begins_with("alien_") and not id.begins_with("enemy_"):return fail.call("独立外观标识须以alien_或enemy_开头")
		if not visual is Dictionary:return fail.call("外观资料无效")
		for field in ["size","foot"]:
			if not visual.get(field) is Array or visual[field].size()!=2:return fail.call("角色画布或锚点无效")
		if not number(visual.size[0],160,160) or not number(visual.size[1],144,144) or not number(visual.foot[0],80,80) or not number(visual.foot[1],128,128):return fail.call("角色须使用160×144画布及统一脚底锚点")
		if not visual.get("giant") is bool or not number(visual.get("height"),48,120,true):return fail.call("角色身高或巨型标记无效")
		if not visual.giant and visual.height>84:return fail.call("普通生物比例不得超过角色尺寸范围，巨型生物须明确标记")
		if not asset(visual.get("portrait")) or image_size(visual.portrait)==Vector2i.ZERO:return fail.call("敌人头像缺失或无法解码")
		files.append(visual.portrait)
		if not visual.get("clips") is Dictionary:return fail.call("缺少动画集合")
		for clip in CLIPS:
			var data=visual.clips.get(clip)
			if not data is Dictionary:return fail.call("缺少动画："+clip)
			if not number(data.get("frames"),1,1000,true) or not number(data.get("columns"),1,32,true) or not number(data.get("fps"),1,120):return fail.call("动画帧数、列数或帧率无效")
			if not asset(data.get("path")):return fail.call("动画图片缺失："+clip)
			var size=image_size(data.path);var required=Vector2i(int(data.columns)*160,ceili(float(data.frames)/float(data.columns))*144)
			if size!=required:return fail.call("动画图集尺寸与帧资料不匹配："+clip)
			files.append(data.path)
	return {"ok":true,"error":"","files":files}

static func load_campaign(registry_path:String=REGISTRY,allow_test_content:bool=false) -> Dictionary:
	image_sizes.clear()
	var base=JSON.parse_string(FileAccess.get_file_as_string(BASE))
	var result={"levels":base.levels.duplicate(true),"visuals":{},"files":[registry_path],"errors":[]}
	var registry=JSON.parse_string(FileAccess.get_file_as_string(registry_path)) if FileAccess.file_exists(registry_path) else null
	if not registry is Dictionary or registry.get("schema")!=1 or not registry.get("packs") is Array:
		result.errors.append("关卡目录格式无效");return result
	var ids={1:true,2:true};var worlds={"hyakki":true,"sleepbeast":true}
	var reserved=["fenfen","gao","qiqi","dadong","wang","tengu","umbrella","oni","kappa","wheel"]
	for path in registry.packs:
		if not path is String or not FileAccess.file_exists(path):result.errors.append("内容包文件缺失");continue
		var pack=JSON.parse_string(FileAccess.get_file_as_string(path));var validation=validate_pack(pack)
		if not validation.ok:result.errors.append(path+": "+validation.error);continue
		if pack.get("test_only",false) and not allow_test_content:result.errors.append(path+": 测试替身不能发布到正常战役");continue
		var level=pack.level.duplicate(true);var conflict=ids.has(int(level.id)) or worlds.has(level.world_key)
		for id in pack.visuals:
			if id in reserved or result.visuals.has(id):conflict=true
		if conflict:result.errors.append(path+": 编号、世界或外观标识重复");continue
		ids[int(level.id)]=true;worlds[level.world_key]=true
		level.id=int(level.id);level.campaign_id=level.id;level.enemy_catalog=pack.enemies.duplicate(true)
		for scene in level.scenes:scene.boss_slots=scene.get("boss_slots",[]).map(func(slot):return int(slot))
		result.levels.append(level);result.visuals.merge(pack.visuals.duplicate(true));result.files.append(path);result.files.append_array(validation.files)
	result.levels.sort_custom(func(a,b):return a.id<b.id)
	return result

static func load_finale(registry_path:String=FINALE_REGISTRY,allow_test_content:bool=false) -> Dictionary:
	image_sizes.clear()
	var result={"level":{},"visuals":{},"files":[registry_path],"errors":[],"available":false}
	var registry=JSON.parse_string(FileAccess.get_file_as_string(registry_path)) if FileAccess.file_exists(registry_path) else null
	if not registry is Dictionary or registry.get("schema")!=1 or not registry.get("pack") is String:
		result.errors.append("中枢目录格式无效");return result
	if registry.pack=="":return result
	if not FileAccess.file_exists(registry.pack):result.errors.append("中枢内容缺失");return result
	var pack=JSON.parse_string(FileAccess.get_file_as_string(registry.pack));var validation=validate_pack(pack,true)
	if not validation.ok:result.errors.append(validation.error);return result
	if pack.get("test_only",false) and not allow_test_content:result.errors.append("测试中枢不能发布到正常战役");return result
	var level=pack.level.duplicate(true);level.source_theme=601;level.id=2001;level.campaign_id=2001;level.enemy_catalog=pack.enemies.duplicate(true)
	for scene in level.scenes:scene.boss_slots=scene.boss_slots.map(func(slot):return int(slot))
	result.level=level;result.visuals=pack.visuals.duplicate(true);result.files.append(registry.pack);result.files.append_array(validation.files);result.available=true
	return result
