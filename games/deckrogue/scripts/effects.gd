extends Control
## 演出用ノードは一回の発生ごとにまとめて所有し、終了時に解放する。

signal impact_requested(strength: float)

const UI := preload("res://scripts/ui.gd")
const PULSE := preload("res://assets/shaders/pulse.gdshader")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


# 戦闘イベントの回数を表現するため、呼び出すたびに独立した演出を発生させる。
func burst(kind: String, at: Vector2, amount: int = 0) -> void:
	var root := Control.new()
	root.position = at
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var tint: Color = _tint(kind)
	_sparks(root, kind, tint)
	_flash(root, tint)
	_ring(root, kind, tint)
	_number(root, kind, amount, tint)
	if kind in ["attack", "hurt", "death"]:
		impact_requested.emit(9.0 if kind == "death" else 4.0)
	var lifetime: Tween = root.create_tween()
	lifetime.tween_interval(1.15)
	lifetime.tween_callback(root.queue_free)


func _tint(kind: String) -> Color:
	match kind:
		"block": return Color("8cded4")
		"heal": return Color("aee49f")
		"power", "upgrade": return Color("e3b8ff")
		"death": return Color("e4c691")
		"hurt": return Color("f3917d")
	return Color("ffd58c")


# 子ノードの生成は burst ごとの視覚表現として一度ずつ行う。
func _sparks(root: Control, kind: String, tint: Color) -> void:
	var sparks := CPUParticles2D.new()
	sparks.emitting = false
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = 34 if kind == "death" else 22
	sparks.lifetime = 0.85 if kind == "death" else 0.62
	sparks.lifetime_randomness = 0.18
	sparks.texture = load("res://assets/art/fx_spark.png")
	sparks.color = tint
	sparks.direction = Vector2.UP
	sparks.spread = 180.0
	sparks.initial_velocity_min = 85.0
	sparks.initial_velocity_max = 225.0
	sparks.gravity = Vector2(0, 115)
	sparks.scale_amount_min = 0.10
	sparks.scale_amount_max = 0.27
	sparks.angular_velocity_min = -100.0
	sparks.angular_velocity_max = 100.0
	sparks.damping_min = 50.0
	sparks.damping_max = 80.0
	if kind in ["heal", "power", "upgrade", "reward", "victory"]:
		sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		sparks.emission_rect_extents = Vector2(65, 35)
		sparks.spread = 35.0
		sparks.gravity = Vector2(0, -60)
		sparks.initial_velocity_min = 35.0
		sparks.initial_velocity_max = 90.0
	elif kind == "block":
		sparks.initial_velocity_min = 55.0
		sparks.initial_velocity_max = 130.0
		sparks.gravity = Vector2.ZERO
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	gradient.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	sparks.color_ramp = gradient
	var blend := CanvasItemMaterial.new()
	blend.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sparks.material = blend
	root.add_child(sparks)
	sparks.finished.connect(sparks.queue_free)
	sparks.emitting = true


func _flash(root: Control, tint: Color) -> void:
	var flash := Sprite2D.new()
	flash.texture = load("res://assets/art/fx_glow.png")
	flash.modulate = tint
	flash.scale = Vector2.ONE * 0.7
	var blend := CanvasItemMaterial.new()
	blend.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	flash.material = blend
	root.add_child(flash)
	var tween: Tween = root.create_tween().set_parallel(true)
	tween.tween_property(flash, "scale", Vector2.ONE * 4.8, 0.24).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(flash, "modulate:a", 0.0, 0.32)


func _ring(root: Control, kind: String, tint: Color) -> void:
	var ring := ColorRect.new()
	ring.position = Vector2(-110, -110)
	ring.size = Vector2(220, 220)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader_material := ShaderMaterial.new()
	shader_material.shader = PULSE
	shader_material.set_shader_parameter("tint", tint)
	shader_material.set_shader_parameter("shield", kind == "block")
	ring.material = shader_material
	root.add_child(ring)
	var tween: Tween = root.create_tween()
	tween.tween_method(_set_ring_progress.bind(shader_material), 0.0, 1.0, 0.62)


func _set_ring_progress(value: float, shader_material: ShaderMaterial) -> void:
	shader_material.set_shader_parameter("progress", value)


func _number(root: Control, kind: String, amount: int, tint: Color) -> void:
	if kind == "victory" or (kind == "heal" and amount == 0):
		return
	var value: String = "−%d" % amount
	match kind:
		"block": value = "+%d 防御" % amount
		"heal": value = "+%d 回復" % amount
		"power", "upgrade": value = "強化"
		"reward": value = "新たな一枚"
		"death": value = "消散"
	var number: Label = UI.label(root, value, Rect2(-145, -74, 290, 74), 39, tint)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.z_index = 10
	number.add_theme_color_override("font_outline_color", Color("10252a"))
	number.add_theme_constant_override("outline_size", 8)
	number.pivot_offset = Vector2(145, 37)
	number.scale = Vector2.ONE * 0.7
	var pop: Tween = root.create_tween()
	pop.tween_property(number, "scale", Vector2.ONE * 1.12, 0.11).set_trans(Tween.TRANS_BACK)
	pop.tween_property(number, "scale", Vector2.ONE, 0.15)
	var drift: Tween = root.create_tween().set_parallel(true)
	drift.tween_property(number, "position:y", -140.0, 0.9).set_trans(Tween.TRANS_QUAD)
	drift.tween_property(number, "modulate:a", 0.0, 0.38).set_delay(0.48)
