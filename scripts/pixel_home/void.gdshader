shader_type canvas_item;
render_mode unshaded;
uniform float flow_time=0.0;
void fragment(){
	// Coarse dark bands flow slowly beneath the opaque room; no stars or particles.
	vec2 p=floor(UV*vec2(200.0,112.0))/vec2(200.0,112.0);
	float a=sin(p.y*12.0+p.x*4.0+flow_time*0.12);
	float b=sin(p.x*9.0-p.y*3.0-flow_time*0.08);
	float v=floor(clamp(0.50+a*0.22+b*0.17,0.0,1.0)*7.0)/7.0;
	COLOR=vec4(mix(vec3(0.018,0.023,0.036),vec3(0.062,0.071,0.092),v),1.0);
}
