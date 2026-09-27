shader_type canvas_item;
uniform float strength = 0.22;
void fragment() {
	vec4 base = COLOR;
	float sweep = pow(max(0.0, sin((UV.x+UV.y*0.7)*7.0-TIME*1.1)),12.0);
	vec3 rainbow = 0.5+0.5*cos(6.28318*(UV.x+UV.y+TIME*0.07+vec3(0.0,0.33,0.67)));
	COLOR = vec4(mix(base.rgb,rainbow,strength*sweep),base.a);
}
