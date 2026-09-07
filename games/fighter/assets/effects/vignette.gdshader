shader_type canvas_item;
render_mode unshaded;

void fragment() {
    vec2 edge = abs(UV - vec2(0.5)) * 2.0;
    float vignette = smoothstep(0.55, 1.3, length(edge * vec2(0.65, 0.65)));
    float scanline = step(0.52, fract(FRAGCOORD.y * 0.5));
    float line_alpha = mix(0.015, 0.085, scanline);
    COLOR = vec4(0.015, 0.005, 0.06, vignette * 0.46 + line_alpha);
}
