class_name SpiritUI
extends RefCounted
## 和紙と墨の共通部品。表示は呼び出し側の状態から作り直せる。

const PAPER: Color = Color("e9ddc0")
const GOLD: Color = Color("c5a971")
const INK: Color = Color("10232b")
const MUTED: Color = Color("9aada6")
const RED: Color = Color("c96659")
const JADE: Color = Color("8bcebb")


static func label(
	parent: Node,
	words: String,
	rect: Rect2,
	font_size: int = 20,
	color: Color = PAPER,
	centered: bool = false
) -> Label:
	var result: Label = Label.new()
	result.text = words
	result.position = rect.position
	result.size = Vector2(rect.size.x, maxf(rect.size.y, font_size * 1.85))
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_constant_override("line_spacing", -4)
	result.add_theme_color_override("font_color", color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.clip_text = true
	if centered:
		result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(result)
	result.position = rect.position
	result.size = Vector2(rect.size.x, maxf(rect.size.y, font_size * 1.85))
	return result


static func panel(parent: Node, rect: Rect2, tint: Color = INK) -> Panel:
	var result: Panel = Panel.new()
	result.position = rect.position
	result.size = rect.size
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = tint
	style.border_color = Color("5a665a")
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	result.add_theme_stylebox_override("panel", style)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(result)
	return result


static func button(
	parent: Node, words: String, rect: Rect2, callback: Callable, tag: String = ""
) -> Button:
	var result: Button = Button.new()
	result.text = words
	result.position = rect.position
	result.size = rect.size
	result.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	result.set_meta("tag", tag)
	parent.add_child(result)
	result.pressed.connect(callback)
	result.mouse_entered.connect(_button_hover.bind(result, true))
	result.mouse_exited.connect(_button_hover.bind(result, false))
	result.focus_entered.connect(_button_hover.bind(result, true))
	result.focus_exited.connect(_button_hover.bind(result, false))
	return result


static func art(parent: Node, id: String, rect: Rect2) -> TextureRect:
	var result: TextureRect = TextureRect.new()
	var path: String = "res://assets/art/%s.svg" % id
	if ResourceLoader.exists(path):
		result.texture = load(path)
	result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result.position = rect.position
	result.size = rect.size
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(result)
	return result


static func line(parent: Node, from: Vector2, to: Vector2, tint: Color = GOLD) -> Line2D:
	var result: Line2D = Line2D.new()
	result.points = PackedVector2Array([from, to])
	result.default_color = tint
	result.width = 1.0
	parent.add_child(result)
	return result


# ホバーの開始に合わせる一度きりの反応。既存Tweenを置換し終点を固定する。
static func _button_hover(button_node: Button, entered: bool) -> void:
	var previous: Tween = null
	if button_node.has_meta("hover_tween"):
		previous = button_node.get_meta("hover_tween")
	if previous and previous.is_valid():
		previous.kill()
	button_node.pivot_offset = button_node.size * 0.5
	var tween: Tween = button_node.create_tween()
	tween.tween_property(button_node, "scale", Vector2.ONE * (1.025 if entered else 1.0), 0.12)
	button_node.set_meta("hover_tween", tween)
