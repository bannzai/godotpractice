extends Control
## 瞬間的な演出を画面の再構築から守る独立レイヤー。

const UI = preload("res://scripts/spirit_ui.gd")

var wash: ColorRect
var transition_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	wash = ColorRect.new()
	wash.size = Vector2(1280, 720)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wash.color = Color(0.02, 0.06, 0.08, 0)
	add_child(wash)


# 演出は出来事ごとに追加するため非冪等。完了時に自分のノードを解放する。
func burst(at: Vector2, tint: Color, text: String = "") -> void:
	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.position = at
	particles.amount = 30
	particles.lifetime = 0.65
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 35.0
	particles.initial_velocity_max = 180.0
	particles.gravity = Vector2(0, -22)
	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 3.0
	particles.color = tint
	add_child(particles)
	particles.emitting = true
	var ring: Line2D = Line2D.new()
	for index: int in range(49):
		ring.add_point(Vector2.from_angle(index * TAU / 48.0) * 32)
	ring.position = at
	ring.default_color = tint
	ring.width = 2
	add_child(ring)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector2.ONE * 2.2, 0.45)
	tween.tween_property(ring, "modulate:a", 0.0, 0.5)
	tween.chain().tween_callback(ring.queue_free)
	if not text.is_empty():
		var number: Label = UI.label(
			self, text, Rect2(at - Vector2(120, 20), Vector2(240, 48)), 29, tint, true
		)
		number.add_theme_color_override("font_shadow_color", Color("08161c"))
		number.add_theme_constant_override("shadow_offset_x", 2)
		number.add_theme_constant_override("shadow_offset_y", 2)
		var pop: Tween = number.create_tween().set_parallel(true)
		pop.tween_property(number, "position:y", number.position.y - 52, 0.9)
		pop.tween_property(number, "modulate:a", 0.0, 0.6).set_delay(0.3)
		pop.chain().tween_callback(number.queue_free)
	get_tree().create_timer(1.0).timeout.connect(particles.queue_free)


func transition() -> void:
	if transition_tween:
		transition_tween.kill()
	wash.color = Color(0.035, 0.075, 0.085, 0.85)
	transition_tween = create_tween()
	transition_tween.tween_property(wash, "color:a", 0.0, 0.42)


func darkness() -> void:
	if transition_tween:
		transition_tween.kill()
	wash.color = Color(0.35, 0.018, 0.03, 0.68)
	transition_tween = create_tween()
	transition_tween.tween_property(wash, "color:a", 0.16, 0.2)
	transition_tween.tween_property(wash, "color:a", 0.0, 0.7)
	burst(Vector2(640, 375), UI.RED, "影が深まる")


func king_hit(target: Control, point: Vector2, damage: int) -> void:
	burst(point, UI.RED, "− %d" % damage)
	wash.color = Color(0.75, 0.51, 0.33, 0.3)
	create_tween().tween_property(wash, "color:a", 0.0, 0.32)
	var shake: Tween = target.create_tween()
	for offset: Vector2 in [Vector2(7, 3), Vector2(-6, -3), Vector2(4, 1), Vector2.ZERO]:
		shake.tween_property(target, "position", offset, 0.045)


func entrance(words: String) -> void:
	var banner: Panel = UI.panel(self, Rect2(328, 282, 624, 101), Color("10262d"))
	UI.label(banner, words, Rect2(18, 18, 588, 65), 38, UI.GOLD, true)
	banner.position.x -= 90
	banner.modulate.a = 0.0
	var tween: Tween = banner.create_tween().set_parallel(true)
	tween.tween_property(banner, "position:x", 328.0, 0.25)
	tween.tween_property(banner, "modulate:a", 1.0, 0.25)
	tween.chain().tween_interval(0.6)
	tween.chain().tween_property(banner, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(banner.queue_free)
