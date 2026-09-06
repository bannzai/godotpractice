shader_type canvas_item;

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	float shimmer = sin(UV.x * 15.0 + TIME * 0.22) * sin(UV.y * 11.0 - TIME * 0.13);
	COLOR = vec4(base.rgb * (1.0 + 0.05 * shimmer), base.a);
}
