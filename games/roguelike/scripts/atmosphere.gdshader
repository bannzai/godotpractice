shader_type canvas_item;
// 探索範囲の端に霧と灯火の減衰を重ねる。地形の視界判定は変更しない。
void fragment() {
	vec2 p = UV - vec2(0.5);
	float edge = smoothstep(0.20, 0.65, length(p));
	float mist = sin(UV.x * 18.0 + TIME * 0.22) * sin(UV.y * 13.0 - TIME * 0.16);
	COLOR = vec4(vec3(0.045, 0.105, 0.14), edge * (0.22 + mist * 0.08));
}
