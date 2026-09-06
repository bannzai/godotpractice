extends Control
## 経路定義を参照して線と道標を描く。表示用にゲームの経路を複製しない。

const UI := preload("res://scripts/ui.gd")
const TITLES: Dictionary = {
	"battle": "戦",
	"grave": "墓",
	"living": "命",
	"police": "警",
	"rest": "灯",
	"story": "語",
	"boss": "主"
}
var run: Node


func _draw() -> void:
	if not is_instance_valid(run):
		return
	for level: int in range(run.route.size()):
		var options: Array = run.route[level]
		for branch: int in range(options.size()):
			var here: Vector2 = point(level, branch, options.size())
			if level < run.route.size() - 1:
				var next: Array = run.route[level + 1]
				for other: int in range(next.size()):
					var destination: Vector2 = point(level + 1, other, next.size())
					draw_line(here, destination, Color("647a8055"), 1.4, true)
			var active: bool = level == run.depth
			var past: bool = level < run.depth
			var shade: Color = UI.GOLD if active else Color("59727c")
			if past:
				var visited: bool = (
					level < run.route_choices.size() and run.route_choices[level] == branch
				)
				shade = UI.GOLD if visited else Color("344c56")
			draw_circle(here, 23.0, Color("152a35"))
			draw_arc(here, 23.0, 0, TAU, 32, shade, 2.0, true)
			if active:
				draw_arc(here, 29.0, 0, TAU, 32, Color("d4b58255"), 1.0, true)
			var kind: String = str(options[branch].get("kind", "story"))
			var caption: String = TITLES.get(kind, "語")
			draw_string(
				get_theme_default_font(),
				here + Vector2(-11, 8),
				caption,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				22,
				shade
			)
	for level: int in range(run.route.size()):
		draw_string(
			get_theme_default_font(),
			Vector2(21 + level * 70, 300),
			str(level + 1),
			HORIZONTAL_ALIGNMENT_CENTER,
			50,
			13,
			UI.MUTED
		)


func point(level: int, branch: int, count: int) -> Vector2:
	return Vector2(44 + level * 70, 148 if count == 1 else 77 + branch * 142)
