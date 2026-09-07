extends Control
## 画面を組み立てる共通部品。ゲーム進行は main.gd が所有する。

var content: Control
var display_life: Array[float] = [8000.0, 8000.0]


func _panel(rect: Rect2) -> void:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override(
		"panel", _style(Color(0.035, 0.15, 0.095, 0.96), Color("b8964d"))
	)
	content.add_child(panel)


func _paper_panel(rect: Rect2) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paper: StyleBoxFlat = _style(Color("eadfbe"), Color("b28c47"))
	paper.set_border_width_all(3)
	paper.shadow_color = Color(0.02, 0.01, 0.0, 0.55)
	paper.shadow_size = 12
	panel.add_theme_stylebox_override("panel", paper)
	content.add_child(panel)
	return panel


func _highlight(rect: Rect2) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glow := StyleBoxFlat.new()
	glow.bg_color = Color(1.0, 0.82, 0.32, 0.08)
	glow.border_color = Color("ffe49a")
	glow.set_border_width_all(4)
	glow.set_corner_radius_all(10)
	glow.shadow_color = Color(1.0, 0.76, 0.18, 0.50)
	glow.shadow_size = 10
	panel.add_theme_stylebox_override("panel", glow)
	content.add_child(panel)
	return panel


func _rule(rect: Rect2, color: Color) -> void:
	var rule := ColorRect.new()
	rule.position = rect.position
	rule.size = rect.size
	rule.color = color
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(rule)


func _label(
	value: String, rect: Rect2, pixels: int, color: Color, node_name: String = ""
) -> Label:
	var label := Label.new()
	if not node_name.is_empty():
		label.name = node_name
	label.text = value
	label.position = rect.position
	label.add_theme_font_size_override("font_size", pixels)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(label)
	label.size = rect.size
	label.set_deferred("size", rect.size)
	return label


func _art(art_name: String, rect: Rect2, node_name: String = "") -> void:
	var art := TextureRect.new()
	if not node_name.is_empty():
		art.name = node_name
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.texture = load("res://assets/art/%s.svg" % art_name)
	art.position = rect.position
	art.size = rect.size
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(art)


func _framed_card_art(card_id: String, rect: Rect2, node_name: String = "") -> Control:
	var holder := Control.new()
	if not node_name.is_empty():
		holder.name = node_name
	holder.position = rect.position
	holder.size = rect.size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(holder)
	var art := TextureRect.new()
	art.texture = load("res://assets/art/generated/%s.png" % card_id)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.position = Vector2(rect.size.x * 0.10, rect.size.y * 0.12)
	art.size = Vector2(rect.size.x * 0.80, rect.size.y * 0.64)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(art)
	var frame := TextureRect.new()
	frame.texture = load("res://assets/art/generated/card_frame.png")
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.size = rect.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(frame)
	return holder


func _button(
	node_name: String, value: String, rect: Rect2, action: Callable, unavailable: bool = false
) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = value
	button.position = rect.position
	button.size = rect.size
	button.disabled = unavailable
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pivot_offset = rect.size * 0.5
	button.mouse_entered.connect(_button_motion.bind(button, Vector2.ONE * 1.025))
	button.mouse_exited.connect(_button_motion.bind(button, Vector2.ONE))
	button.button_down.connect(_button_motion.bind(button, Vector2.ONE * 0.975))
	button.button_up.connect(_button_motion.bind(button, Vector2.ONE))
	button.pressed.connect(action)
	content.add_child(button)
	return button


func _style(background: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_corner_radius_all(8)
	box.set_border_width_all(1)
	box.content_margin_left = 8
	box.content_margin_right = 8
	return box


func _life_bar(player: int, rect: Rect2, color: Color) -> void:
	var bar := ProgressBar.new()
	bar.name = "life_bar%d" % player
	bar.position = rect.position
	bar.size = rect.size
	bar.max_value = 8000.0
	bar.value = display_life[player]
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", _style(Color("1b2b39"), Color.TRANSPARENT))
	bar.add_theme_stylebox_override("fill", _style(color, Color.TRANSPARENT))
	content.add_child(bar)
	bar.size = rect.size
	bar.set_deferred("size", rect.size)


# 押下ごとの視覚フィードバックであり、現在の Tween を置き換えて重複を防ぐ。
func _button_motion(button: Button, target: Vector2) -> void:
	if button.has_meta("motion"):
		var previous: Tween = button.get_meta("motion")
		previous.kill()
	var motion: Tween = button.create_tween()
	motion.tween_property(button, "scale", target, 0.12).set_trans(Tween.TRANS_QUAD)
	button.set_meta("motion", motion)
