shader_type canvas_item;
render_mode unshaded;

uniform vec4 mist_tint : source_color = vec4(0.61, 0.81, 0.77, 1.0);
uniform float intensity : hint_range(0.0, 0.3) = 0.085;
uniform float clock = 0.0;

void fragment() {
	vec2 point = UV;
	float ribbons = sin(point.x * 11.0 + sin(point.y * 8.0) + clock * 0.12);
	ribbons += sin(point.x * 5.0 - point.y * 13.0 - clock * 0.09) * 0.6;
	float mist = smoothstep(-0.5, 1.6, ribbons);
	float band = smoothstep(0.25, 0.64, point.y) * (1.0 - smoothstep(0.70, 1.0, point.y));
	float glow = pow(max(0.0, 1.0 - length((point - vec2(0.73, 0.27)) * vec2(1.4, 1.0))), 5.0);
	COLOR = vec4(mist_tint.rgb, (mist * band + glow * 0.7) * intensity);
}
