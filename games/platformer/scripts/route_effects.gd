class_name RouteEffects
extends Node2D
## 取得・衝突の瞬間ごとに粒子と数字を生成するため非冪等。子ノードは演出終了時に解放する。

const GOLD: Color = Color("ffe097")
const MINT: Color = Color("83ffe0")
const CORAL: Color = Color("ff8b8d")
const INK: Color = Color("153e4a")
const COMIC_THEME: Theme = preload("res://resources/delivery_theme.tres")
const SOUND_WORDS: Dictionary[String, String] = {
	"coin": "キラッ！", "block": "ガコン！", "land": "タッ！", "power": "ビカッ！",
	"stomp": "ドン！", "hurt": "イテッ！", "death": "ズコー！", "clear": "ゴール！",
}


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
	var word_parent: Node = self
	var word_at: Vector2 = at + Vector2(0, -82)
	if not text.is_empty():
		word_parent = _number(at + Vector2(0, -34), text, tint)
		word_at = Vector2(-40, -63)
	var word: String = _sound_word(kind)
	if not word.is_empty():
		_comic_word(word_parent, word_at, word, tint, kind)


func _sound_word(kind: String) -> String:
	return SOUND_WORDS.get(kind, "")


func _comic_word(parent: Node, at: Vector2, word: String, tint: Color, kind: String) -> void:
	var label: Label = Label.new()
	label.theme = COMIC_THEME
	label.text = word
	label.position = at - Vector2(100, 30)
	label.size = Vector2(200, 68)
	label.pivot_offset = label.size / 2.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 9
	label.rotation = deg_to_rad(-8.0 if kind in ["stomp", "block", "hurt"] else 6.0)
	label.add_theme_font_size_override("font_size", 35 if kind in ["clear", "death"] else 29)
	label.add_theme_color_override("font_color", tint)
	label.add_theme_color_override("font_outline_color", INK)
	label.add_theme_constant_override("outline_size", 9)
	parent.add_child(label)
	label.scale = Vector2.ONE * 0.28
	var tween: Tween = label.create_tween()
	tween.tween_property(label, "scale", Vector2.ONE * 1.22, 0.12).set_trans(Tween.TRANS_BACK)
	tween.tween_property(label, "scale", Vector2.ONE, 0.10)
	tween.tween_interval(0.16)
	tween.tween_property(label, "position:y", label.position.y - 24.0, 0.18)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.18)
	tween.tween_callback(label.queue_free)


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


func _number(at: Vector2, value: String, tint: Color) -> Label:
	var label: Label = Label.new()
	label.text = value
	label.position = at - Vector2(60, 15)
	label.size = Vector2(120, 40)
	label.pivot_offset = Vector2(60, 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.z_index = 8
	label.theme = COMIC_THEME
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
	return label
