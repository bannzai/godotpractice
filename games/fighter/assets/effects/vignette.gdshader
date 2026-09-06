shader_type canvas_item;
render_mode unshaded;

void fragment() {
    vec2 edge = abs(UV - vec2(0.5)) * 2.0;
    float vignette = smoothstep(0.55, 1.3, length(edge * vec2(0.65, 0.65)));
    COLOR = vec4(0.015, 0.035, 0.08, vignette * 0.42);
}
