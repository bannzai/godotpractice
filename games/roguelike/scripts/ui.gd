extends RefCounted
## 活字端末の色・文字とコントロール生成。生成関数は新規ノードを返すため非冪等。

const FONT_PATH := "res://assets/fonts/MPLUS1Code[wght].ttf"
const INK := Color("060b10")
const PANEL := Color("0b151c")
const GOLD := Color("ffbd4a")
const TEXT := Color("d7f7e8")
const MUTED := Color("739487")
const TEAL := Color("45f0b5")
const ALERT := Color("ff6174")


static func make_theme() -> Theme:
	var result := Theme.new()
	var font := FontVariation.new()
	font.base_font = load(FONT_PATH)
	var weight: int = TextServerManager.get_primary_interface().name_to_tag("wght")
	font.variation_opentype = {weight: 520}
	result.default_font = font
	result.default_font_size = 18
	result.set_color("font_color", "Label", TEXT)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("163229") if state in ["hover", "focus"] else PANEL
		if state == "pressed":
			box.bg_color = Color("24513f")
		box.border_color = TEAL if state in ["hover", "focus"] else Color("315347")
		box.set_border_width_all(2 if state == "focus" else 1)
		box.content_margin_left = 14
		box.content_margin_right = 14
		result.set_stylebox(state, "Button", box)
	result.set_color("font_color", "Button", TEXT)
	result.set_color("font_hover_color", "Button", TEAL)
	result.set_color("font_focus_color", "Button", TEAL)
	result.set_color("font_disabled_color", "Button", MUTED.darkened(0.35))
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
	node.pressed.connect(func() -> void: node.get_node("/root/Sound").play("select"))
	node.pressed.connect(action)
	parent.add_child(node)
	return node


static func rich_text(
	parent: Node, caption: String, rect: Rect2, size: int = 18
) -> RichTextLabel:
	var node := RichTextLabel.new()
	node.bbcode_enabled = true
	node.fit_content = false
	node.scroll_active = false
	node.text = caption
	node.position = rect.position
	node.size = rect.size
	node.add_theme_font_size_override("normal_font_size", size)
	node.add_theme_font_size_override("bold_font_size", size)
	node.add_theme_color_override("default_color", TEXT)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node


static func panel(parent: Node, rect: Rect2) -> Panel:
	var node := Panel.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color("091218")
	box.border_color = Color("315347")
	box.set_border_width_all(1)
	node.add_theme_stylebox_override("panel", box)
	node.position = rect.position
	node.size = rect.size
	parent.add_child(node)
	return node
