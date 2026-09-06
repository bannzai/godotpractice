extends Node2D
## パーティクルと数値の寿命を演出ノードが所有する。ゲーム時間の停止とは独立する。

const COLORS: Dictionary = {
	"hit": Color("ffbb91"),
	"death": Color("c4e7aa"),
	"pulse": Color("79e7da"),
	"level": Color("ffe5a5"),
	"heal": Color("9ff3b4"),
	"magnet": Color("bca8ff"),
	"boss": Color("ff9d88")
}
var face: Font


# 同じ場所への連続した衝突も別の演出なので、呼び出すたびに生成する。
func emit_effect(at: Vector2, kind: String, caption: String = "", radius: float = 0.0) -> void:
	if not Rect2(-200, -200, 1680, 1120).has_point(at):
		return
	var important: bool = kind not in ["hit", "death"]
	# 一斉撃破のあとでも範囲・回復・成長が見えるよう、重要演出の枠を残す。
	if not important and get_child_count() >= 48:
		return
	if get_child_count() >= 64:
		var oldest: Node = get_child(0)
		remove_child(oldest)
		oldest.queue_free()
	var effect := Node2D.new()
	effect.name = kind
	effect.position = at
	add_child(effect)
	var lifetime: Tween = effect.create_tween()
	lifetime.tween_interval(0.95)
	lifetime.tween_callback(effect.queue_free)
	var color: Color = COLORS.get(kind, Color.WHITE)
	var particles := CPUParticles2D.new()
	particles.position = Vector2.ZERO
	particles.emitting = false
	particles.texture = preload("res://assets/art/spark.svg")
	particles.amount = 9 if kind in ["hit", "death"] else 28
	particles.lifetime = 0.48 if kind == "hit" else 0.8
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.spread = 180.0
	particles.direction = Vector2.UP
	particles.gravity = Vector2(0, -35 if kind == "heal" else 40)
	particles.initial_velocity_min = 35.0
	particles.initial_velocity_max = 110.0 if kind in ["hit", "death"] else 180.0
	particles.scale_amount_min = 0.22
	particles.scale_amount_max = 0.48
	particles.damping_min = 45.0
	particles.damping_max = 65.0
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([color, Color(color, 0.0)])
	particles.color_ramp = gradient
	particles.finished.connect(particles.queue_free)
	effect.add_child(particles)
	particles.emitting = true
	if kind in ["pulse", "level", "heal", "magnet", "boss"]:
		_ring(effect, radius if radius > 0 else 90.0, color)
	if not caption.is_empty():
		_number(effect, caption, color, kind != "hit")


func clear_effects() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()


# Tween はイベント単位の変化を表すため非冪等。
func _ring(effect: Node2D, radius: float, color: Color) -> void:
	var ring := Line2D.new()
	# アイコン画像の余白に影響されず、終点を実際の攻撃半径へ合わせる。
	for index: int in range(96):
		ring.add_point(Vector2.from_angle(TAU * index / 96.0) * radius)
	ring.closed = true
	ring.width = 3.0
	ring.default_color = color
	ring.antialiased = true
	ring.scale = Vector2.ONE * 0.12
	effect.add_child(ring)
	var tween: Tween = ring.create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector2.ONE, 0.48)
	tween.tween_property(ring, "modulate:a", 0.0, 0.65)
	tween.chain().tween_callback(ring.queue_free)


func _number(effect: Node2D, caption: String, color: Color, important: bool) -> void:
	var label := Label.new()
	label.text = caption
	label.add_theme_font_override("font", face)
	label.add_theme_font_size_override("font_size", 24 if important else 20)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("0a1c26"))
	label.add_theme_constant_override("outline_size", 5)
	label.position = Vector2(-26, -42)
	label.pivot_offset = Vector2(28, 12)
	label.scale = Vector2.ONE * 0.7
	effect.add_child(label)
	var tween: Tween = label.create_tween().set_parallel(true)
	tween.tween_property(label, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK)
	tween.tween_property(label, "position:y", label.position.y - 55, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.35).set_delay(0.45)
	tween.chain().tween_callback(label.queue_free)
