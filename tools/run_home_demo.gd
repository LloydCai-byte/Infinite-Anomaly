extends SceneTree
const Demo=preload("res://scripts/pixel_home/flow_demo.gd")
func _initialize() -> void:call_deferred("start")
func start() -> void:root.add_child(Demo.new())
