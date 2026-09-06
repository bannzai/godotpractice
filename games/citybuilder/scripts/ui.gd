extends RefCounted
## 紙・深緑・珊瑚色を使う共通テーマ。

const INK: Color = Color("243c42")
const PAPER: Color = Color("f4f0df")
const MUTED: Color = Color("9ab4b1")
const MINT: Color = Color("90d9b4")
const CORAL: Color = Color("ec9678")


static func make_theme() -> Theme:
	var result := Theme.new()
	result.default_font = load("res://assets/fonts/MPLUSRounded1c-Regular.ttf")
	result.default_font_size = 17
	result.set_color("font_color", "Label", PAPER)
	for mode: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var color: Color = INK.lightened(0.13 if mode == "hover" else 0.0)
		if mode == "pressed":
			color = Color("41685b")
		result.set_stylebox(mode, "Button", box(color, MINT if mode == "focus" else MUTED))
	result.set_color("font_color", "Button", PAPER)
	result.set_color("font_hover_color", "Button", Color.WHITE)
	result.set_color("font_disabled_color", "Button", Color("657879"))
	return result


static func box(color: Color, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(12)
	style.set_border_width_all(1)
	style.border_color = border
	style.content_margin_left = 12
	style.content_margin_right = 12
	return style


static func panel(parent: Node, rect: Rect2, color: Color = INK) -> Panel:
	var item := Panel.new()
	item.position = rect.position
	item.size = rect.size
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_theme_stylebox_override("panel", box(color))
	parent.add_child(item)
	return item


static func label(
	parent: Node, text: String, rect: Rect2, font_size: int = 18, color: Color = PAPER
) -> Label:
	var item := Label.new()
	item.text = text
	item.position = rect.position
	item.size = rect.size
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", color)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(item)
	return item


static func button(parent: Node, text: String, rect: Rect2, action: Callable) -> Button:
	var item := Button.new()
	item.text = text
	item.position = rect.position
	item.size = rect.size
	item.pressed.connect(action)
	parent.add_child(item)
	return item


static func picture(parent: Node, path: String, rect: Rect2) -> TextureRect:
	var item := TextureRect.new()
	item.texture = load("res://assets/" + path)
	item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item.position = rect.position
	item.size = rect.size
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(item)
	return item
