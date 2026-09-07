shader_type canvas_item;

uniform vec2 shadow_offset = vec2(-0.012, -0.016);
uniform vec4 shadow_color : source_color = vec4(0.035, 0.02, 0.025, 0.62);

void fragment() {
	vec4 paper = texture(TEXTURE, UV) * COLOR;
	float shadow_alpha = texture(TEXTURE, UV + shadow_offset).a * shadow_color.a;
	vec4 shadow = vec4(shadow_color.rgb, shadow_alpha) * COLOR.a;
	COLOR = paper + shadow * (1.0 - paper.a);
}
