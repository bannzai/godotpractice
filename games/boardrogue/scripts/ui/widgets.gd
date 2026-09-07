extends RefCounted
## 全画面で共有する寸法・色・文字・操作部品。

const INK := Color("281b15")
const PAPER := Color("f0dfb9")
const MUTED := Color("765f49")
const GOLD := Color("a56f22")
const RED := Color("a43725")
const JADE := Color("566b3d")
const WOOD := Color("593324")


static func box(color: Color = PAPER, border: Color = Color("6e4d35")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(2)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


static func theme_resource() -> Theme:
	var result := Theme.new()
	result.default_font = load("res://assets/fonts/YujiSyuku-Regular.ttf")
	result.default_font_size = 18
	result.set_color("font_color", "Label", INK)
	result.set_color("font_color", "Button", INK)
	result.set_color("font_hover_color", "Button", RED)
	result.set_color("font_focus_color", "Button", INK)
	result.set_color("font_pressed_color", "Button", INK)
	result.set_color("font_disabled_color", "Button", Color("9b8970"))
	result.set_stylebox("normal", "Button", box(Color("ead6aa")))
	result.set_stylebox("hover", "Button", box(Color("f7eacb"), RED))
	result.set_stylebox("pressed", "Button", box(Color("dcc38f"), GOLD))
	result.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), GOLD))
	result.set_stylebox("disabled", "Button", box(Color("cdbf9f9a"), Color("897b62")))
	result.set_stylebox("panel", "Panel", box())
	result.set_stylebox("normal", "LineEdit", box(Color("f4e7c8")))
	result.set_stylebox("focus", "LineEdit", box(Color("fff4d7"), GOLD))
	result.set_color("font_color", "LineEdit", INK)
	result.set_color("font_placeholder_color", "LineEdit", MUTED)
	return result


static func panel(parent: Node, area: Rect2, color: Color = INK) -> Panel:
	var node := Panel.new()
	node.position = area.position
	node.size = area.size
	# 旧画面の暗色指定も紙面へ寄せ、共通テンプレート由来の青緑パネルを残さない。
	var paper_color: Color = color
	if color.get_luminance() < 0.38:
		paper_color = Color(PAPER, clampf(color.a, 0.76, 0.96))
	node.add_theme_stylebox_override("panel", box(paper_color))
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node


static func scroll_panel(parent: Node, area: Rect2, color: Color = Color("f1dfb8ed")) -> Panel:
	var node: Panel = panel(parent, area, color)
	for x: float in [5.0, area.size.x - 11.0]:
		var edge := ColorRect.new()
		edge.position = Vector2(x, 5)
		edge.size = Vector2(6, area.size.y - 10)
		edge.color = Color(WOOD, 0.86)
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.add_child(edge)
	return node


static func vertical_label(
	parent: Node, value: String, area: Rect2, pixels: int = 22, color: Color = INK
) -> Label:
	return label(parent, "\n".join(value.split("")), area, pixels, color)


static func label(
	parent: Node, value: String, area: Rect2, pixels: int = 18, color: Color = INK
) -> Label:
	var node := Label.new()
	node.position = area.position
	node.size = area.size
	node.text = value
	node.add_theme_font_size_override("font_size", pixels)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node


static func paragraph(parent: Node, value: String, area: Rect2, pixels: int = 18) -> Label:
	var node: Label = label(parent, value, area, pixels)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return node


static func button(
	parent: Node, key: String, value: String, area: Rect2, action: Callable
) -> Button:
	var node := Button.new()
	node.name = key
	node.position = area.position
	node.size = area.size
	node.text = value
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.pressed.connect(action)
	parent.add_child(node)
	node.pivot_offset = area.size / 2
	node.mouse_entered.connect(func() -> void: _hover(node, true))
	node.mouse_exited.connect(func() -> void: _hover(node, false))
	return node


# 入力時刻から短い補間を始めるため非冪等。直前の補間は終了させる。
static func _hover(node: Control, active: bool) -> void:
	if node.has_meta("hover_tween"):
		(node.get_meta("hover_tween") as Tween).kill()
	var tween: Tween = node.create_tween()
	node.set_meta("hover_tween", tween)
	tween.tween_property(node, "scale", Vector2.ONE * (1.025 if active else 1.0), 0.10)


static func picture(parent: Node, path: String, area: Rect2) -> TextureRect:
	var node := TextureRect.new()
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.texture = load(path)
	node.position = area.position
	node.size = area.size
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node
