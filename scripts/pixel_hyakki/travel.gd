extends RefCounted
## The scene changes once, behind an opaque veil. Combat never ticks in transit.
const DURATION=1.2
const LONG_DURATION=1.4
const SWAP=.50
const ARRIVAL=.60
var duration=DURATION
var elapsed=0.0
var previous_image=""
var active=false
var switched=false
var arrived=false
var failed=false
var repeat_level=-1
var previous_header={}
var frozen
var source_model

class FrozenHud extends RefCounted:
	var units=[]
	var action={}
	var ready_queue=[]
	var looks_live=[]
	var captions=[]
	func alive(side:int) -> Array:return units.filter(func(u):return u.side==side and u.hp>0)
	func cosmic_caption(hero:int) -> String:return captions[hero]
	func _init(model) -> void:
		units=model.units.duplicate(true);action=model.action.duplicate(true)
		ready_queue=model.ready_queue.duplicate();looks_live=model.looks_live.duplicate()
		for i in range(5):captions.append(model.cosmic_caption(i) if model.has_method("cosmic_caption") else "")

static func read_header(model) -> Dictionary:
	return {"chapter":model.chapter_id() if model.has_method("chapter_id") else model.level_index()+1,"level":model.level_title(),"index":model.scene_index(),"count":model.scene_count(),"title":model.stage_title(),"finale":model.has_method("is_finale") and model.is_finale(),"room":model.has_method("room_mode") and model.room_mode(),"difficulty":model.get("depth") if model.get("depth")!=null else 1,"enemies":model.alive(1).size(),"cleared":model.phase in ["clear","victory"]}

func begin(model,loop_level:int=-1) -> bool:
	if active or (model.phase!="clear" and not (loop_level>=0 and model.phase=="victory")):return false
	if model.has_method("room_mode") and model.room_mode() and not model.is_level_end():return false
	if loop_level<0 and model.stage>=model.stage_count()-1:return false
	previous_image=str(model.scene_info().image);previous_header=read_header(model);frozen=FrozenHud.new(model)
	source_model=model;repeat_level=loop_level
	duration=LONG_DURATION if model.is_level_end() or model.scene_index()==model.scene_count()-2 or (model.has_method("is_finale") and model.is_finale()) else DURATION
	elapsed=0;switched=false;arrived=false;failed=false;active=true;return true

func tick(dt:float) -> Dictionary:
	var cues={}
	if not active:return cues
	elapsed=minf(duration,elapsed+maxf(0,dt))
	if not switched and not failed and fraction()>=SWAP:
		if repeat_level>=0:
			source_model.reset(repeat_level);source_model.start();switched=true
		else:switched=source_model.advance_stage()
		failed=not switched;cues["switched" if switched else "failed"]=true
	if not arrived and fraction()>=ARRIVAL:arrived=true;cues.arrived=true
	if elapsed>=duration:active=false;source_model=null;cues.finished=true
	return cues

func fraction() -> float:return clampf(elapsed/duration,0,1)
func hud_model(model):return frozen if active and not arrived else model
func header(model) -> Dictionary:return previous_header if active and not arrived else read_header(model)
func image_path(model) -> String:return str(model.scene_info().image) if switched else previous_image
static func phase_blend(a:float,b:float,value:float) -> float:
	var t=clampf((value-a)/(b-a),0,1);return t*t*(3-2*t)
func cover_alpha() -> float:
	var p=fraction();return phase_blend(.36,.48,p)*(1-phase_blend(.54,.66,p))
func actor_alpha(side:int) -> float:
	if side!=0:return 1.0
	return 1-phase_blend(.10,.35,fraction()) if fraction()<SWAP else phase_blend(.66,.94,fraction())
func display_units(model) -> Array:
	var result=(model.units if switched else frozen.units).duplicate(true)
	for unit in result:
		unit.pos=unit.home
		if unit.hp>0:unit.anim="idle";unit.anim_time=0;unit.hit_time=0
	return result

func ring_strength() -> float:
	var p=fraction()
	return phase_blend(0,.12,p)*(1-phase_blend(.95,1,p))
func draw_ground(view,units:Array) -> void:
	var strength=ring_strength()
	for unit in units:
		if unit.side!=0 or unit.hp<=0:continue
		var p=unit.home.round();var radius=48+floorf(sin(fraction()*PI)*8)
		view.draw_ellipse_shadow(p,radius,Color(.14,.48,.53,strength*.30))
		for i in range(32):
			var angle=i*TAU/32;var pos=(p+Vector2(cos(angle)*radius,sin(angle)*radius*.25))/3
			view.draw_rect(Rect2(pos.round()*3-Vector2(3,2),Vector2(6,3)),Color(.57,.78,.76,strength*.84))
		for side in [-1,1]:
			view.draw_rect(Rect2(p+Vector2(side*(radius+9)-2,-5),Vector2(4,10)),Color(.87,.77,.51,strength))
		view.draw_rect(Rect2(p+Vector2(-9,-19),Vector2(18,3)),Color(.87,.77,.51,strength*.8))

func draw_columns(view,units:Array) -> void:
	var p=fraction();var strength=ring_strength()*(1-cover_alpha())
	var rising=phase_blend(0,.30,p) if p<SWAP else 1-phase_blend(.66,1,p)
	for unit in units:
		if unit.side!=0 or unit.hp<=0:continue
		var foot=unit.home.round();var height=view.roster[unit.id].height*view.battle_actor_scale(unit)+12
		var height_now=roundf(height*rising/3)*3
		view.draw_rect(Rect2(foot+Vector2(-31,-height_now),Vector2(62,height_now)),Color(.30,.62,.65,strength*.10))
		for side in [-1,1]:
			view.draw_rect(Rect2(foot+Vector2(side*33-2,-height_now),Vector2(3,height_now)),Color(.52,.78,.76,strength*.50))
		for i in range(5):
			var x=[-24,15,-9,27,3][i];var y=fmod(p*230+i*33,height)
			view.draw_rect(Rect2((foot+Vector2(x,-y)).snapped(Vector2(3,3)),Vector2(3,6)),Color(.81,.78,.57,strength*.85))

func draw_cover(view) -> void:
	var alpha=cover_alpha()
	if alpha<=0:return
	view.draw_rect(Rect2(0,0,1600,900),Color(0,0,0,alpha))

static func sound(landing:bool=false) -> AudioStreamWAV:
	var pcm=PackedByteArray();var rate=22050;var length=.28 if landing else .38
	for i in range(int(rate*length)):
		var t=float(i)/rate;var f=t/length;var envelope=sin(PI*f)*pow(1-f,1.4)
		var phase=TAU*((310*t-210*t*t) if landing else (150*t+260*t*t))
		var wave=(sin(phase)*.72+sin(phase*1.5)*.20+sin(phase*.5)*.08)*envelope*.25
		var sample=clampi(roundi(wave*32767),-32768,32767);pcm.append(sample&255);pcm.append((sample>>8)&255)
	var wav=AudioStreamWAV.new();wav.format=AudioStreamWAV.FORMAT_16_BITS;wav.mix_rate=rate;wav.data=pcm;return wav
