shader_type canvas_item;

uniform float darkness : hint_range(0.0, 1.0) = 0.0;
uniform float dots : hint_range(0.0, 1.0) = 0.42;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float value = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	float poster = step(0.22, value) * 0.34 + step(0.52, value) * 0.34 + step(0.78, value) * 0.32;
	vec2 cell = floor(FRAGCOORD.xy / 4.0);
	float checker = mod(cell.x + cell.y, 2.0);
	float halftone = mix(1.0, mix(0.56, 1.0, checker), dots * (1.0 - poster));
	vec3 ink = mix(vec3(0.008), vec3(1.0, 0.82, 0.28), poster * halftone);
	ink = mix(ink, vec3(0.82, 0.08, 0.08), darkness * (1.0 - poster) * 0.5);
	COLOR = vec4(ink, source.a);
}
