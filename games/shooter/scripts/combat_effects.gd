extends Node2D
## 戦闘イベントごとに線片とTweenを生成するため非冪等。clear_effectsで出撃前へ戻す。

const MINT: Color = Color("79f5d4")
const GOLD: Color = Color("ffbc75")
const FIELD_ORIGIN: Vector2 = Vector2(320, 0)
const MAX_EFFECTS: int = 72

var font: Font
var content: Node2D
var atmosphere: ColorRect


func _ready() -> void:
	var clip: Control = Control.new()
	clip.position = FIELD_ORIGIN
	clip.size = Vector2(640, 720)
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(clip)
	content = Node2D.new()
	content.position = -FIELD_ORIGIN
	clip.add_child(content)
	atmosphere = ColorRect.new()
	atmosphere.size = clip.size
	atmosphere.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader: Shader = Shader.new()
	shader.code = """shader_type canvas_item;
render_mode unshaded;
uniform float alarm = 0.0;
void fragment() {
    vec2 p = UV * 2.0 - 1.0;
    float edge = smoothstep(0.35, 1.3, length(p));
    vec3 tint = mix(vec3(0.015, 0.06, 0.10), vec3(0.20, 0.03, 0.07), alarm);
    COLOR = vec4(tint, edge * 0.17);
}"""
	var shader_material: ShaderMaterial = ShaderMaterial.new()
	shader_material.shader = shader
	atmosphere.material = shader_material
	clip.add_child(atmosphere)


func set_presentation(offset: Vector2, boss: bool, stopped: bool) -> void:
	content.position = offset - FIELD_ORIGIN
	content.process_mode = Node.PROCESS_MODE_DISABLED if stopped else Node.PROCESS_MODE_INHERIT
	(atmosphere.material as ShaderMaterial).set_shader_parameter("alarm", 1.0 if boss else 0.0)


func clear_effects() -> void:
	for child: CanvasItem in content.get_children():
		child.hide()
		child.queue_free()


func hit(location: Vector2, amount: int = 1, friendly: bool = false) -> void:
	var color: Color = MINT if friendly else GOLD
	_burst(location, color, 8, 130.0, 0.27, 0.7)
	_popup(location, "−%d" % amount, color, 17)


func explosion(location: Vector2, large: bool = false) -> void:
	_burst(location, GOLD, 70 if large else 25, 280.0 if large else 165.0, 0.7, 1.4)
	_ring(location, GOLD, 170.0 if large else 54.0, 0.65)


func bomb(location: Vector2) -> void:
	_burst(location, MINT, 85, 470.0, 0.85, 1.7)
	_ring(location, MINT, 690.0, 0.7)
	_popup(location - Vector2(0, 55), "航路一掃", MINT, 26)


func collect(location: Vector2, kind: String) -> void:
	var color: Color = GOLD if kind == "score" else MINT
	_burst(location, color, 25, 125.0, 0.58, 0.95)
	_ring(location, color, 69.0, 0.55)
	var text: String = "ショット強化" if kind == "power" else "ボム補給"
	if kind == "score":
		text = "+500"
	_popup(location, text, color, 22)


func _burst(
	location: Vector2, color: Color, count: int, speed: float, duration: float, size: float
) -> void:
	if content.get_child_count() >= MAX_EFFECTS:
		return
	var burst: Node2D = Node2D.new()
	burst.position = location
	content.add_child(burst)
	for index: int in range(mini(count, 42)):
		var angle: float = float(index) * 2.399963 + location.x * 0.013
		var direction: Vector2 = Vector2.from_angle(angle)
		var length: float = (7.0 + float(index % 7) * 2.4) * size
		var shard: Line2D = Line2D.new()
		shard.points = PackedVector2Array([Vector2.ZERO, direction * length])
		shard.default_color = color
		shard.width = maxf(1.0, 2.4 * size)
		shard.antialiased = true
		burst.add_child(shard)
		var distance: float = speed * duration * (0.35 + float(index % 9) * 0.055)
		var tween: Tween = shard.create_tween().set_parallel()
		(
			tween
			. tween_property(shard, "position", direction * distance, duration)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_OUT)
		)
		tween.tween_property(shard, "rotation", -1.0 + float(index % 5) * 0.5, duration)
		tween.tween_property(shard, "modulate:a", 0.0, duration).set_delay(duration * 0.32)
	var cleanup: Tween = burst.create_tween()
	cleanup.tween_interval(duration + 0.05)
	cleanup.tween_callback(burst.queue_free)


