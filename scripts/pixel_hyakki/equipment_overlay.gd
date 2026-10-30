extends Node2D
var owner_ui
func _process(_dt:float)->void:queue_redraw()
func _draw()->void:
	if owner_ui!=null:owner_ui.draw_icons(self)
