extends Control
## 演出はルールを変更せず、描画時間だけを所有する。

signal impact(strength: float, duration: float)

const BACK = preload("res://assets/art/card_back.svg")
const COLORS := {
	"attack": Color("88fff0"), "damage": Color("ff796b"),
	"destroy": Color("ffb46b"), "summon": Color("ffdc90"),
	"draw": Color("91d8ff"), "boost": Color("ffe8a8"),
	"spell": Color("bd9dff"), "trap": Color("d892ff"),
	"set": Color("a4baff"),
}

var progress: float = 1.0
var kind: String = ""
var source := Vector2(450, 425)
var destination := Vector2(450, 240)
var caption: String = ""
var tween: Tween
var particles: CPUParticles2D
var flash: float = 0.0
var preview: bool = false
var damage_font: FontVariation


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_font = FontVariation.new()
	damage_font.base_font = get_theme_default_font()
	damage_font.variation_embolden = 1.4
	_ensure_particles()


# 受け取ったイベントを再生する操作のため非冪等。前の Tween は停止する。
func play(event_kind: String, label: String, origin: Vector2, target: Vector2) -> void:
	_configure(event_kind, label, origin, target)
	preview = false
	progress = 0.0
	particles.speed_scale = 1.0
	tween = create_tween()
	if kind == "attack":
		tween.tween_property(self, "progress", 0.48, 0.28).set_trans(Tween.TRANS_CUBIC)
		tween.tween_callback(_burst)
		tween.tween_property(self, "progress", 1.0, 0.32).set_trans(Tween.TRANS_QUAD)
	else:
		_burst()
		tween.tween_property(self, "progress", 1.0, duration()).set_trans(Tween.TRANS_QUAD)


func duration() -> float:
	if kind == "destroy":
		return 0.66
	return 0.60 if kind in ["attack", "summon"] else 0.54


func seek_effect(
	event_kind: String, label: String, origin: Vector2, target: Vector2, ratio: float
) -> void:
	_configure(event_kind, label, origin, target)
	preview = true
	progress = clampf(ratio, 0.0, 1.0)
	flash = maxf(0.0, 1.0 - progress * 3.0)
	particles.speed_scale = 0.0
	particles.restart()
	particles.request_particles_process(progress * duration())
	queue_redraw()


func _configure(event_kind: String, label: String, origin: Vector2, target: Vector2) -> void:
	if tween:
		tween.kill()
	kind = event_kind
	caption = label
	source = origin
	destination = target
	flash = 0.0
	_ensure_particles()
	particles.position = target
	particles.color = COLORS.get(kind, Color("ffdc90"))
	particles.gravity = Vector2(0, 190 if kind == "destroy" else -25)
	particles.initial_velocity_min = 65.0 if kind == "boost" else 110.0
	particles.initial_velocity_max = 200.0 if kind == "boost" else 330.0
	particles.direction = Vector2.UP
	particles.spread = 35.0 if kind == "boost" else 180.0
	particles.emitting = false


func _ensure_particles() -> void:
	if is_instance_valid(particles):
		return
	particles = CPUParticles2D.new()
	particles.name = "ImpactParticles"
	particles.emitting = false
	particles.one_shot = true
	particles.amount = 42
	particles.lifetime = 0.50
	particles.explosiveness = 1.0
	particles.use_fixed_seed = true
	particles.seed = 42
	particles.scale_amount_min = 0.45
	particles.scale_amount_max = 1.0
	var fade := Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1, 1, 1, 0))
	particles.color_ramp = fade
	var texture := GradientTexture2D.new()
	texture.width = 12
	texture.height = 12
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.gradient = fade
	particles.texture = texture
	var glow := CanvasItemMaterial.new()
	glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	particles.material = glow
	add_child(particles)


# 各イベントの衝突時に一度呼ばれるため非冪等。
func _burst() -> void:
	particles.restart()
	flash = 1.0
	if kind in ["attack", "damage", "destroy", "trap"]:
		impact.emit(7.0 if kind == "destroy" else 4.0, 0.07)


# フラッシュの減衰は経過時間を積み重ねるため非冪等。
func _process(delta: float) -> void:
	if not preview:
		flash = move_toward(flash, 0.0, delta * 7.0)
	queue_redraw()


func _draw() -> void:
	if progress >= 1.0:
		return
	var color: Color = COLORS.get(kind, Color("ffdc90"))
	var alpha: float = sin(progress * PI)
	color.a = alpha
	if flash > 0.0 and kind in ["attack", "damage", "destroy"]:
		draw_rect(Rect2(Vector2.ZERO, size), Color(color, flash * 0.10))
	match kind:
		"draw":
			_draw_card(alpha, color)
		"attack":
			_draw_attack(color)
		"destroy":
			_draw_destruction(color)
		"damage":
			_draw_damage(color)
		"boost":
			_draw_blessing(color)
		"trap", "set":
			_draw_trap(color)
		_:
			_draw_sigil(color)
	_draw_banner(alpha)


func _draw_card(alpha: float, color: Color) -> void:
	var center: Vector2 = source.lerp(destination, ease(progress, 0.65))
	center.y -= sin(progress * PI) * 65.0
	for index: int in range(6):
		var point: Vector2 = center.lerp(source, index * 0.045)
		draw_circle(point, 14.0 - index * 1.6, Color(color, alpha * (0.25 - index * 0.03)))
	draw_set_transform(center, sin(progress * TAU) * 0.18)
	draw_texture_rect(BACK, Rect2(-30, -43, 60, 86), false, Color(1, 1, 1, alpha))
	draw_set_transform(Vector2.ZERO)


