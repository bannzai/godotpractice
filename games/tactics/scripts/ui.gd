extends RefCounted
## 配色・書体・操作の見た目を共有し、進行データは持たない。

const INK := Color("101e2d")
const PAPER := Color("f2ead6")
const GOLD := Color("dfbd79")
const JADE := Color("77c4b0")
const CORAL := Color("ec8b79")
const MUTED := Color("9fb1b6")


static func box(tint: Color, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = tint
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	return style


static func make_theme() -> Theme:
	var result := Theme.new()
	if ResourceLoader.exists("res://assets/fonts/ZenOldMincho-Regular.ttf"):
		result.default_font = load("res://assets/fonts/ZenOldMincho-Regular.ttf")
	result.default_font_size = 20
	result.set_color("font_color", "Label", PAPER)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var tint: Color = INK
		if state == "hover":
			tint = Color("31534f")
		if state == "pressed":
			tint = Color("54776d")
		result.set_stylebox(state, "Button", box(tint, GOLD))
		result.set_color("font_" + state + "_color", "Button", PAPER)
	result.set_color("font_color", "Button", PAPER)
	return result


static func label(
	parent: Node, text: String, rect: Rect2, point: int = 20, tint: Color = PAPER
) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", point)
	node.add_theme_color_override("font_color", tint)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	node.position = rect.position
	node.size = rect.size
	return node


static func panel(parent: Node, rect: Rect2, tint: Color = INK, border: Color = GOLD) -> Panel:
	var node := Panel.new()
	node.add_theme_stylebox_override("panel", box(tint, border))
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	node.position = rect.position
	node.size = rect.size
	return node


static func button(parent: Node, text: String, rect: Rect2, action: Callable) -> Button:
	var node := Button.new()
	node.text = text
	parent.add_child(node)
	node.position = rect.position
	node.size = rect.size
	node.pressed.connect(action)
	node.mouse_entered.connect(feedback.bind(node, true))
	node.mouse_exited.connect(feedback.bind(node, false))
	return node


# 操作への反応は、個々の入力につき一度ずつ補間する。
static func feedback(node: Button, active: bool) -> void:
	if node.has_meta("feedback"):
		var old: Tween = node.get_meta("feedback")
		if old.is_valid():
			old.kill()
	var tween: Tween = node.create_tween()
	node.set_meta("feedback", tween)
	tween.tween_property(node, "modulate", GOLD if active else Color.WHITE, 0.12)


static func art(parent: Node, path: String, rect: Rect2) -> TextureRect:
	var node := TextureRect.new()
	if ResourceLoader.exists("res://assets/" + path):
		node.texture = load("res://assets/" + path)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	node.position = rect.position
	node.size = rect.size
	return node


static func meter(parent: Node, rect: Rect2, value: int, maximum: int) -> ProgressBar:
	var node := ProgressBar.new()
	node.show_percentage = false
	node.max_value = maximum
	node.value = value
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_stylebox_override("background", box(Color("283744")))
	node.add_theme_stylebox_override("fill", box(JADE))
	parent.add_child(node)
	node.position = rect.position
	node.size = rect.size
	return node
