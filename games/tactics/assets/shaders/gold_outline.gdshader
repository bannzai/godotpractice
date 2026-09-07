shader_type canvas_item;
render_mode unshaded;

uniform vec4 outline_color : source_color = vec4(0.89, 0.70, 0.25, 0.95);
uniform float outline_width : hint_range(0.0, 16.0, 0.5) = 8.0;
varying vec4 canvas_tint;

void vertex() {
	// fragmentのCOLORには既定テクスチャが乗るため、modulateだけを先に退避する。
	canvas_tint = COLOR;
}

// 透明な人物画の外周へ、屏風の金雲と馴染む細い金線を加える。
// TEXTURE_PIXEL_SIZEを使うため、元画像やAtlasTextureの解像度が変わっても幅の単位は画素になる。
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec2 offset = TEXTURE_PIXEL_SIZE * outline_width;
	float nearby_alpha = 0.0;
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(offset.x, 0.0)).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV - vec2(offset.x, 0.0)).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(0.0, offset.y)).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV - vec2(0.0, offset.y)).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + offset).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV - offset).a);
	nearby_alpha = max(
		nearby_alpha,
		texture(TEXTURE, UV + vec2(offset.x, -offset.y)).a
	);
	nearby_alpha = max(
		nearby_alpha,
		texture(TEXTURE, UV + vec2(-offset.x, offset.y)).a
	);
	float ring = clamp(nearby_alpha - source.a, 0.0, 1.0) * outline_color.a;
	float result_alpha = max(source.a, ring);
	vec3 result_color = mix(outline_color.rgb, source.rgb, source.a);
	COLOR = vec4(result_color, result_alpha) * canvas_tint;
}
