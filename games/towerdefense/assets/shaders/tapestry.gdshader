shader_type canvas_item;
render_mode unshaded;

uniform float weave_strength : hint_range(0.0, 0.35, 0.01) = 0.12;
uniform float thread_pitch : hint_range(2.0, 8.0, 0.5) = 4.0;


void fragment() {
	vec2 thread = fract(FRAGCOORD.xy / thread_pitch);
	float warp = smoothstep(0.34, 0.5, abs(thread.x - 0.5));
	float weft = smoothstep(0.34, 0.5, abs(thread.y - 0.5));
	float over_under = step(0.5, fract((FRAGCOORD.x + FRAGCOORD.y) / (thread_pitch * 2.0)));
	float raised_thread = mix(warp, weft, over_under);
	vec3 fiber_color = mix(vec3(0.18, 0.15, 0.10), vec3(0.88, 0.78, 0.57), raised_thread);
	float fiber_alpha = weave_strength * mix(0.16, 0.58, raised_thread);
	COLOR = vec4(fiber_color, fiber_alpha);
}
