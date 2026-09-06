shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec4 tint : source_color = vec4(1.0, 0.83, 0.55, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform bool shield = false;

void fragment() {
	vec2 point = UV * 2.0 - 1.0;
	float radius = length(point);
	float front = mix(0.13, 0.95, progress);
	float ring = 1.0 - smoothstep(0.018, 0.052, abs(radius - front));
	float center = shield ? (1.0 - smoothstep(0.0, front, radius)) * 0.17 : 0.0;
	float fade = pow(1.0 - progress, 1.5);
	COLOR = vec4(tint.rgb, (ring * 0.8 + center) * fade * tint.a);
}
