extends RefCounted
## Stable room identifiers are separate from authored theme / image identifiers.
## Room identity and combat rating are intentionally independent.
const ROOMS_PER_PHASE=1000
const THEMES_PER_PHASE=100
const ROOMS_PER_THEME=10
const WAVES=10
const DIFFICULTIES=10
const LAST_ROOM=2000
const SPACE_RATING_STEP=.35

static func rating_base(room:int)->int:
	if room<1 or room>LAST_ROOM:return 0
	# Earth requires ten successful difficulty runs per room; the space story
	# requires one. Match its pressure increase to the smaller earned XP budget.
	return room if room<=ROOMS_PER_PHASE else ROOMS_PER_PHASE+roundi((room-ROOMS_PER_PHASE)*SPACE_RATING_STEP)

static func room_id(source_theme:int,image_index:int) -> int:
	if image_index<0 or image_index>=ROOMS_PER_THEME:return 0
	if source_theme>=1 and source_theme<=100:return (source_theme-1)*10+image_index+1
	if source_theme>=301 and source_theme<=400:return 1000+(source_theme-301)*10+image_index+1
	return 0

static func source(room:int) -> Dictionary:
	if room<1 or room>LAST_ROOM:return {}
	var local=(room-1)%ROOMS_PER_PHASE
	return {"theme":1+int(local/10)+(300 if room>ROOMS_PER_PHASE else 0),"image_index":local%10,"phase":"cosmos" if room>ROOMS_PER_PHASE else "earth"}

static func key(room:int) -> String:return "R%04d"%room

static func id_of(value:String) -> int:
	if value.length()!=5 or not value.begins_with("R") or not value.substr(1).is_valid_int():return 0
	var room=value.substr(1).to_int()
	return room if room>=1 and room<=LAST_ROOM and value==key(room) else 0

static func expand(authored:Array) -> Dictionary:
	var result={"levels":[],"reserve_themes":[],"errors":[]};var used={}
	for original in authored:
		var theme=int(original.get("campaign_id",original.get("id",0)))
		if room_id(theme,0)==0:result.reserve_themes.append(theme);continue
		if not original.get("scenes") is Array or original.scenes.size()!=ROOMS_PER_THEME:
			result.errors.append("主题%d需要十张独立场景图"%theme);continue
		for index in range(ROOMS_PER_THEME):
			var room=room_id(theme,index)
			if used.has(room):result.errors.append("房间编号重复："+key(room));continue
			used[room]=true
			var picture=original.scenes[index];var level=original.duplicate(true)
			level.id=room;level.campaign_id=room;level.room_id=room;level.room_mode=true
			level.source_theme=theme;level.source_image_index=index;level.source_scene_id=picture.id
			level.source_world_key=str(original.get("world_key",{1:"hyakki",2:"sleepbeast"}.get(theme,"L%03d"%theme)))
			level.world_key=key(room);level.title=picture.title;level.phase=source(room).phase
			level.theme_title=original.title;level.scenes=[]
			level.source_rating_base=int(original.get("rating_base",1+5*(theme-1)))
			level.rating_base=rating_base(room)
			for wave in range(WAVES):
				var scene=picture.duplicate(true)
				scene.id=key(room)+"-W%02d"%(wave+1);scene.source_scene_id=picture.id;scene.wave=wave+1
				if scene.has("boss_slots") and wave<WAVES-1:scene.boss_slots=[]
				level.scenes.append(scene)
			result.levels.append(level)
	result.levels.sort_custom(func(a,b):return a.room_id<b.room_id)
	return result
