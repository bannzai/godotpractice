shader_type canvas_item;

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 accent : source_color = vec4(0.64, 1.0, 0.93, 1.0);

void fragment() {
	vec4 sprite = texture(TEXTURE, UV) * COLOR;
	COLOR = vec4(mix(sprite.rgb, mix(accent.rgb, vec3(1.0), 0.65), flash * 0.85), sprite.a);
}
