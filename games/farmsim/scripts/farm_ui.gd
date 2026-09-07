extends RefCounted
## 版木の墨と日記帳の紙を使う UI。進行状態を保持せず Control の組み立てだけを担う。

const INK := Color("332c26")
const MUTED := Color("765f45")
const CREAM := Color("ead7ab")
const GOLD := Color("c98b32")


static func box(color: Color, radius: int = 4) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.border_color = Color("59402c")
	style.set_border_width_all(2)
	return style


static func panel(parent: Node, rect: Rect2, color: Color = CREAM) -> Panel:
	var node := Panel.new()
	node.position = rect.position
	node.size = rect.size
	node.add_theme_stylebox_override("panel", box(color))
	parent.add_child(node)
	return node


static func label(parent: Node, text: String, rect: Rect2,
		font_size: int = 22, color: Color = INK) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
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
	return node


static func picture(parent: Node, path: String, rect: Rect2) -> TextureRect:
	var node := TextureRect.new()
	node.texture = load(path) as Texture2D
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	node.position = rect.position
	node.size = rect.size
	return node
