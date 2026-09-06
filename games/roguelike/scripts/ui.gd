extends RefCounted
## 共通の色・文字とコントロール生成。生成関数は新規ノードを返すため非冪等。

const INK := Color("101d29")
const PANEL := Color("182c38")
const GOLD := Color("e5b866")
const TEXT := Color("eee9d7")
const MUTED := Color("94adae")
const TEAL := Color("6cd4c5")


static func make_theme() -> Theme:
	var result := Theme.new()
	var font := FontVariation.new()
	font.base_font = load("res://assets/fonts/NotoSansJP.ttf")
	var weight: int = TextServerManager.get_primary_interface().name_to_tag("wght")
	font.variation_opentype = {weight: 500}
	result.default_font = font
	result.default_font_size = 18
	result.set_color("font_color", "Label", TEXT)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = PANEL.lightened(0.15) if state == "hover" else PANEL
		if state == "pressed":
			box.bg_color = Color("35635e")
		box.border_color = GOLD if state in ["hover", "focus"] else Color("47616a")
		box.set_border_width_all(2 if state == "focus" else 1)
		box.set_corner_radius_all(8)
		box.content_margin_left = 16
		box.content_margin_right = 16
		result.set_stylebox(state, "Button", box)
	result.set_color("font_color", "Button", TEXT)
	result.set_color("font_hover_color", "Button", GOLD)
	return result


static func label(
	parent: Node, caption: String, rect: Rect2, size: int = 18, color: Color = TEXT
) -> Label:
	var node := Label.new()
	node.text = caption
	node.position = rect.position
	node.size = rect.size
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node


static func button(parent: Node, caption: String, rect: Rect2, action: Callable) -> Button:
	var node := Button.new()
	node.text = caption
	node.position = rect.position
	node.size = rect.size
	node.pressed.connect(action)
	parent.add_child(node)
	return node


static func panel(parent: Node, rect: Rect2) -> Panel:
	var node := Panel.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color("142631f5")
	box.border_color = Color("46636c")
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	node.add_theme_stylebox_override("panel", box)
	node.position = rect.position
	node.size = rect.size
	parent.add_child(node)
	return node


static func picture(parent: Node, path: String, rect: Rect2) -> TextureRect:
	var node := TextureRect.new()
	node.texture = load(path)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node