func _ring(location: Vector2, color: Color, radius: float, duration: float) -> void:
	if content.get_child_count() >= MAX_EFFECTS:
		return
	var ring: Line2D = Line2D.new()
	ring.position = location
	ring.default_color = color
	ring.width = 2.5
	ring.antialiased = true
	for index: int in range(65):
		ring.add_point(Vector2.from_angle(index * TAU / 64.0) * 16.0)
	content.add_child(ring)
	var tween: Tween = ring.create_tween().set_parallel()
	(
		tween
		. tween_method(_resize_ring.bind(ring), 1.0, radius / 16.0, duration)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)
	tween.tween_property(ring, "modulate:a", 0.0, duration)
	tween.chain().tween_callback(ring.queue_free)


func _resize_ring(factor: float, ring: Line2D) -> void:
	ring.scale = Vector2.ONE * factor
	# Line2Dは線幅もscaleするので逆数を掛け、広がっても見かけの太さを保つ。
	ring.width = 2.5 / factor


func _popup(location: Vector2, text: String, color: Color, size: int) -> void:
	if content.get_child_count() >= MAX_EFFECTS:
		return
	# 同じ射線での多段ヒットは粒子を毎回出し、数字だけを約0.2秒間隔にする。
	if text == "−1" and _has_recent_damage(location):
		return
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color("08111e"))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.position = location - Vector2(text.length() * size * 0.35, 32)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(label)
	label.position.x = clampf(label.position.x, 334, 946 - label.get_minimum_size().x)
	label.set_meta("origin", location)
	label.set_meta("born_msec", Time.get_ticks_msec())
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2.ONE * 0.7
	_make_room_for(label)
	_rise_popup(label, label.position.y - 46, 0.65)
	var tween: Tween = label.create_tween().set_parallel()
	tween.tween_property(label, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK)
	tween.tween_property(label, "modulate:a", 0.0, 0.3).set_delay(0.35)
	tween.chain().tween_callback(label.queue_free)


func _has_recent_damage(location: Vector2) -> bool:
	for child: Node in content.get_children():
		if not child is Label or child.is_queued_for_deletion() or child.text != "−1":
			continue
		if not child.has_meta("born_msec"):
			continue
		var origin: Vector2 = child.get_meta("origin")
		var born: int = child.get_meta("born_msec")
		if location.distance_to(origin) < 56 and Time.get_ticks_msec() - born < 190:
			return true
	return false


func _make_room_for(label: Label) -> void:
	var new_rect: Rect2 = Rect2(label.position, label.get_minimum_size()).grow(8)
	for child: Node in content.get_children():
		if not child is Label or child == label or child.is_queued_for_deletion():
			continue
		var older: Label = child as Label
		var old_rect: Rect2 = Rect2(older.position, older.get_minimum_size())
		# 上昇中の近隣表示も押し上げ、連続回収の3件目以降にも縦の間隔を残す。
		if new_rect.grow_individual(0, 100, 0, 0).intersects(old_rect):
			var gap: float = maxf(label.get_minimum_size().y, older.get_minimum_size().y) + 8
			var target: float = older.position.y - gap
			if older.has_meta("rise_target"):
				target = minf(target, float(older.get_meta("rise_target")) - gap)
			_rise_popup(older, target, 0.16)


func _rise_popup(label: Label, target_y: float, duration: float) -> void:
	if label.has_meta("rise_tween"):
		var previous: Tween = label.get_meta("rise_tween") as Tween
		if previous.is_valid():
			previous.kill()
	var tween: Tween = label.create_tween()
	label.set_meta("rise_tween", tween)
	label.set_meta("rise_target", target_y)
	(
		tween
		. tween_property(label, "position:y", target_y, duration)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
