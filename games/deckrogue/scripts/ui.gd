extends RefCounted
## 羊皮紙の見開きと写本の余白を組み立てる。ゲーム状態は保持しない。

const INK := Color("34251b")
const PAPER := Color("ead9b5")
const LIGHT_PAPER := Color("f5e8c8")
const GOLD := Color("ae812f")
const MUTED := Color("6b5339")
const RUST := Color("963f31")
const LAPIS := Color("355a82")
const VERDIGRIS := Color("486449")
const DESK := Color("25160f")


static func box(color: Color, border: Color = Color.TRANSPARENT,
		border_width: int = 2, radius: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style


static func book(parent: Node) -> void:
	var desk := ColorRect.new()
	desk.color = DESK
	desk.size = Vector2(1280, 720)
	desk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(desk)
	for index: int in range(7):
		var grain := ColorRect.new()
		grain.color = Color("5b3a24") if index % 2 == 0 else Color("1a100b")
		grain.position = Vector2(0, 52 + index * 102)
		grain.size = Vector2(1280, 2)
		grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
		desk.add_child(grain)
	panel(parent, Rect2(30, 20, 1220, 680), Color("0d0806a8"), Color.TRANSPARENT, 0, 13)
	panel(parent, Rect2(40, 30, 590, 660), PAPER, INK, 3, 9)
	panel(parent, Rect2(650, 30, 590, 660), PAPER, INK, 3, 9)
	var left_texture: TextureRect = art(parent, "paper_texture", Rect2(43, 33, 584, 654))
	var right_texture: TextureRect = art(parent, "paper_texture", Rect2(653, 33, 584, 654))
	left_texture.modulate = Color(1.0, 1.0, 1.0, 0.09)
	right_texture.modulate = Color(1.0, 1.0, 1.0, 0.09)
	var gutter := ColorRect.new()
	gutter.position = Vector2(628, 39)
	gutter.size = Vector2(24, 642)
	gutter.color = Color("4a2d1c88")
	gutter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(gutter)
	rule(parent, PackedVector2Array([Vector2(58, 49), Vector2(612, 49)]), GOLD, 2.0)
	rule(parent, PackedVector2Array([Vector2(668, 49), Vector2(1222, 49)]), GOLD, 2.0)
	rule(parent, PackedVector2Array([Vector2(58, 672), Vector2(612, 672)]), GOLD, 2.0)
	rule(parent, PackedVector2Array([Vector2(668, 672), Vector2(1222, 672)]), GOLD, 2.0)
	label(parent, "❦", Rect2(51, 45, 42, 30), 23, RUST)
	label(parent, "❦", Rect2(1186, 650, 42, 30), 23, RUST)


static func label(parent: Node, value: String, rect: Rect2, size: int = 22,
		color: Color = INK) -> Label:
	var node := Label.new()
	node.text = value
	node.position = rect.position
	node.size = rect.size
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node


static func illuminated_heading(parent: Node, initial: String, rest: String,
		rect: Rect2, size: int = 38) -> void:
	panel(parent, Rect2(rect.position, Vector2(size + 16, size + 17)), GOLD, RUST, 3, 1)
	var capital: Label = label(parent, initial, Rect2(rect.position + Vector2(4, -5),
		Vector2(size + 10, size + 18)), size + 8, RUST)
	capital.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	capital.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label(parent, rest, Rect2(rect.position + Vector2(size + 29, 0),
		Vector2(rect.size.x - size - 29, rect.size.y)), size, INK)


static func panel(parent: Node, rect: Rect2, color: Color = PAPER,
		border: Color = INK, border_width: int = 2, radius: int = 2) -> Panel:
	var node := Panel.new()
	node.position = rect.position
	node.size = rect.size
	node.add_theme_stylebox_override("panel", box(color, border, border_width, radius))
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node


static func note(parent: Node, title: String, body: String, rect: Rect2,
		accent: Color = LAPIS) -> Panel:
	var node: Panel = panel(parent, rect, LIGHT_PAPER, accent, 3, 1)
	label(node, title, Rect2(18, 9, rect.size.x - 36, 30), 20, accent)
	rule(node, PackedVector2Array([Vector2(17, 41), Vector2(rect.size.x - 17, 41)]), accent, 1.5)
	var copy: Label = label(node, body, Rect2(18, 49, rect.size.x - 36, rect.size.y - 57), 17, INK)
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return node


static func button(parent: Node, value: String, rect: Rect2,
		callback: Callable, primary: bool = false) -> Button:
	var node := Button.new()
	node.text = value
	node.position = rect.position
	node.size = rect.size
	node.add_theme_font_size_override("font_size", 20)
	node.add_theme_color_override("font_color", PAPER if primary else INK)
	node.add_theme_color_override("font_hover_color", LIGHT_PAPER if primary else INK)
	node.add_theme_color_override("font_focus_color", PAPER if primary else INK)
	node.add_theme_stylebox_override("normal", box(RUST if primary else LIGHT_PAPER,
		INK if primary else MUTED, 2, 1))
	node.add_theme_stylebox_override("disabled", box(Color("c7b997"), Color("8d8064"), 2, 1))
	node.add_theme_color_override("font_disabled_color", Color("746951"))
	node.add_theme_stylebox_override("hover", box(Color("71412d") if primary else Color("f7e3b7"),
		GOLD, 3, 1))
	node.add_theme_stylebox_override("pressed", box(Color("542d22") if primary else Color("dbc58f"),
		RUST, 3, 1))
	node.add_theme_stylebox_override("focus", box(Color("963f3130"), GOLD, 5, 1))
	node.mouse_entered.connect(feedback.bind(node, true))
	node.mouse_exited.connect(feedback.bind(node, false))
	node.button_down.connect(feedback.bind(node, true))
	node.button_up.connect(feedback.bind(node, false))
	if callback.is_valid():
		node.pressed.connect(callback)
	parent.add_child(node)
	return node


static func art(parent: Node, filename: String, rect: Rect2) -> TextureRect:
	var node := TextureRect.new()
	var path := "res://assets/art/" + filename + ".png"
	node.texture = load(path)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node


static func rule(parent: Node, points: PackedVector2Array, color: Color = INK,
		width: float = 2.0) -> Line2D:
	var node := Line2D.new()
	if points.size() >= 2:
		node.points = points
	node.default_color = color
	node.width = width
	node.antialiased = true
	parent.add_child(node)
	return node


static func meter(parent: Node, rect: Rect2, maximum: int, value: int,
		color: Color) -> ProgressBar:
	var node := ProgressBar.new()
	node.position = rect.position
	node.size = rect.size
	node.max_value = maximum
	node.value = value
	node.show_percentage = false
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_stylebox_override("background", box(Color("c8b68e"), INK, 1, 0))
	node.add_theme_stylebox_override("fill", box(color, color, 1, 0))
	parent.add_child(node)
	node.size = rect.size
	return node


static func count(node: Label, previous: int, value: int, format: String) -> void:
	if node.has_meta("count_tween"):
		var active: Tween = node.get_meta("count_tween")
		if active.is_valid():
			active.kill()
	node.text = format % previous
	var tween: Tween = node.create_tween()
	node.set_meta("count_tween", tween)
	tween.tween_method(func(number: float) -> void:
		node.text = format % int(roundf(number)), float(previous), float(value), 0.38)


static func feedback(node: Button, pressed: bool) -> void:
	if node.has_meta("feedback_tween"):
		var active: Tween = node.get_meta("feedback_tween")
		if active.is_valid():
			active.kill()
	var tween: Tween = node.create_tween()
	node.set_meta("feedback_tween", tween)
	tween.tween_property(node, "self_modulate", Color("d8b45f") if pressed else Color.WHITE, 0.14)
