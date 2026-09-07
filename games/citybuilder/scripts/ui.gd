extends RefCounted
## 青焼き図面の用紙・インク・注記を共通化する。

const BLUEPRINT_SHADER: Shader = preload("res://assets/shaders/blueprint_paper.gdshader")
const INK: Color = Color("062d55")
const PAPER: Color = Color("e9f8ff")
const MUTED: Color = Color("8bbbd3")
const CYAN: Color = Color("62ddff")
const ORANGE: Color = Color("ffba62")
const ALERT: Color = Color("ff7b7b")
const BLUE: Color = Color("084f8b")
const DEEP_BLUE: Color = Color("073865")


static func make_theme() -> Theme:
	var result := Theme.new()
	result.default_font = load("res://assets/fonts/IBMPlexSansJP-Regular.ttf")
	result.default_font_size = 17
	result.set_color("font_color", "Label", PAPER)
	for mode: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var fill: Color = Color("063663e8")
		var border: Color = MUTED
		if mode == "hover":
			fill = Color("0a5d9ff2")
			border = CYAN
		elif mode == "pressed":
			fill = Color("0c78b8")
			border = PAPER
		elif mode == "focus":
			fill = Color("096fa9")
			border = ORANGE
		elif mode == "disabled":
			fill = Color("082d4da0")
			border = Color("59849a80")
		result.set_stylebox(mode, "Button", box(fill, border, 2))
	result.set_color("font_color", "Button", PAPER)
	result.set_color("font_hover_color", "Button", Color.WHITE)
	result.set_color("font_pressed_color", "Button", Color.WHITE)
	result.set_color("font_focus_color", "Button", Color.WHITE)
	result.set_color("font_disabled_color", "Button", Color("658ba0"))
	return result


static func box(
	color: Color, border: Color = Color.TRANSPARENT, radius: int = 2, width: int = 1
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_border_width_all(width)
	style.border_color = border
	style.content_margin_left = 10
	style.content_margin_right = 10
	return style


static func blueprint_surface(parent: Node, rect: Rect2, color: Color = INK) -> ColorRect:
	var item := ColorRect.new()
	item.position = rect.position
	item.size = rect.size
	item.color = color
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paper := ShaderMaterial.new()
	paper.shader = BLUEPRINT_SHADER
	item.material = paper
	parent.add_child(item)
	return item


static func panel(parent: Node, rect: Rect2, color: Color = DEEP_BLUE) -> Panel:
	var item := Panel.new()
	item.position = rect.position
	item.size = rect.size
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_theme_stylebox_override("panel", box(color, MUTED, 1))
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


static func rule(
	parent: Node, from: Vector2, to: Vector2, color: Color = MUTED, width: float = 1.0
) -> Line2D:
	var item := Line2D.new()
	item.points = PackedVector2Array([from, to])
	item.default_color = color
	item.width = width
	item.antialiased = true
	parent.add_child(item)
	return item
