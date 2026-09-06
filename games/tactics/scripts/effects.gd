extends Control
## 戦闘イベントの視覚表現。ゲームの値は変更しない。

const UI := preload("res://scripts/ui.gd")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


# イベントの発生回数に応じて粒子と数値を追加するため非冪等。
func burst(at: Vector2, caption: String, tint: Color = UI.GOLD) -> void:
	var particles := CPUParticles2D.new()
	particles.position = at
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 28
	particles.lifetime = 0.65
	particles.direction = Vector2.UP
	particles.spread = 150
	particles.initial_velocity_min = 50
	particles.initial_velocity_max = 160
	particles.gravity = Vector2(0, 110)
	particles.scale_amount_min = 2
	particles.scale_amount_max = 4
	particles.color = tint
	add_child(particles)
	particles.finished.connect(particles.queue_free)
	var text: Label = UI.label(self, caption, Rect2(at.x - 100, at.y - 65, 200, 50), 30, tint)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.add_theme_color_override("font_outline_color", UI.INK)
	text.add_theme_constant_override("outline_size", 7)
	var tween: Tween = text.create_tween().set_parallel(true)
	tween.tween_property(text, "position:y", text.position.y - 46, 0.9)
	tween.tween_property(text, "modulate:a", 0.0, 0.4).set_delay(0.5)
	tween.chain().tween_callback(text.queue_free)


# フェーズ通知は一度表示して退場する。
func banner(caption: String, tint: Color = UI.JADE) -> void:
	var strip: Panel = UI.panel(self, Rect2(-1280, 288, 1280, 120), UI.INK, tint)
	var text: Label = UI.label(strip, caption, Rect2(0, 26, 1280, 70), 36, tint)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tween: Tween = strip.create_tween()
	tween.tween_property(strip, "position:x", 0.0, 0.2).set_trans(Tween.TRANS_CUBIC)
	tween.tween_interval(0.5)
	tween.tween_property(strip, "position:x", 1280.0, 0.2)
	tween.tween_callback(strip.queue_free)
