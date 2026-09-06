shader_type canvas_item;
render_mode unshaded;

// 背景の谷に漂う薄霧。画面の読みやすさを保つため最大alphaは0.075。
void fragment() {
	vec2 point = UV;
	float drift = TIME * 0.025;
	float mist = sin(point.x * 10.0 + point.y * 7.0 + drift);
	mist += sin(point.x * 17.0 - point.y * 12.0 - drift * 0.71) * 0.45;
	mist += sin(point.x * 31.0 + point.y * 19.0 + drift * 1.31) * 0.2;
	mist = smoothstep(-1.1, 1.35, mist);
	float valley = smoothstep(0.25, 0.65, point.y) * (1.0 - smoothstep(0.8, 1.0, point.y));
	float shimmer = 0.5 + 0.5 * sin(point.x * 5.0 + TIME * 0.18);
	vec3 tint = mix(vec3(0.35, 0.57, 0.56), vec3(0.83, 0.75, 0.54), shimmer * 0.3);
	COLOR = vec4(tint, (0.018 + mist * 0.057) * valley);
}
