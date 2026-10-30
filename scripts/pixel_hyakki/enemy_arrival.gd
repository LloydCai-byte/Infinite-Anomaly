extends RefCounted
## Presentation clock; combat is held until the new wave has materialized.
const DURATION=.72
var active=false
var elapsed=0.0
func begin()->void:elapsed=0;active=true
func tick(dt:float)->void:
	if not active:return
	elapsed=minf(DURATION,elapsed+maxf(0,dt));active=elapsed<DURATION
func alpha(side:int)->float:
	if not active or side==0:return 1.0
	return smoothstep(.20,.78,elapsed/DURATION)
func draw_ground(view)->void:
	if not active:return
	var t=elapsed/DURATION;var strength=sin(PI*t)
	for unit in view.model.units.slice(5):
		var foot=unit.home;var radius=42+floorf(8*sin(t*PI))
		view.draw_ellipse_shadow(foot,radius,Color(.20,.47,.55,strength*.32))
		for i in range(28):
			var angle=TAU*i/28;var point=(foot+Vector2(cos(angle)*radius,sin(angle)*radius*.26)).snapped(Vector2(3,3))
			view.draw_rect(Rect2(point-Vector2(3,1),Vector2(6,3)),Color(.55,.83,.88,strength))
func draw_columns(view)->void:
	if not active:return
	var t=elapsed/DURATION;var strength=sin(PI*t)
	for unit in view.model.units.slice(5):
		var foot=unit.home;var height=view.roster[unit.get("visual_id",unit.id)].height*view.battle_actor_scale(unit)+10
		var height_now=snappedf(height*(1-smoothstep(.55,1,t)),3)
		view.draw_rect(Rect2(foot-Vector2(29,height_now),Vector2(58,height_now)),Color(.30,.65,.75,strength*.15))
		for side in [-1,1]:view.draw_rect(Rect2(foot+Vector2(side*30,-height_now),Vector2(3,height_now)),Color(.64,.85,.88,strength*.65))
