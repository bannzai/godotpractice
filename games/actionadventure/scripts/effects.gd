extends Node2D
## 演出は寿命が終わると子ノードごと解放する。

var font: Font


func _ready() -> void:
	font = load("res://assets/fonts/Stick-Regular.ttf")


# ゲーム内の一回の衝突・獲得に対する視覚効果なので非冪等。
func burst(at: Vector2, color: Color, count: int = 18) -> void:
	var particles := CPUParticles2D.new()
	particles.position = at
	particles.amount = count
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.lifetime = 0.5
	particles.direction = Vector2.UP
	particles.spread = 180
	particles.gravity = Vector2(0, 70)
	particles.initial_velocity_min = 45
	particles.initial_velocity_max = 160
	particles.scale_amount_min = 3
	particles.scale_amount_max = 6
	particles.color = color
	add_child(particles)
	particles.emitting = true
	get_tree().create_timer(0.7).timeout.connect(particles.queue_free)


# 数値ポップは発生ごとに独立した寿命を持つ。
func popup(at: Vector2, text: String, color: Color = Color("f4ce82")) -> void:
	var label := Label.new()
	label.text = text
	label.position = at - Vector2(35, 55)
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 48, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.2)
	tween.chain().tween_callback(label.queue_free)
