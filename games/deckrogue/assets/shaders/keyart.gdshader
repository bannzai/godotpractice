shader_type canvas_item;

void fragment() {
	COLOR.a *= smoothstep(0.0, 0.25, UV.x);
}
