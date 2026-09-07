shader_type canvas_item;
render_mode unshaded;

uniform float phase = 0.0;

void fragment() {
	vec4 tint = COLOR;
	vec2 offset = TEXTURE_PIXEL_SIZE * (2.4 + sin(TIME * 3.0 + phase) * 0.35);
	vec4 source = texture(TEXTURE, UV);
	float cyan_edge = texture(TEXTURE, UV - vec2(offset.x, 0.0)).a;
	float magenta_edge = texture(TEXTURE, UV + vec2(offset.x, 0.0)).a;
	float pulse = 0.97 + 0.03 * sin(TIME * 5.0 + phase + UV.y * 18.0);
	vec3 glow = vec3(0.0, 0.92, 1.0) * max(cyan_edge - source.a, 0.0) * 0.65;
	glow += vec3(1.0, 0.0, 0.72) * max(magenta_edge - source.a, 0.0) * 0.55;
	float alpha = max(source.a, max(cyan_edge, magenta_edge) * 0.48);
	COLOR = vec4((source.rgb * pulse + glow) * tint.rgb, alpha * tint.a);
}
