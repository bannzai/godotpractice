extends Control
## 時間で進む演出。play は新しい演出を開始するため非冪等。

const BACK = preload("res://assets/art/card_back.svg")

var progress: float = 1.0
var kind: String = ""
var source := Vector2(450, 425)
var destination := Vector2(450, 240)
var caption: String = ""
var tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func play(event_kind: String, label: String, origin: Vector2, target: Vector2) -> void:
	kind = event_kind
	caption = label
	source = origin
	destination = target
	progress = 0.0
	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_property(self, "progress", 1.0, 0.65)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if progress >= 1.0:
		return
	var alpha: float = sin(progress * PI)
	var color := Color(0.88, 0.74, 0.45, alpha)
	var center: Vector2 = source.lerp(destination, progress)
	if kind == "draw":
		draw_set_transform(center, progress * 0.3)
		draw_texture_rect(BACK, Rect2(-35, -50, 70, 100), false)
		draw_set_transform(Vector2.ZERO)
	elif kind == "attack":
		draw_line(source, center, Color(0.3, 0.95, 0.85, alpha), 10, true)
		draw_circle(center, 15 + alpha * 15, Color(1, 0.9, 0.6, alpha))
	else:
		for index: int in range(14):
			var angle: float = index * TAU / 14.0
			var ray := Vector2.from_angle(angle)
			draw_line(
				destination + ray * progress * 30,
				destination + ray * (30 + progress * 100),
				color,
				3,
				true
			)
		draw_arc(destination, 25 + progress * 75, 0, TAU, 48, color, 3, true)
	draw_style_box(_banner(alpha), Rect2(325, 299, 570, 62))
	draw_string(
		theme.default_font,
		Vector2(340, 339),
		caption,
		HORIZONTAL_ALIGNMENT_CENTER,
		540,
		22,
		Color(1, 0.94, 0.8, alpha)
	)


func _banner(alpha: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.03, 0.08, 0.13, alpha * 0.92)
	box.border_color = Color(0.87, 0.73, 0.44, alpha)
	box.border_width_top = 1
	box.border_width_bottom = 1
	return box
