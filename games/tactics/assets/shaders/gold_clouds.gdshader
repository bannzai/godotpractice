shader_type canvas_item;
render_mode unshaded;

// 大和絵の色を残しつつ、四曲屏風の折り目と和紙、縁取りされたすやり霞を重ねる。
float paper_grain(vec2 point) {
	float fibers = sin(point.x * 913.0 + sin(point.y * 83.0) * 2.1);
	fibers += sin(point.y * 641.0 + point.x * 31.0) * 0.55;
	fibers += sin((point.x + point.y) * 377.0) * 0.25;
	return fibers / 1.8;
}


float cloud_wave(vec2 point, float phase) {
	float broad = sin(point.x * 8.5 + phase) * 0.030;
	float middle = sin(point.x * 19.0 - phase * 0.61) * 0.014;
	float detail = sin(point.x * 41.0 + phase * 0.37) * 0.006;
	return broad + middle + detail;
}


float line_mask(float value, float center, float width) {
	return 1.0 - smoothstep(width, width * 1.9, abs(value - center));
}


void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec2 point = UV;
	float drift = TIME * 0.018;

	// 黄ばみと繊維感をごく薄く乗せ、背景全体を和紙の色へ寄せる。
	float grain = paper_grain(point);
	vec3 paper_tint = vec3(0.96, 0.87, 0.66);
	vec3 color = mix(source.rgb, source.rgb * paper_tint, 0.16);
	color += grain * 0.012;

	// 四曲屏風。折り目の左を暗く、右を明るくして奥行きを出す。
	float fold_distance = min(min(abs(point.x - 0.25), abs(point.x - 0.50)), abs(point.x - 0.75));
	float fold_shadow = 1.0 - smoothstep(0.001, 0.009, fold_distance);
	float fold_light_distance = min(
		min(abs(point.x - 0.254), abs(point.x - 0.504)), abs(point.x - 0.754)
	);
	float fold_light = 1.0 - smoothstep(0.001, 0.006, fold_light_distance);
	color *= 1.0 - fold_shadow * 0.17;
	color += vec3(0.17, 0.12, 0.045) * fold_light;

	// 屏風の上下と画面を横切る霞を、幅の異なる波で細長く作る。
	float top_edge = 0.135 + cloud_wave(point, drift);
	float bottom_edge = 0.845 + cloud_wave(vec2(1.0 - point.x, point.y), drift * 0.73);
	float top_fill = 1.0 - smoothstep(top_edge, top_edge + 0.095, point.y);
	float bottom_fill = smoothstep(bottom_edge - 0.085, bottom_edge, point.y);

	float upper_ribbon = 0.355 + cloud_wave(point, drift * 1.19);
	float lower_ribbon = 0.665 + cloud_wave(vec2(point.x + 0.23, point.y), -drift * 0.91);
	float upper_span = smoothstep(0.02, 0.18, point.x) * (1.0 - smoothstep(0.57, 0.88, point.x));
	float lower_span = smoothstep(0.38, 0.62, point.x) * (1.0 - smoothstep(0.91, 1.0, point.x));
	float upper_fill = line_mask(point.y, upper_ribbon, 0.027) * upper_span;
	float lower_fill = line_mask(point.y, lower_ribbon, 0.024) * lower_span;

	float cloud_fill = clamp(top_fill + bottom_fill + upper_fill + lower_fill, 0.0, 1.0);
	float cloud_outline = line_mask(point.y, top_edge + 0.094, 0.004);
	cloud_outline += line_mask(point.y, bottom_edge - 0.084, 0.004);
	cloud_outline += line_mask(point.y, upper_ribbon - 0.052, 0.003) * upper_span;
	cloud_outline += line_mask(point.y, upper_ribbon + 0.052, 0.003) * upper_span;
	cloud_outline += line_mask(point.y, lower_ribbon - 0.047, 0.003) * lower_span;
	cloud_outline += line_mask(point.y, lower_ribbon + 0.047, 0.003) * lower_span;
	cloud_outline = clamp(cloud_outline, 0.0, 1.0);

	vec3 cloud_gold = vec3(0.79, 0.57, 0.17) + grain * 0.025;
	color = mix(color, cloud_gold, cloud_fill * 0.16);
	color = mix(color, vec3(0.95, 0.75, 0.27), cloud_outline * 0.62);

	// 輪郭だけが浮かないよう、四周をかすかに減光する。
	float edge = min(min(point.x, 1.0 - point.x), min(point.y, 1.0 - point.y));
	color *= mix(0.82, 1.0, smoothstep(0.0, 0.10, edge));
	COLOR = vec4(color, source.a);
}
