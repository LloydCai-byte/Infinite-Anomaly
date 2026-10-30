extends RefCounted
## Deterministic staged opening. No delayed callbacks survive skip/replay.
const VERSION=2
const LINES=[
	["主神空间 · 第一次集合","敲门声停了。粉粉放下袖口，七七与老王也停了话。工作间的打印声，还在继续。"],
	["大东老师（工作间传来的声音）","打印机又吐出了一张纸。轩轩，这次会去哪里？"],
	["轩轩","去地球为你们准备的训练场。我负责打开门，也负责等你们回来。"],
	["七七","阳台外的黑暗……刚才是不是动了一下？"],
	["老王","为什么地球需要我们？为什么连训练里的伤口都是真的？"],
	["轩轩","因为你们将来要面对的东西，不会给第二次机会。现在先学会一起回来。"],
	["高哥（阳台传来的声音）","阳台外面什么也没有。出发的时候叫我，我站最前面。"],
	["粉粉","先从第一扇门开始。至于答案，我们会自己找到。"],
	["轩轩","我会留在这里。你们每次回来，这盏灯都亮着。"]
]
var host
var active=false
var elapsed=0.0
var knocks=0
var door_pulse=0.0
var light_dip=0.0
var shake=Vector2.ZERO
var stage="idle"
var cue_log=[]
var speaker=""
var sound:AudioStreamPlayer

func _init(owner_node) -> void:
	host=owner_node;sound=AudioStreamPlayer.new();sound.volume_db=-16;host.add_child(sound)
	var pcm=PackedByteArray();var noise=RandomNumberGenerator.new();noise.seed=41
	for i in range(11025):
		var t=float(i)/22050.0
		var value=(sin(t*TAU*91)*.65+noise.randf_range(-1,1)*.35)*exp(-t*23)*.5
		var sample=clampi(roundi(value*32767),-32768,32767)
		pcm.append(sample&255);pcm.append((sample>>8)&255)
	var wav=AudioStreamWAV.new();wav.format=AudioStreamWAV.FORMAT_16_BITS;wav.mix_rate=22050;wav.data=pcm;sound.stream=wav

func start() -> void:
	stop();active=true;stage="silence";elapsed=0;knocks=0;cue_log=["fade_in"];speaker=""
	host.close_dialog();host.player=Vector2(1120,760);host.facing=1;host.arrival=1.4
	host.cinematic=true;host.replay_button.text="跳过演出 [Esc]";host.replay_button.show()

func tick(dt:float) -> void:
	if not active:return
	elapsed+=dt;door_pulse=maxf(0,door_pulse-dt*2.6);light_dip=maxf(0,light_dip-dt*1.3)
	shake=Vector2(roundf(sin(elapsed*57)*door_pulse*3),0)
	for time in [1.65,2.45,3.55]:
		if knocks<[1.65,2.45,3.55].find(time)+1 and elapsed>=time:
			knocks+=1;stage="knocking";door_pulse=1;cue_log.append("knock_%d"%knocks)
			if host.battle.sound_enabled:sound.play()
	if elapsed>=4.4 and stage=="knocking":
		stage="light_dip";light_dip=.62;cue_log.append("light_dip")
	if elapsed>=5.4 and stage=="light_dip":
		stage="dialogue";cue_log.append("dialogue")
		host.show_lines(LINES.duplicate(true),host.finish_intro)

func on_line(index:int) -> void:
	if not active:return
	speaker=LINES[index][0]
	if index==2:
		host.move_to(Vector2(850,555));host.script_walk=true;cue_log.append("xuan_walk")
	if index==3:light_dip=.32;cue_log.append("window_flicker")
	if index==8:door_pulse=.65;cue_log.append("home_light")

func stop() -> void:
	active=false;stage="idle";door_pulse=0;light_dip=0;shake=Vector2.ZERO;speaker=""
	if is_instance_valid(sound):sound.stop()
	if is_instance_valid(host):host.script_walk=false;host.path=PackedVector2Array()
