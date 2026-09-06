shader_type canvas_item;
render_mode unshaded;
uniform bool cave = false;

void fragment() {
	vec3 top = cave ? vec3(0.035, 0.08, 0.18) : vec3(0.45, 0.76, 0.79);
	vec3 bottom = cave ? vec3(0.10, 0.31, 0.39) : vec3(0.98, 0.91, 0.72);
	vec3 color = mix(top, bottom, smoothstep(0.0, 1.0, UV.y));
	vec2 sun = (UV - vec2(0.81, 0.24)) * vec2(1.78, 1.0);
	float halo = exp(-length(sun) * 9.0);
	color += (cave ? vec3(0.06, 0.15, 0.19) : vec3(0.18, 0.16, 0.10)) * halo;
	if (!cave) {
		color = mix(color, vec3(1.0, 0.96, 0.80), 1.0 - smoothstep(0.063, 0.066, length(sun)));
	}
	COLOR = vec4(color, 1.0);
}
