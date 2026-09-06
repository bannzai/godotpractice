extends Node2D
## 行動が成立した瞬間だけ生成し、寿命が終われば消える戦闘演出。


## 独立した命中を重ねて表示するため、呼び出しごとに粒子を追加する。
func burst(pos: Vector2, color: Color, amount: int = 14) -> void:
	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.position = pos
	particles.emitting = false
	particles.amount = maxi(amount, 1)
	particles.lifetime = 0.45
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.spread = 180.0
	particles.direction = Vector2.UP
	particles.gravity = Vector2(0, 95)
	particles.initial_velocity_min = 28.0
	particles.initial_velocity_max = 95.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, color.lightened(0.4))
	gradient.set_color(1, Color(color.r, color.g, color.b, 0))
	particles.color_ramp = gradient
	particles.finished.connect(particles.queue_free)
	add_child(particles)
	particles.emitting = true


## 連続したダメージを個別に読めるよう、毎回ラベルと Tween を生成する。
func popup(pos: Vector2, text: String, color: Color) -> void:
	var label: Label = Label.new()
	label.text = text
	label.position = pos + Vector2(-45, -35)
	label.size = Vector2(90, 36)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Node2D 配下では画面の Theme を継承しないため、日本語フォントを明示する。
	label.add_theme_font_override("font", preload("res://assets/fonts/NotoSansJP.ttf"))
	label.add_theme_font_size_override("font_size", 23)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.035, 0.025, 0.05))
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 32.0, 0.7).set_trans(
		Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.3).set_delay(0.4)
	tween.chain().tween_callback(label.queue_free)


## 攻撃ごとに異なる残像を残すため、演出ノードの生成は冪等にしない。
func slash(pos: Vector2, direction: Vector2) -> void:
	var arc: Line2D = Line2D.new()
	arc.position = pos
	arc.rotation = direction.angle()
	arc.width = 5.0
	arc.default_color = Color(1.0, 0.92, 0.65)
	arc.begin_cap_mode = Line2D.LINE_CAP_ROUND
	arc.end_cap_mode = Line2D.LINE_CAP_ROUND
	arc.antialiased = true
	for index: int in range(12):
		var angle: float = lerpf(-1.15, 1.15, float(index) / 11.0)
		arc.add_point(Vector2(cos(angle) * 27.0, sin(angle) * 27.0))
	add_child(arc)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(arc, "scale", Vector2.ONE * 1.4, 0.2)
	tween.tween_property(arc, "modulate:a", 0.0, 0.2)
	tween.tween_property(arc, "width", 1.0, 0.2)
	tween.chain().tween_callback(arc.queue_free)
