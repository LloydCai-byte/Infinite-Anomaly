extends SceneTree
const G=preload("res://scripts/earth/gait.gd")
const Street=preload("res://scripts/reboot/street_model.gd")
var failures=0
var n=0
func ck(ok:bool,label:String) -> void:
	n+=1
	if not ok:failures+=1;printerr("FAIL "+label)
func _initialize() -> void:
	ck(G.frame(0,315,40)==0,"no movement no phase")
	ck(G.frame(157.5,315,40)==20,"half stride half cycle")
	ck(G.frame(315,315,40)==0,"full cycle wraps")
	ck(G.frame(100,0,40)==0,"invalid stride safe")
	ck(is_equal_approx(G.legacy_cycle("male-heavy",448),624),"scale-dependent stride")
	var a=Street.new();var b=Street.new()
	for i in range(240):a.tick(1.0/60)
	for i in range(120):
		b.tick(1.0/60);b.tick(1.0/60)
	ck(is_equal_approx(a.units[0].move_distance,b.units[0].move_distance),"2x uses same distance and phase")
	var before=a.units[0].move_distance
	a.paused=true;a.tick(1)
	ck(a.units[0].move_distance==before,"pause freezes feet")
	print("EARTH GAIT ",n," checks / ",failures," failures")
	quit(1 if failures else 0)
