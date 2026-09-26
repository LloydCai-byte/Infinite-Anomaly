extends Node
var ambient: AudioStreamPlayer
var effect: AudioStreamPlayer
var current = ""
var ending = false

func _ready() -> void:
	if DisplayServer.get_name()=="headless":
		set_process(false)
		return
	ambient=AudioStreamPlayer.new()
	ambient.volume_db=-8
	add_child(ambient)
	effect=AudioStreamPlayer.new()
	effect.volume_db=-5
	add_child(effect)

func _process(_delta: float) -> void:
	var target="home"
	if Journey.started and Journey.s.mode in ["EXPLORE","AUTO"]: target="outside"
	if Journey.started and Journey.s.mode=="ENDING": target="ending"
	if target!=current:
		current=target
		var stream: AudioStreamWAV=load("res://assets/v3/audio/"+target+".wav")
		stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
		stream.loop_end=stream.get_length()*stream.mix_rate
		ambient.stream=stream
		ambient.play()

func cue(id: String) -> void:
	if not is_instance_valid(effect): return
	var path="res://assets/v3/audio/"+id+".wav"
	if ResourceLoader.exists(path):
		effect.stream=load(path)
		effect.play()

func _exit_tree() -> void:
	if is_instance_valid(ambient):
		ambient.stop()
		ambient.stream=null
	if is_instance_valid(effect):
		effect.stop()
		effect.stream=null
