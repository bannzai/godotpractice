shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

float noise(vec2 point) {
	return fract(sin(dot(point, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float row = floor(uv.y * 180.0);
	float tracking = (noise(vec2(row, floor(TIME * 10.0))) - 0.5) * 0.0017;
	vec2 shifted = uv + vec2(tracking, 0.0);
	float chroma = 0.0012 + 0.0007 * sin(TIME * 2.2);
	vec3 color;
	color.r = texture(screen_texture, shifted + vec2(chroma, 0.0)).r;
	color.g = texture(screen_texture, shifted).g;
	color.b = texture(screen_texture, shifted - vec2(chroma, 0.0)).b;
	float scanline = sin(uv.y * 720.0 * 3.14159265) * 0.025;
	float grain = (noise(vec2(floor(uv.x * 640.0), floor(uv.y * 360.0) + floor(TIME * 24.0))) - 0.5) * 0.035;
	float vignette = 1.0 - smoothstep(0.28, 0.86, distance(uv, vec2(0.5)));
	color = color * (0.95 + scanline) + grain;
	color *= 0.90 + vignette * 0.10;
	COLOR = vec4(color, 1.0);
}
