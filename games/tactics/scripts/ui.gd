extends RefCounted
## 屏風絵の配色・書体・操作の見た目を共有し、進行データは持たない。

const INK := Color("211914")
const PAPER := Color("f3e5c3")
const GOLD := Color("c99a3d")
const JADE := Color("416b50")
const CORAL := Color("a94332")
const MUTED := Color("725f4b")


static func box(tint: Color, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = tint
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(2)
	style.content_margin_left = 14
	style.content_margin_right = 14
	return style


static func make_theme() -> Theme:
	var result := Theme.new()
	if ResourceLoader.exists("res://assets/fonts/ShipporiMinchoB1-Regular.ttf"):
		result.default_font = load("res://assets/fonts/ShipporiMinchoB1-Regular.ttf")
	result.default_font_size = 20
	result.set_color("font_color", "Label", INK)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var tint: Color = Color("efe0b9")
		if state == "hover":
			tint = Color("e4c779")
		if state == "pressed":
			tint = Color("d0aa54")
		if state == "disabled":
			tint = Color("c8bda3")
		result.set_stylebox(state, "Button", box(tint, INK if state == "focus" else GOLD))
		result.set_color("font_" + state + "_color", "Button", INK)
	result.set_color("font_color", "Button", INK)
	return result


static func label(
	parent: Node, text: String, rect: Rect2, point: int = 20, tint: Color = PAPER
) -> Label:
	var node := Label.new()
	node.text = text
	if point >= 26 and ResourceLoader.exists("res://assets/fonts/ShipporiMinchoB1-SemiBold.ttf"):
		node.add_theme_font_override(
			"font", load("res://assets/fonts/ShipporiMinchoB1-SemiBold.ttf")
		)
	node.add_theme_font_size_override("font_size", point)
	node.add_theme_color_override("font_color", tint)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	node.position = rect.position
	node.size = rect.size
	return node


static func panel(parent: Node, rect: Rect2, tint: Color = PAPER, border: Color = INK) -> Panel:
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


static func fan_button(
	parent: Node, text: String, rect: Rect2, angle: float, action: Callable
) -> Button:
	var node: Button = button(parent, text, rect, action)
	node.pivot_offset = Vector2(rect.size.x / 2.0, rect.size.y)
	node.rotation = angle * 0.25
	node.scale = Vector2(0.32, 0.12)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = (
			Color("e7cf91")
			if state in ["hover", "pressed", "focus"]
			else Color("f4e8c8")
		)
		style.border_color = CORAL if state == "focus" else GOLD
		style.set_border_width_all(2)
		style.corner_radius_top_left = 28
		style.corner_radius_top_right = 28
		style.corner_radius_bottom_left = 5
		style.corner_radius_bottom_right = 5
		node.add_theme_stylebox_override(state, style)
		node.add_theme_color_override("font_" + state + "_color", INK)
	var opening: Tween = node.create_tween().set_parallel(true)
	opening.tween_property(node, "rotation", angle, 0.18).set_trans(Tween.TRANS_BACK)
	opening.tween_property(node, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)
	return node


static func scroll_panel(parent: Node, rect: Rect2) -> Panel:
	var node: Panel = panel(parent, rect, Color("f6e9c7"), Color("6f4a24"))
	for y: float in [8.0, rect.size.y - 10.0]:
		var roll := ColorRect.new()
		roll.color = Color("b8893c")
		roll.position = Vector2(-10, y)
		roll.size = Vector2(rect.size.x + 20, 5)
		roll.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.add_child(roll)
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


static func art_cover(parent: Node, path: String, rect: Rect2) -> TextureRect:
	var node: TextureRect = art(parent, path, rect)
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
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
