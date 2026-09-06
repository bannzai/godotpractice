shader_type canvas_item;

// 夜空の薄い光だけを動かし、判定ノーツの輪郭とコントラストを保つ。
void fragment() {
	vec4 sky = texture(TEXTURE, UV);
	float ribbon = exp(-pow((UV.y - 0.30 - 0.06 * sin(UV.x * 7.0 + TIME * 0.12)) * 12.0, 2.0));
	float edge = (1.0 - smoothstep(0.25, 0.95, length(UV - vec2(0.50, 0.35))));
	sky.rgb += vec3(0.025, 0.055, 0.075) * ribbon * edge;
	COLOR = sky;
}
