shader_type canvas_item;
render_mode unshaded;

uniform float grain_strength : hint_range(0.0, 0.1) = 0.032;
uniform float fiber_strength : hint_range(0.0, 0.04) = 0.009;

float hash(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec2 pixel = SCREEN_UV / SCREEN_PIXEL_SIZE;
	float grain = hash(floor(pixel * 0.55)) - 0.5;
	float fiber = sin(pixel.y * 0.61 + sin(pixel.x * 0.035) * 2.0);
	float fold = pow(max(0.0, cos((UV.x + UV.y * 0.07) * 31.0)), 34.0);
	vec4 result = COLOR;
	result.rgb += vec3(grain * grain_strength + fiber * fiber_strength + fold * 0.012);
	COLOR = result;
}
