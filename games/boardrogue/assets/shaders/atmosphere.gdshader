shader_type canvas_item;
render_mode unshaded;

uniform float clock = 0.0;
uniform float strength = 0.08;
uniform vec4 tint : source_color = vec4(0.78, 0.82, 0.73, 1.0);

float noise(vec2 p) {
    vec2 cell = floor(p);
    vec2 part = fract(p);
    part = part * part * (3.0 - 2.0 * part);
    float a = fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
    float b = fract(sin(dot(cell + vec2(1.0, 0.0), vec2(127.1, 311.7))) * 43758.5453);
    float c = fract(sin(dot(cell + vec2(0.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
    float d = fract(sin(dot(cell + vec2(1.0), vec2(127.1, 311.7))) * 43758.5453);
    return mix(mix(a, b, part.x), mix(c, d, part.x), part.y);
}

void fragment() {
    vec2 drift = UV * vec2(4.0, 12.0) + vec2(clock * 0.021, sin(clock * 0.09) * 0.12);
    float mist = noise(drift) * 0.65 + noise(drift * 2.8) * 0.35;
    float band = smoothstep(0.1, 0.9, UV.y) * (1.0 - smoothstep(0.72, 1.0, UV.y));
    float fiber = noise(UV * vec2(180.0, 38.0)) * 0.6 + sin(UV.y * 920.0) * 0.08;
    float edge_distance = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
    float ragged_edge = 1.0 - smoothstep(0.006 + noise(UV * 31.0) * 0.016, 0.055, edge_distance);
    float wash = mist * band * strength + fiber * 0.026 + ragged_edge * 0.19;
    COLOR = vec4(tint.rgb, wash);
}
