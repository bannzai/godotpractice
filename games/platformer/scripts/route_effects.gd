class_name RouteEffects
extends Node2D
## 取得・衝突の瞬間ごとに粒子と数字を生成するため非冪等。子ノードは演出終了時に解放する。

const GOLD: Color = Color("ffe097")
const MINT: Color = Color("83ffe0")
const CORAL: Color = Color("ff8b8d")


func burst(kind: String, at: Vector2, text: String = "") -> void:
	var tint: Color = GOLD
	var amount: int = 14
	if kind == "power" or kind == "clear":
		tint = MINT
		amount = 32 if kind == "power" else 60
	elif kind in ["hurt", "death"]:
		tint = CORAL
	elif kind == "land":
		amount = 7
		tint = Color("c5d4c6")
	_particles(at, tint, amount, kind)
	if kind != "land":
		_ring(at, tint, 1.8 if kind == "clear" else 1.0)
	if not text.is_empty():
		_number(at + Vector2(0, -34), text, tint)


func _particles(at: Vector2, tint: Color, amount: int, kind: String) -> void:
	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.emitting = false
	particles.position = at
	particles.z_index = 7
	particles.one_shot = true
	particles.amount = amount
	particles.lifetime = 0.70 if kind != "clear" else 1.35
	particles.explosiveness = 1.0
	particles.texture = load("res://assets/images/particle.svg")
	particles.direction = Vector2.UP
	particles.spread = 70.0 if kind in ["land", "clear"] else 180.0
	particles.gravity = Vector2(0, 190 if kind != "power" else -50)
	particles.initial_velocity_min = 32.0 if kind == "land" else 55.0
	particles.initial_velocity_max = 110.0 if kind != "clear" else 230.0
	particles.scale_amount_min = 0.25
	particles.scale_amount_max = 0.8
	particles.angular_velocity_min = -160
	particles.angular_velocity_max = 160
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, tint)
	ramp.set_color(1, Color(tint, 0.0))
	particles.color_ramp = ramp
	add_child(particles)
	particles.finished.connect(particles.queue_free)
	particles.emitting = true


func _ring(at: Vector2, tint: Color, strength: float) -> void:
	var ring: Line2D = Line2D.new()
	ring.position = at
	ring.z_index = 6
	ring.width = 2.5
	ring.default_color = tint
	ring.closed = true
	ring.antialiased = true
	for index: int in 33:
		ring.add_point(Vector2.from_angle(TAU * index / 32.0) * 10.0)
	add_child(ring)
	var tween: Tween = ring.create_tween().set_parallel()
	tween.tween_property(ring, "scale", Vector2.ONE * 4.5 * strength, 0.38)
	tween.tween_property(ring, "modulate:a", 0.0, 0.38)
	tween.chain().tween_callback(ring.queue_free)


func _number(at: Vector2, value: String, tint: Color) -> void:
	var label: Label = Label.new()
	label.text = value
	label.position = at - Vector2(60, 15)
	label.size = Vector2(120, 40)
	label.pivot_offset = Vector2(60, 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.z_index = 8
	var theme: Theme = load("res://resources/delivery_theme.tres")
	label.add_theme_font_override("font", theme.default_font)
	label.add_theme_font_size_override("font_size", 23)
	label.add_theme_color_override("font_color", tint)
	label.add_theme_color_override("font_outline_color", Color("183442"))
	label.add_theme_constant_override("outline_size", 6)
	add_child(label)
	label.scale = Vector2.ONE * 0.6
	var tween: Tween = label.create_tween()
	tween.tween_property(label, "scale", Vector2.ONE * 1.12, 0.12)
	tween.tween_property(label, "scale", Vector2.ONE, 0.13)
	tween.parallel().tween_property(label, "position:y", label.position.y - 36, 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.2)
	tween.tween_callback(label.queue_free)
