extends CanvasLayer
## 行動ごとの一時的な粒子・フラッシュ・数値をゲーム状態から切り離す。

var flash_rect: ColorRect
var fade_rect: ColorRect
var particles_root: Node2D
var flash_tween: Tween
var fade_tween: Tween
var shake_tween: Tween
var shake_target: Control
var original_position: Vector2
var stopping_time: bool = false


func _ready() -> void:
	layer = 40
	particles_root = Node2D.new()
	add_child(particles_root)
	flash_rect = _overlay()
	fade_rect = _overlay()


func _overlay() -> ColorRect:
	var overlay := ColorRect.new()
	overlay.size = Vector2(1280, 720)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.color = Color(0, 0, 0, 0)
	add_child(overlay)
	return overlay


# 粒子は出来事ごとに追加するため、繰り返すとそれぞれ独立に発生する。
func burst(at: Vector2, color: Color = Color(0.67, 0.87, 0.83)) -> void:
	var particles := CPUParticles2D.new()
	particles.position = at
	particles.amount = 22
	particles.lifetime = 0.72
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.direction = Vector2.UP
	particles.spread = 155.0
	particles.gravity = Vector2(0, -26)
	particles.initial_velocity_min = 65
	particles.initial_velocity_max = 165
	particles.scale_amount_min = 0.09
	particles.scale_amount_max = 0.3
	particles.texture = load("res://assets/art/spark.svg")
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([color, Color(color, 0)])
	particles.color_ramp = gradient
	particles_root.add_child(particles)
	particles.emitting = true
	var lifetime := create_tween()
	lifetime.tween_interval(1.0)
	lifetime.tween_callback(particles.queue_free)


# 同じ種類でも新しい行動ならフラッシュを先頭から再生する。
func flash(color: Color = Color(0.9, 0.85, 0.67, 0.36)) -> void:
	if flash_tween != null and flash_tween.is_valid():
		flash_tween.kill()
	flash_rect.color = color
	flash_tween = create_tween()
	flash_tween.tween_property(flash_rect, "color:a", 0.0, 0.38).set_trans(Tween.TRANS_CUBIC)


func darkness_pulse() -> void:
	flash(Color(0.62, 0.07, 0.06, 0.62))
	shake(null, 7.0)


func transition() -> void:
	if fade_tween != null and fade_tween.is_valid():
		fade_tween.kill()
	fade_rect.color = Color(0.025, 0.055, 0.075, 0.9)
	fade_tween = create_tween()
	fade_tween.tween_property(fade_rect, "color:a", 0.0, 0.4)


# 新しい衝撃は前の揺れを置き換え、終了時には必ず元の座標へ戻す。
func shake(target: Control = null, strength: float = 10.0) -> void:
	if shake_tween != null and shake_tween.is_valid():
		shake_tween.kill()
		if is_instance_valid(shake_target):
			shake_target.position = original_position
	shake_target = target if target != null else get_parent() as Control
	if shake_target == null:
		return
	original_position = shake_target.position
	shake_tween = create_tween()
	for offset: Vector2 in [Vector2(-1, 0.4), Vector2(0.7, -0.3), Vector2(-0.4, 0.2)]:
		shake_tween.tween_property(shake_target, "position", original_position + offset * strength, 0.045)
	shake_tween.tween_property(shake_target, "position", original_position, 0.08)


# 攻撃の一瞬だけ時間を遅くする。重複は延長せず元の速度へ戻す。
func hit_stop() -> void:
	if stopping_time:
		return
	stopping_time = true
	Engine.time_scale = 0.08
	await get_tree().create_timer(0.065, true, false, true).timeout
	Engine.time_scale = 1.0
	stopping_time = false


# 数値ポップは一回の増減量であり、呼び出しごとに独立して表示する。
func popup(at: Vector2, value: String, color: Color = Color(0.91, 0.84, 0.66)) -> void:
	var label := Label.new()
	label.position = at - Vector2(40, 30)
	label.text = value
	label.add_theme_font_override("font", load("res://assets/fonts/ReggaeOne-Regular.ttf"))
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.1, 0.14))
	label.add_theme_constant_override("outline_size", 6)
	particles_root.add_child(label)
	var motion := create_tween().set_parallel(true)
	motion.tween_property(label, "position:y", label.position.y - 58, 0.8)
	motion.tween_property(label, "modulate:a", 0.0, 0.45).set_delay(0.35)
	motion.chain().tween_callback(label.queue_free)


func _exit_tree() -> void:
	if stopping_time:
		Engine.time_scale = 1.0
