shader_type canvas_item;
render_mode unshaded;

// 透過済みの SVG と、明るい無彩色の市松背景を持つ生成画像を同じ輪郭処理で扱う。
// 生成画像でだけ key_checker_background を有効にし、セル寸法と2色を素材に合わせる。
uniform bool key_checker_background = false;
uniform bool key_chroma_background = false;
uniform float checker_cell_size_px : hint_range(2.0, 64.0, 1.0) = 16.0;
uniform float checker_lightness_a : hint_range(0.0, 1.0, 0.005) = 0.985;
uniform float checker_lightness_b : hint_range(0.0, 1.0, 0.005) = 0.945;
uniform float checker_tolerance : hint_range(0.005, 0.20, 0.005) = 0.055;
uniform float neutral_tolerance : hint_range(0.005, 0.20, 0.005) = 0.045;
uniform vec4 chroma_key_color : source_color = vec4(1.0, 0.0, 1.0, 1.0);
uniform float chroma_tolerance : hint_range(0.01, 0.40, 0.01) = 0.20;
uniform vec4 outline_color : source_color = vec4(0.055, 0.16, 0.20, 1.0);
uniform float outline_width_px : hint_range(0.0, 4.0, 1.0) = 2.0;


float luminance(vec3 color) {
	return dot(color, vec3(0.2126, 0.7152, 0.0722));
}


float visible_alpha(vec4 sample_color, vec2 uv, vec2 texture_pixel_size) {
	float result_alpha = sample_color.a;
	if (key_chroma_background) {
		float chroma_distance = distance(sample_color.rgb, chroma_key_color.rgb);
		float exact_key_alpha = smoothstep(
			chroma_tolerance * 0.35, chroma_tolerance, chroma_distance
		);
		// 生成時の補間で暗くなったマゼンタも、赤と青が緑より強い色相として除去する。
		float magenta_axis = min(sample_color.r, sample_color.b) - sample_color.g;
		float magenta_variant_alpha = 1.0 - smoothstep(0.07, 0.15, magenta_axis);
		result_alpha *= min(exact_key_alpha, magenta_variant_alpha);
	}
	if (!key_checker_background) {
		return result_alpha;
	}
	vec2 pixel = uv / texture_pixel_size;
	vec2 checker_cell = floor(pixel / max(checker_cell_size_px, 1.0));
	float parity = mod(checker_cell.x + checker_cell.y, 2.0);
	float expected_lightness = mix(checker_lightness_a, checker_lightness_b, parity);
	float highest = max(sample_color.r, max(sample_color.g, sample_color.b));
	float lowest = min(sample_color.r, min(sample_color.g, sample_color.b));
	float neutral = 1.0 - smoothstep(
		neutral_tolerance,
		neutral_tolerance * 1.7,
		highest - lowest
	);
	float checker_match = 1.0 - smoothstep(
		checker_tolerance,
		checker_tolerance * 1.45,
		abs(luminance(sample_color.rgb) - expected_lightness)
	);
	return result_alpha * (1.0 - neutral * checker_match);
}


void fragment() {
	vec4 vertex_tint = COLOR;
	vec4 texel = texture(TEXTURE, UV);
	float source_alpha = visible_alpha(texel, UV, TEXTURE_PIXEL_SIZE);
	float nearby_alpha = 0.0;
	vec2 directions[8] = vec2[](
		vec2(-1.0, 0.0), vec2(1.0, 0.0), vec2(0.0, -1.0), vec2(0.0, 1.0),
		vec2(-0.707, -0.707), vec2(0.707, -0.707),
		vec2(-0.707, 0.707), vec2(0.707, 0.707)
	);
	for (int ring = 1; ring <= 4; ring++) {
		if (float(ring) > outline_width_px) {
			continue;
		}
		for (int direction = 0; direction < 8; direction++) {
			vec2 sample_uv = UV + directions[direction] * TEXTURE_PIXEL_SIZE * float(ring);
			vec4 nearby_color = texture(TEXTURE, sample_uv);
			nearby_alpha = max(
				nearby_alpha,
				visible_alpha(nearby_color, sample_uv, TEXTURE_PIXEL_SIZE)
			);
		}
	}
	float outline_alpha = max(nearby_alpha - source_alpha, 0.0) * outline_color.a;
	float result_alpha = max(source_alpha, outline_alpha);
	float fill_mix = smoothstep(0.0, 1.0, source_alpha);
	vec3 result_rgb = mix(outline_color.rgb, texel.rgb, fill_mix);
	COLOR = vec4(result_rgb, result_alpha) * vertex_tint;
}
