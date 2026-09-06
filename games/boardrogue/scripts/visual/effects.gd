extends Control
## 墨の飛沫、斬撃、獲得光を一度の戦闘イベントに対応させる。

signal impact_requested(strength: float)

const FONT := preload("res://assets/fonts/ZenOldMincho-Regular.ttf")
const INK := preload("res://assets/art/fx_ink.svg")
const SPARK := preload("res://assets/art/fx_spark.svg")
const GLOW := preload("res://assets/art/fx_glow.svg")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


# 同じ場所の別イベントも表示する必要があるため、呼ぶたびに子ノードを作る。
func spawn(kind: String, at: Vector2, amount: int = 0) -> void:
	var effect := Node2D.new()
	effect.position = at
	add_child(effect)
	var tint: Color = Color("bb4c3c") if kind in ["hurt", "hit", "death"] else Color("e3c587")
	_particles(effect, kind, tint)
	_flash(effect, tint)
	if kind in ["attack", "blade", "arrow", "hit"]:
		_slash(effect, tint)
	if amount != 0 or kind in ["reward", "heal", "death"]:
		_number(effect, kind, amount, tint)
	if kind in ["hurt", "hit", "death", "king", "boss"]:
		impact_requested.emit(9.0 if kind in ["king", "boss"] else 4.0)
	var lifetime: Tween = effect.create_tween()
	lifetime.tween_interval(1.15)
	lifetime.tween_callback(effect.queue_free)


func _particles(effect: Node2D, kind: String, tint: Color) -> void:
	var particles := CPUParticles2D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 30 if kind == "death" else 20
	particles.lifetime = 0.9
	particles.lifetime_randomness = 0.18
	particles.texture = INK if kind in ["death", "hurt", "hit"] else SPARK
	particles.color = Color("192d34") if kind == "death" else tint
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 45.0
	particles.initial_velocity_max = 190.0
	particles.gravity = Vector2(0, 100)
	particles.scale_amount_min = 0.08
	particles.scale_amount_max = 0.38
	particles.angular_velocity_min = -160.0
	particles.angular_velocity_max = 160.0
	particles.damping_min = 50.0
	particles.damping_max = 85.0
	if kind in ["reward", "heal", "boss"]:
		particles.gravity = Vector2(0, -70)
		particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		particles.emission_rect_extents = Vector2(50, 24)
		particles.spread = 30.0
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	gradient.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	particles.color_ramp = gradient
	effect.add_child(particles)
	particles.emitting = true


func _flash(effect: Node2D, tint: Color) -> void:
	var flash := Sprite2D.new()
	flash.texture = GLOW
	flash.modulate = tint
	flash.scale = Vector2.ONE * 0.5
	var blend := CanvasItemMaterial.new()
	blend.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	flash.material = blend
	effect.add_child(flash)
	var tween: Tween = effect.create_tween().set_parallel(true)
	tween.tween_property(flash, "scale", Vector2.ONE * 3.5, 0.25)
	tween.tween_property(flash, "modulate:a", 0.0, 0.30)


func _slash(effect: Node2D, tint: Color) -> void:
	var slash := Line2D.new()
	slash.points = PackedVector2Array([Vector2(-55, 42), Vector2(-19, 9), Vector2(52, -41)])
	slash.width = 6.0
	slash.default_color = tint
	slash.antialiased = true
	effect.add_child(slash)
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.04))
	curve.add_point(Vector2(0.45, 1))
	curve.add_point(Vector2(1, 0.03))
	slash.width_curve = curve
	var tween: Tween = effect.create_tween().set_parallel(true)
	tween.tween_property(slash, "scale", Vector2.ONE * 1.5, 0.23)
	tween.tween_property(slash, "modulate:a", 0.0, 0.26)


func _number(effect: Node2D, kind: String, amount: int, tint: Color) -> void:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = "−%d" % absi(amount)
	match kind:
		"reward": label.text = "新たな一枚"
		"heal": label.text = "+%d 回復" % absi(amount)
		"death": label.text = "消散"
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", tint)
	label.add_theme_color_override("font_outline_color", Color("101c22"))
	label.add_theme_constant_override("outline_size", 7)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-140, -55)
	label.size = Vector2(280, 60)
	label.pivot_offset = Vector2(140, 30)
	label.scale = Vector2.ONE * 0.65
	effect.add_child(label)
	var pop: Tween = effect.create_tween()
	pop.tween_property(label, "scale", Vector2.ONE * 1.1, 0.10).set_trans(Tween.TRANS_BACK)
	pop.tween_property(label, "scale", Vector2.ONE, 0.14)
	var drift: Tween = effect.create_tween().set_parallel(true)
	drift.tween_property(label, "position:y", -120.0, 0.95)
	drift.tween_property(label, "modulate:a", 0.0, 0.35).set_delay(0.55)
