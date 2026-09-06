extends RefCounted
## 全画面で共有する寸法・色・文字・操作部品。

const INK := Color("142522")
const PAPER := Color("eee1c5")
const MUTED := Color("a8b8a6")
const GOLD := Color("d7b46e")
const RED := Color("d97763")
const JADE := Color("8cc8b3")


static func box(color: Color = INK, border: Color = Color("53655b")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


static func theme_resource() -> Theme:
	var result := Theme.new()
	result.default_font = load("res://assets/fonts/ZenOldMincho-Regular.ttf")
	result.default_font_size = 18
	result.set_color("font_color", "Label", PAPER)
	result.set_color("font_color", "Button", PAPER)
	result.set_color("font_hover_color", "Button", Color.WHITE)
	result.set_color("font_disabled_color", "Button", Color("72857b"))
	result.set_stylebox("normal", "Button", box())
	result.set_stylebox("hover", "Button", box(Color("304c40"), GOLD))
	result.set_stylebox("pressed", "Button", box(Color("5b4d32"), GOLD))
	result.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), GOLD))
	result.set_stylebox("disabled", "Button", box(Color("182722"), Color("34483d")))
	result.set_stylebox("panel", "Panel", box())
	result.set_stylebox("normal", "LineEdit", box())
	result.set_stylebox("focus", "LineEdit", box(INK, GOLD))
	result.set_color("font_color", "LineEdit", PAPER)
	return result


static func panel(parent: Node, area: Rect2, color: Color = INK) -> Panel:
	var node := Panel.new()
	node.position = area.position
	node.size = area.size
	node.add_theme_stylebox_override("panel", box(color))
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node


static func label(
	parent: Node, value: String, area: Rect2, pixels: int = 18, color: Color = PAPER
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
