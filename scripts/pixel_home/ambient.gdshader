shader_type canvas_item;
render_mode unshaded;
uniform float breeze_time = 0.0;
uniform vec4 cloth_a = vec4(0.0);
uniform vec4 cloth_b = vec4(0.0);
uniform vec4 sunlight = vec4(0.0);
uniform float cloth_pixels = 2.0;

float inside_soft(vec2 uv, vec4 area) {
	if (area.z <= 0.0 || area.w <= 0.0) { return 0.0; }
	vec2 local = (uv - area.xy) / area.zw;
	vec2 edge = smoothstep(vec2(0.0), vec2(0.08), local) * (1.0 - smoothstep(vec2(0.92), vec2(1.0), local));
	return edge.x * edge.y;
}
float curtain(vec2 uv, vec4 area, float phase) {
	float bottom = clamp((uv.y - area.y) / max(area.w, 0.001), 0.0, 1.0);
	return inside_soft(uv, area) * bottom * sin(breeze_time * 0.76 + bottom * 0.35 + phase);
}
void fragment() {
	vec2 source = UV;
	// One coherent, top-anchored cloth motion; no independently shifted strips.
	source.x += (curtain(UV, cloth_a, 0.0) + curtain(UV, cloth_b, 0.4)) * cloth_pixels * TEXTURE_PIXEL_SIZE.x;
	vec4 original = texture(TEXTURE, source);
	float warm = smoothstep(0.06, 0.22, original.r - original.b);
	float bright = smoothstep(0.28, 0.60, original.r);
	float light = inside_soft(UV, sunlight) * warm * bright * sin(breeze_time * 0.28);
	// Generated PNGs can contain near-opaque interiors (253/255) and near-clear
	// exteriors (1/255). Keep the void behind the room, without tinting furniture.
	float alpha = original.a < 0.01 ? 0.0 : (original.a > 0.98 ? 1.0 : original.a);
	COLOR = vec4(original.rgb * (1.0 + light * 0.035), alpha);
}
