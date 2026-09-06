class_name FighterEffect
extends Node2D
## 命中ごとに新しい粒子とTweenを消費する、短命な演出ノード。

var blocked: bool = false
var tint: Color = Color("fff0ae")
var strength: float = 1.0


func _ready() -> void:
	z_index = 30
	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.texture = preload("res://assets/effects/spark.svg")
	particles.amount = 12 if blocked else 22
	particles.lifetime = 0.42
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.gravity = Vector2(0, 280)
	particles.initial_velocity_min = 90.0 * strength
	particles.initial_velocity_max = 250.0 * strength
	particles.scale_amount_min = 0.07
	particles.scale_amount_max = 0.23
	var fade: Gradient = Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	fade.colors = PackedColorArray([tint, tint, Color(tint, 0.0)])
	particles.color_ramp = fade
	particles.damping_min = 120.0
	particles.damping_max = 180.0
	add_child(particles)
	particles.emitting = true
	var burst: Sprite2D = Sprite2D.new()
	burst.texture = preload("res://assets/effects/guard.svg") if blocked else \
		preload("res://assets/effects/impact.svg")
	burst.modulate = tint
	burst.scale = Vector2.ONE * 0.16
	add_child(burst)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(burst, "scale", Vector2.ONE * (0.68 if blocked else 0.72), 0.17) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(burst, "rotation", -0.18 if blocked else 0.28, 0.3)
	tween.tween_property(burst, "modulate:a", 0.0, 0.25).set_delay(0.06)
	tween.chain().tween_interval(0.25)
	tween.chain().tween_callback(queue_free)
