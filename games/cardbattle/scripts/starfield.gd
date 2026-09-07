extends Control
## 木製卓上の俯瞰背景。灯りの揺らぎを時間で変えるため描画は非冪等。

const TABLE = preload("res://assets/art/generated/table.png")

var elapsed: float = 0.0
var duel: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()


func _draw() -> void:
	var warmth: float = 0.96 + sin(elapsed * 0.7) * 0.025
	var tint := Color(warmth, warmth * 0.98, warmth * (0.92 if duel else 0.96))
	draw_texture_rect(TABLE, Rect2(Vector2.ZERO, size), false, tint)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.025, 0.015, 0.08 if duel else 0.16))
