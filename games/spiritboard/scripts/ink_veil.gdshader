shader_type canvas_item;
render_mode unshaded;

// 画面の端と紙目だけに薄い墨を重ね、文字の中央は読める明るさを保つ。
void fragment() {
	vec2 paper = floor(UV * vec2(1280.0, 720.0));
	float grain = fract(sin(dot(paper, vec2(12.9898, 78.233))) * 43758.5453);
	float edge = smoothstep(0.32, 0.76, length((UV - 0.5) * vec2(1.1, 1.0)));
	COLOR = vec4(0.015, 0.03, 0.045, edge * 0.28 + grain * 0.035);
}
