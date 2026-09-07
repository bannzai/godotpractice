extends Control
## 太鼓の張りを円形のゲージとして表す。

const INK := Color("17131d")
const PAPER := Color("fff0cf")
const VERMILION := Color("ef3e2f")
const SUN := Color("ffc62f")

var value: float = 0.5:
	set(next_value):
		value = clampf(next_value, 0.0, 1.0)
		queue_redraw()


func _draw() -> void:
	var center: Vector2 = size / 2.0
	var radius: float = minf(size.x, size.y) * 0.42
	draw_circle(center + Vector2(6, 8), radius + 8, Color(INK, 0.5))
	draw_circle(center, radius + 8, INK)
	draw_circle(center, radius, PAPER)
	draw_circle(center, radius * 0.78, Color("f7cf86"))
	for spoke: int in range(12):
		var angle: float = TAU * float(spoke) / 12.0
		draw_line(
			center + Vector2.from_angle(angle) * radius * 0.79,
			center + Vector2.from_angle(angle) * radius * 0.98,
			INK,
			3.0
		)
	var start_angle: float = -PI * 0.5
	var color: Color = SUN if value >= 0.6 else VERMILION
	draw_arc(center, radius * 0.67, start_angle, start_angle + TAU * value, 72, color, 13.0, true)
	draw_circle(center, 9.0, INK)
	draw_string(
		get_theme_default_font(),
		center + Vector2(-35, 7),
		"%d%%" % roundi(value * 100.0),
		HORIZONTAL_ALIGNMENT_CENTER,
		70,
		19,
		INK
	)
