extends RefCounted
## タペストリーの限定糸色・巻物・操作反応を全画面で共有する。

const INK := Color("29251f")
const GOLD := Color("c99a3d")
const PAPER := Color("ead9af")
const MUTED := Color("766b57")
const PARCHMENT_DARK := Color("c7ad78")
const THREAD_RED := Color("8f3f32")
const THREAD_BLUE := Color("345769")
const THREAD_OLIVE := Color("677044")
const THREAD_BROWN := Color("6f4d32")
const THREAD_FADED := Color("9a8868")
const TRANSPARENT := Color(0.0, 0.0, 0.0, 0.0)


static func make_theme() -> Theme:
	var value := Theme.new()
	value.default_font = load("res://assets/fonts/ZenKurenaido-Regular.ttf")
	value.default_font_size = 19
	value.set_color("font_color", "Label", INK)
	value.set_color("font_color", "Button", INK)
	value.set_color("font_hover_color", "Button", GOLD)
	value.set_color("font_pressed_color", "Button", PAPER)
	value.set_color("font_disabled_color", "Button", THREAD_FADED)
	value.set_stylebox("normal", "Button", embroidered_box(PAPER, THREAD_BROWN))
	value.set_stylebox("hover", "Button", embroidered_box(Color("f3e4be"), GOLD, 3))
	value.set_stylebox("pressed", "Button", embroidered_box(THREAD_RED, INK, 3))
	value.set_stylebox(
		"disabled", "Button", embroidered_box(Color("c9b98f"), THREAD_FADED)
	)
	value.set_stylebox("focus", "Button", embroidered_box(TRANSPARENT, GOLD, 3))
	value.set_stylebox("panel", "Panel", scroll_box())
	return value


static func box(fill: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	return embroidered_box(fill, border, width)


## 角を丸めず、布の縦糸・横糸に沿った直線的な刺繍縁を作る。
static func embroidered_box(fill: Color, border: Color, width: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(1)
	style.anti_aliasing = false
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


## 羊皮紙の濃淡と縁の影を持つ、戦況を書き込む巻物用の面を作る。
static func scroll_box(fill: Color = PAPER, border: Color = THREAD_BROWN) -> StyleBoxFlat:
	var style := embroidered_box(fill, border, 3)
	style.shadow_color = Color(INK, 0.32)
	style.shadow_size = 5
	style.shadow_offset = Vector2(4, 5)
	return style


## 塔の紋章を載せる盾向けの、選択状態が糸色と太さで分かる面を作る。
static func crest_box(thread_color: Color, selected: bool = false) -> StyleBoxFlat:
	var fill := Color(thread_color, 0.28 if selected else 0.13)
	return embroidered_box(fill, GOLD if selected else thread_color, 4 if selected else 2)


static func label(parent: Node, text: String, point: Vector2, font_size: int = 20,
		color: Color = INK) -> Label:
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


static func panel(parent: Node, rect: Rect2, style: StyleBox = null) -> Panel:
	var node := Panel.new()
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if style != null:
		node.add_theme_stylebox_override("panel", style)
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


## 画面を描いた後に薄い織物目を重ねる。入力は背後のUIへ通す。
static func tapestry_overlay(
		parent: Node,
		rect: Rect2 = Rect2(0, 0, 1280, 720),
		strength: float = 0.12,
) -> ColorRect:
	var existing := parent.get_node_or_null("TapestryOverlay")
	if existing is ColorRect:
		var existing_overlay := existing as ColorRect
		existing_overlay.position = rect.position
		existing_overlay.size = rect.size
		var existing_material := existing_overlay.material as ShaderMaterial
		existing_material.set_shader_parameter(
			"weave_strength", clampf(strength, 0.0, 0.35)
		)
		return existing_overlay
	var node := ColorRect.new()
	node.name = "TapestryOverlay"
	node.position = rect.position
	node.size = rect.size
	node.color = Color.WHITE
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.z_index = 100
	var shader: Shader = load("res://assets/shaders/tapestry.gdshader")
	var shader_material := ShaderMaterial.new()
	shader_material.shader = shader
	shader_material.set_shader_parameter("weave_strength", clampf(strength, 0.0, 0.35))
	node.material = shader_material
	parent.add_child(node)
	return node
