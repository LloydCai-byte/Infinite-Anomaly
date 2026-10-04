shader_type canvas_item;
render_mode unshaded;
uniform float hurt : hint_range(0.0,1.0) = 0.0;
varying vec4 vertex_modulate;
void vertex() {
	vertex_modulate = COLOR;
}
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float green_excess = source.g - max(source.r, source.b);
	float matte = 1.0 - smoothstep(0.12, 0.50, green_excess);
	vec3 clean = source.rgb;
	clean.g = min(clean.g, max(clean.r, clean.b) + 0.025);
	clean = mix(clean, vec3(1.0, 0.48, 0.4), hurt * 0.45);
	COLOR = vertex_modulate * vec4(clean, source.a * matte);
}
