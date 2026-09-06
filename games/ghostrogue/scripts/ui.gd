extends RefCounted
## 画面要素の生成は親へノードを追加するため非冪等。再描画時は画面の所有者が破棄する。

const PAPER := Color("e6dec9")
const MUTED := Color("a2b8ba")
const RED := Color("d4776d")
const GOLD := Color("d4b582")
const INK := Color("13232ddd")


static func label(
	parent: Node, value: String, rect: Rect2, font_size: int = 22, color: Color = PAPER
) -> Label:
	var node := Label.new()
	node.text = value
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	node.position = rect.position
	node.size = rect.size
	return node


static func panel(parent: Node, rect: Rect2, color: Color = INK) -> Panel:
	var node := Panel.new()
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = Color("738b8966")
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	node.add_theme_stylebox_override("panel", box)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	node.position = rect.position
	node.size = rect.size
	return node


static func button(
	parent: Node, id: String, value: String, rect: Rect2, callback: Callable, hint: String = ""
) -> Button:
	var node := Button.new()
	node.name = id
	node.text = value if not value.contains("\n") else ""
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.tooltip_text = hint
	node.add_theme_font_size_override("font_size", 20)
	parent.add_child(node)
	node.position = rect.position
	node.size = rect.size
	if value.contains("\n"):
		var lines: PackedStringArray = value.split("\n", true, 1)
		label(node, lines[0], Rect2(16, 7, rect.size.x - 32, 29), 20)
		label(node, lines[1], Rect2(16, 39, rect.size.x - 32, rect.size.y - 43), 14, MUTED)
	node.pivot_offset = rect.size * 0.5
	node.pressed.connect(callback)
	node.mouse_entered.connect(_react.bind(node, true))
	node.mouse_exited.connect(_react.bind(node, false))
	return node


static func _react(button_node: Button, hovered: bool) -> void:
	if not is_instance_valid(button_node):
		return
	var tween: Tween = button_node.create_tween()
	tween.tween_property(button_node, "scale", Vector2.ONE * (1.025 if hovered else 1.0), 0.12)


static func texture(parent: Node, path: String, rect: Rect2) -> TextureRect:
	var node := TextureRect.new()
	node.texture = load(path)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	node.position = rect.position
	node.size = rect.size
	return node


static func bar(
	parent: Node, rect: Rect2, value: float, maximum: float, color: Color
) -> ProgressBar:
	var node := ProgressBar.new()
	node.show_percentage = false
	node.max_value = maximum
	node.value = value
	var empty := StyleBoxFlat.new()
	empty.bg_color = Color("0a171f")
	empty.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	node.add_theme_stylebox_override("background", empty)
	node.add_theme_stylebox_override("fill", fill)
	parent.add_child(node)
	node.position = rect.position
	node.size = rect.size
	return node
