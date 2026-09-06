extends RefCounted
## 画面の配色と再利用する部品。ゲーム状態は保持しない。

const INK := Color("101c2c")
const PAPER := Color("f2e6ca")
const GOLD := Color("d9b66f")
const MUTED := Color("a8bbb6")
const RUST := Color("c86e55")


static func box(color: Color, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 16
	style.content_margin_right = 16
	return style


static func label(parent: Node, value: String, rect: Rect2, size: int = 22,
		color: Color = PAPER) -> Label:
	var node := Label.new()
	node.text = value
	node.position = rect.position
	node.size = rect.size
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node


static func panel(parent: Node, rect: Rect2, color: Color = INK,
		border: Color = GOLD) -> Panel:
	var node := Panel.new()
	node.position = rect.position
	node.size = rect.size
	node.add_theme_stylebox_override("panel", box(color, border))
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node


static func button(parent: Node, value: String, rect: Rect2,
		callback: Callable, primary: bool = false) -> Button:
	var node := Button.new()
	node.text = value
	node.position = rect.position
	node.size = rect.size
	node.add_theme_font_size_override("font_size", 21)
	node.add_theme_color_override("font_color", INK if primary else PAPER)
	node.add_theme_color_override("font_hover_color", PAPER)
	node.add_theme_color_override("font_focus_color", INK if primary else PAPER)
	node.add_theme_stylebox_override("normal", box(GOLD if primary else INK, GOLD))
	node.add_theme_stylebox_override("disabled", box(INK, Color("526861")))
	node.add_theme_color_override("font_disabled_color", MUTED)
	node.add_theme_stylebox_override("hover", box(Color("305660"), PAPER))
	node.add_theme_stylebox_override("pressed", box(Color("506f6b"), PAPER))
	node.add_theme_stylebox_override("focus", box(Color(0.5, 0.7, 0.6, 0.18), PAPER))
	node.mouse_entered.connect(feedback.bind(node, true))
	node.mouse_exited.connect(feedback.bind(node, false))
	node.button_down.connect(feedback.bind(node, true))
	node.button_up.connect(feedback.bind(node, false))
	if callback.is_valid():
		node.pressed.connect(callback)
	parent.add_child(node)
	return node


static func art(parent: Node, filename: String, rect: Rect2) -> TextureRect:
	var node := TextureRect.new()
	node.texture = load("res://assets/art/" + filename + ".svg")
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node


static func meter(parent: Node, rect: Rect2, maximum: int, value: int,
		color: Color) -> ProgressBar:
	var node := ProgressBar.new()
	node.position = rect.position
	node.size = rect.size
	node.max_value = maximum
	node.value = value
	node.show_percentage = false
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_stylebox_override("background", box(Color("243747")))
	node.add_theme_stylebox_override("fill", box(color))
	parent.add_child(node)
	# パーセント表示を消す前の最小高さを保持させない。
	node.size = rect.size
	return node


# 数値の描画だけを補間し、ゲーム状態は変更しない。
static func count(node: Label, previous: int, value: int, format: String) -> void:
	if node.has_meta("count_tween"):
		var active: Tween = node.get_meta("count_tween")
		if active.is_valid():
			active.kill()
	node.text = format % previous
	var tween: Tween = node.create_tween()
	node.set_meta("count_tween", tween)
	tween.tween_method(func(number: float) -> void:
		node.text = format % int(roundf(number)), float(previous), float(value), 0.38)


# ボタンの入力ごとに表示を補間するため、一回の操作を一回の演出として扱う。
static func feedback(node: Button, pressed: bool) -> void:
	if node.has_meta("feedback_tween"):
		var active: Tween = node.get_meta("feedback_tween")
		if active.is_valid():
			active.kill()
	var tween: Tween = node.create_tween()
	node.set_meta("feedback_tween", tween)
	tween.tween_property(node, "self_modulate", Color("d9b66f") if pressed else Color.WHITE, 0.14)
