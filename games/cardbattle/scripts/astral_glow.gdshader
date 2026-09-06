shader_type canvas_item;
render_mode unshaded;

// 加算光と緩やかな帯だけを描き、GL Compatibility / WebGL 2 で同じ計算を使う。
void fragment() {
	vec2 point = UV - vec2(0.72, 0.36);
	float halo = exp(-dot(point * vec2(1.0, 1.5), point * vec2(1.0, 1.5)) * 7.0);
	float ribbon = pow(max(0.0, 1.0 - abs(sin(UV.x * 3.0 + UV.y * 5.0 + TIME * 0.08)) * 1.4), 4.0);
	COLOR = vec4(vec3(0.23, 0.65, 0.72), halo * ribbon * 0.07);
}
