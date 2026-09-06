shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	float edge = smoothstep(0.35, 1.35, length(centered));
	float breath = sin(UV.x * 7.0 + TIME * 0.22) * 0.015;
	COLOR = vec4(0.025, 0.05, 0.095, edge * 0.35 + breath + 0.015);
}
