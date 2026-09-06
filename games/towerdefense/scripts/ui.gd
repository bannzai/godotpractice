extends RefCounted
## 全画面で同じ余白・配色・操作反応を使う。

const INK := Color("122e35")
const GOLD := Color("f2d291")
const PAPER := Color("f5edda")
const MUTED := Color("aec6bd")


static func make_theme() -> Theme:
	var value := Theme.new()
	value.default_font = load("res://assets/fonts/font.ttf")
	value.default_font_size = 19
	value.set_color("font_color", "Label", PAPER)
	value.set_color("font_color", "Button", PAPER)
	value.set_color("font_hover_color", "Button", GOLD)
	value.set_color("font_pressed_color", "Button", INK)
	value.set_color("font_disabled_color", "Button", Color("718981"))
	value.set_stylebox("normal", "Button", box(Color("254c4c"), Color("789188")))
	value.set_stylebox("hover", "Button", box(Color("356462"), GOLD))
	value.set_stylebox("pressed", "Button", box(GOLD, PAPER))
	value.set_stylebox("disabled", "Button", box(Color("203b40"), Color("3e5657")))
	value.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), GOLD, 3))
	value.set_stylebox("panel", "Panel", box(INK, Color("69867b")))
	return value


static func box(fill: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(12)
	style.content_margin_left = 12
	style.content_margin_right = 12
	return style


static func label(parent: Node, text: String, point: Vector2, font_size: int = 20,
		color: Color = PAPER) -> Label:
	var node := Label.new()
	node.text = text
	node.position = point
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node


static func button(parent: Node, text: String, rect: Rect2, callback: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.position = rect.position
	node.size = rect.size
	# ゲーム中の方向キーは建設地点の選択に使う。全ボタンに対応する操作キーも用意する。
	node.focus_mode = Control.FOCUS_NONE
	node.pressed.connect(callback)
	parent.add_child(node)
	node.pivot_offset = node.size / 2
	node.mouse_entered.connect(func() -> void:
		node.create_tween().tween_property(node, "scale", Vector2.ONE * 1.025, 0.10))
	node.mouse_exited.connect(func() -> void:
		node.create_tween().tween_property(node, "scale", Vector2.ONE, 0.10))
	return node


static func panel(parent: Node, rect: Rect2) -> Panel:
	var node := Panel.new()
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node


static func texture(parent: Node, path: String, rect: Rect2) -> TextureRect:
	var node := TextureRect.new()
	node.texture = load(path)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node
