extends Node2D
## 行動の余韻を記号の組版と Tween だけで表す。

const UI := preload("res://scripts/ui.gd")


## 独立した命中を重ねて表示するため、呼び出しごとに活字の飛沫を追加する。
func burst(pos: Vector2, color: Color, amount: int = 14) -> void:
	var marks: int = clampi(amount / 3, 4, 16)
	var text := ""
	for index: int in range(marks):
		text += ["*", "+", "·", ":"][index % 4]
	var label: Label = _effect_label(text, pos - Vector2(70, 26), Vector2(140, 52), 24, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(label, "scale", Vector2(1.55, 1.35), 0.45).set_trans(Tween.TRANS_EXPO)
	tween.tween_property(label, "rotation", 0.18, 0.45)
	tween.tween_property(label, "modulate:a", 0.0, 0.28).set_delay(0.17)
	tween.chain().tween_callback(label.queue_free)


## 連続したダメージを個別に読めるよう、毎回ラベルと Tween を生成する。
func popup(pos: Vector2, text: String, color: Color) -> void:
	var label: Label = _effect_label(text, pos + Vector2(-65, -43), Vector2(130, 36), 22, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 32.0, 0.7).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.3).set_delay(0.4)
	tween.chain().tween_callback(label.queue_free)


## 攻撃ごとに向きの違う記号を残すため、演出ノードの生成は冪等にしない。
func slash(pos: Vector2, direction: Vector2) -> void:
	var glyph := "─" if absf(direction.x) >= absf(direction.y) else "│"
	if absf(direction.x) > 0.1 and absf(direction.y) > 0.1:
		glyph = "╱" if signf(direction.x) != signf(direction.y) else "╲"
	var label: Label = _effect_label(glyph, pos - Vector2(35, 35), Vector2(70, 70), 52, UI.GOLD)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(label, "scale", Vector2.ONE * 1.6, 0.2)
	tween.tween_property(label, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(label.queue_free)


func _effect_label(
	text: String, pos: Vector2, extent: Vector2, size: int, color: Color
) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = extent
	label.pivot_offset = extent * 0.5
	label.add_theme_font_override("font", load(UI.FONT_PATH))
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("020507"))
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label