func _draw_attack(color: Color) -> void:
	var travel: float = clampf(progress / 0.48, 0.0, 1.0)
	var center: Vector2 = source.lerp(destination, travel)
	var tail: Vector2 = source.lerp(center, maxf(0.0, travel - 0.36))
	for width: int in [20, 10, 3]:
		draw_line(tail, center, Color(color, color.a * (0.15 if width == 20 else 0.8)), width, true)
	draw_circle(center, 9, Color("fff5cf"))
	if progress >= 0.48:
		var hit: float = (progress - 0.48) / 0.52
		_ring(destination, 18 + hit * 106, Color(color, (1.0 - hit) * 0.9), 3)
		for index: int in range(8):
			var ray: Vector2 = Vector2.from_angle(index * TAU / 8.0 + 0.22)
			draw_line(destination + ray * 14, destination + ray * (45 + hit * 70), color, 3, true)
		var slash := Vector2(50, -70) * sin(hit * PI)
		draw_line(destination - slash, destination + slash, Color("fff9df"), 5, true)


func _draw_destruction(color: Color) -> void:
	_ring(destination, 24 + progress * 95, color, 3)
	for index: int in range(14):
		var direction: Vector2 = Vector2.from_angle(index * 2.4)
		var center: Vector2 = destination + direction * (15 + progress * (65 + index * 4))
		center.y += progress * progress * 65
		var tip: Vector2 = direction.rotated(progress * 3.0) * (13 - progress * 8)
		var points := PackedVector2Array([
			center + tip, center + tip.rotated(2.4) * 0.65, center + tip.rotated(4.4) * 0.7,
		])
		draw_colored_polygon(points, color)


func _draw_damage(color: Color) -> void:
	var point: Vector2 = destination + Vector2(-76, -12 - progress * 40)
	var amount: String = caption.get_slice("  ", caption.get_slice_count("  ") - 1)
	var text_value: String = "−" + amount
	var pixels: int = int(35 + sin(minf(progress * 3.0, 1.0) * PI) * 12)
	draw_string_outline(damage_font, point, text_value, HORIZONTAL_ALIGNMENT_CENTER, 152, pixels, 6,
		Color(0.07, 0.02, 0.08, color.a))
	draw_string(damage_font, point, text_value, HORIZONTAL_ALIGNMENT_CENTER, 152, pixels, color)
	_ring(destination, 20 + progress * 45, color, 2)


func _draw_blessing(color: Color) -> void:
	_draw_sigil(color)
	for index: int in range(6):
		var angle: float = index * TAU / 6.0 + progress * 2.0
		var center: Vector2 = destination + Vector2(cos(angle) * 52, -progress * 85)
		draw_line(center + Vector2(0, 10), center - Vector2(0, 10), color, 3, true)
		draw_line(center - Vector2(6, 0), center + Vector2(6, 0), color, 3, true)


func _draw_trap(color: Color) -> void:
	var radius: float = 98 - progress * 55
	for index: int in range(6):
		var angle: float = index * TAU / 6.0 + PI / 6.0
		var first: Vector2 = destination + Vector2.from_angle(angle) * radius
		var next: Vector2 = destination + Vector2.from_angle(angle + TAU / 6.0) * radius
		draw_line(first, next, color, 3, true)
		for link: int in range(4):
			var center: Vector2 = first.lerp(destination, link / 6.0)
			draw_arc(center, 6, angle, angle + TAU * 0.83, 12, color, 2, true)
	_ring(destination, 28 + sin(progress * PI) * 22, Color(color, color.a * 0.5), 8)


func _draw_sigil(color: Color) -> void:
	var radius: float = 28 + sin(progress * PI * 0.7) * 61
	draw_set_transform(destination, 0, Vector2(1, 0.45))
	_ring(Vector2.ZERO, radius, color, 3)
	_ring(Vector2.ZERO, radius * 0.76, Color(color, color.a * 0.55), 1)
	for index: int in range(12):
		var angle: float = index * TAU / 12.0 + progress * 1.7
		draw_line(Vector2.from_angle(angle) * radius * 0.80,
			Vector2.from_angle(angle) * radius * 0.96, color, 3, true)
	draw_set_transform(Vector2.ZERO)
	for index: int in range(5):
		var x: float = (index - 2) * 20
		draw_line(destination + Vector2(x, 3),
			destination + Vector2(x, -sin(progress * PI) * (62 - absf(x))),
			Color(color, color.a * 0.5), 4, true)


func _ring(center: Vector2, radius: float, color: Color, width: float) -> void:
	draw_arc(center, radius, 0, TAU, 64, color, width, true)


func _draw_banner(alpha: float) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.025, 0.05, 0.09, alpha * 0.93)
	box.border_color = Color(0.87, 0.73, 0.44, alpha)
	box.border_width_top = 1
	box.border_width_bottom = 1
	var rect := Rect2(340, 325, 540, 44)
	draw_style_box(box, rect)
	draw_string(get_theme_default_font(), rect.position + Vector2(8, 29), caption,
		HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 16, 19, Color(1, 0.94, 0.8, alpha))
